terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.60.0"
    }

  }
}
###
# Locals
###
locals {
  subfolders = jsondecode(file("${path.module}/subfolders.json"))
  schemas    = jsondecode(file("${path.module}/schemas.json"))
  emails     = #Redacted
}

####################
# Issues for MB to fix 
# 1. CSV too big - Chunk
# 2. Need to create database that creates table with data load



###
# output "AWS_ACCESS_KEY_ID" {
#   value     = local.envs["AWS_ACCESS_KEY_ID"]
#   sensitive = true # this is required if the sensitive function was used when loading .env file (more secure way)
# }

# ###
# output "AWS_SECRET_ACCESS_KEY_ID" {
#   value     = local.envs["AWS_SECRET_ACCESS_KEY_ID"]
#   sensitive = true # this is required if the sensitive function was used when loading .env file (more secure way)
# }

provider "aws" {
  region = "eu-west-2" # Specify your AWS region
  profile = "default"

}


###
# AWS Account ID
###
data "aws_caller_identity" "current" {}


###
# Buckets
###
module "mcells-upload_buckets" {
  source      = ".\\modules\\s3"
  for_each    = toset(["raw", "etl", "error"])
  bucket_name = "mcells-upload-${each.key}"
  env         = var.env
  subfolders  = var.data_sources
}

resource "aws_s3_object" "etl_target_folders" {
  for_each = {
    for subfolder in local.subfolders : subfolder.id => subfolder
  }
  bucket = module.mcells-upload_buckets["etl"].id
  key    = "data/${each.value.folder}/${each.value.subfolder}/"
  acl    = "private"
}
###
# Upload IAM
### 

resource "aws_iam_user" "upload_user" {
  name = "wrk-upload-${var.env}"
}

resource "aws_iam_access_key" "upload_user_keys" {
  user = aws_iam_user.upload_user.name
}

data "aws_iam_policy_document" "upload_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.upload_user.arn]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      module.mcells-upload_buckets["raw"].arn,
      "${module.mcells-upload_buckets["raw"].arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.mcells-upload_buckets["raw"].id
  policy = data.aws_iam_policy_document.upload_access.json
}

###
# Ingestion
###
data "aws_iam_policy_document" "lambda_role_document" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_document.json
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "s3:*"
    ]

    effect = "Allow"

    resources = [
      module.mcells-upload_buckets["raw"].arn,
      module.mcells-upload_buckets["etl"].arn,
      module.mcells-upload_buckets["error"].arn,
      "${module.mcells-upload_buckets["raw"].arn}/*",
      "${module.mcells-upload_buckets["etl"].arn}/*",
      "${module.mcells-upload_buckets["error"].arn}/*",
    ]
  }

  statement {
    actions = [
      "autoscaling:Describe*",
      "cloudwatch:*",
      "logs:*",
      "sns:*"
    ]

    effect = "Allow"

    resources = ["*"]
  }

  statement {
    actions = [
      "logs:*"
    ]

    effect = "Allow"

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "lambda-access-policy"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_iam-policy-attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_sns_topic" "error_updates" {
  name = "error-updates-topic"
}

resource "aws_sns_topic_subscription" "email_error_updates" {
  for_each  = toset(local.emails)
  topic_arn = aws_sns_topic.error_updates.arn
  protocol  = "email"
  endpoint  = each.key
}

module "mcells-uploads_preprocessing_lambda" {
  source            = ".\\modules\\lambda"
  for_each          = toset(var.lambda_funcs)
  function          = each.key
  lambda_role_arn   = aws_iam_role.lambda_role.arn
  source_bucket_arn = module.mcells-upload_buckets["raw"].arn
  sns_arn           = aws_sns_topic.error_updates.arn
}


module "mcells-uploads_rds_lambda" {
  source            = ".\\modules\\rds"
  for_each          = toset(var.lambda_funcs)
  function          = each.key
  lambda_role_arn   = aws_iam_role.lambda_role.arn
  source_bucket_arn = module.mcells-upload_buckets["raw"].arn
  sns_arn           = aws_sns_topic.error_updates.arn
}




resource "aws_s3_bucket_notification" "aws_lambda_trigger" {
  depends_on = [
    module.mcells-uploads_preprocessing_lambda
  ]

  bucket = module.mcells-upload_buckets["raw"].id

  dynamic "lambda_function" {
    for_each = toset(var.lambda_funcs)
    content {
      lambda_function_arn = module.mcells-uploads_preprocessing_lambda[lambda_function.key].arn
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = "data/${lambda_function.key}"
    }
  }
}
# Create VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnet in AZ us-east-1a
resource "aws_subnet" "example_a" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"  # Change to the region's AZs
}

# Create Subnet in AZ us-east-1b
resource "aws_subnet" "example_b" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"  # Change to the region's AZs
}

# Create DB Subnet Group
resource "aws_db_subnet_group" "example" {
  name       = "example-db-subnet-group"
  subnet_ids = [aws_subnet.example_a.id, aws_subnet.example_b.id]

  tags = {
    Name = "example-db-subnet-group"
  }
}

# Create Security Group for RDS
resource "aws_security_group" "example" {
  vpc_id = aws_vpc.example.id
  

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust this for security; this is open to all IPs.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database_sg"
  }
}
resource "aws_db_instance" "example" {
  identifier = #Redacted 
  allocated_storage    = 20                  # Size in GB
  storage_type         = "gp2"               # General-purpose SSD
  engine               = "mysql"             # Change to your DB engine (e.g., postgres, mariadb)
  engine_version       = "8.0"               # MySQL version
  instance_class       = "db.t4g.micro"      # Instance type
  db_name              = #Redacted        # The database name
  username             = #Redacted             # Username for the database
  password             = #Redacted       # Password for the database (change this!)
  parameter_group_name = "default.mysql8.0"  # Parameter group for MySQL
  publicly_accessible  = true               # Set to true if needed for public access
  db_subnet_group_name = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.example.id]
  skip_final_snapshot  = true                # Set to false if you want to take a final snapshot on deletion

  tags = {
    Name = "my-database"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.example.endpoint
}

output "rds_username" {
  value = aws_db_instance.example.username
}

resource "aws_key_pair" "generated_key" {
  key_name   = "mc_key"
  public_key = file("~/.ssh/mc_key.pub")  # Path to your public SSH key
}



resource "aws_instance" "airflow" {
  ami           = "ami-0acc77abdfc7ed5a6"  # Amazon Linux 2 AMI (update to your preferred AMI)
  instance_type = "t2.micro"  # Change to your desired instance type (t2.micro is free tier eligible)

  key_name = aws_key_pair.generated_key.key_name   # Replace with your SSH key pair name

  security_groups = [aws_security_group.airflow_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install python3 -y
              pip3 install apache-airflow
              EOF

  tags = {
    Name = "Airflow EC2 Instance"
  }
}

resource "aws_security_group" "airflow_sg" {
  name        = "airflow_sg"
  description = "Allow SSH and Airflow web server access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (modify for security)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow access to Airflow web server
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "instance_public_ip" {
  value = aws_instance.airflow.public_ip
}

# resource "aws_instance" "my_instance" {
#   ami           = "ami-0acc77abdfc7ed5a6"  # This is a common Amazon Linux 2 AMI; check for your region
#   instance_type = "t2.micro"               # Free Tier eligible instance type
#   key_name = aws_key_pair.generated_key.key_name 
#   # Security Group (allow SSH access)
#   vpc_security_group_ids = [aws_security_group.allow_ssh.id]

#   tags = {
#     Name = "MyFreeTierInstance"
#   }
# }



# resource "aws_security_group" "allow_ssh" {
#   name        = "allow_ssh"
#   description = "Allow SSH inbound traffic"

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# output "instance_public_ip" {
#   value = aws_instance.my_instance.public_ip
# }

