variable function {
    type = string
    description = "Function name from python"
}

variable lambda_role_arn {
    type = string
    description = "ARN of the lambda role"
}

variable "source_bucket_arn" {
    type = string
    description = "ARN of the S3 bucket where the extracted files are stored"
}

variable "sns_arn" {
    type = string
    description = "ARN of the SNS topic for error messaging"
}

