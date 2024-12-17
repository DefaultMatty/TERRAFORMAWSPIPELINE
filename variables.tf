
variable "env" {
  type    = string
  default = "prd"
}

# locals {
#   envs = { for tuple in regexall("(.*)=(.*)", file(".env")) : tuple[0] => sensitive(tuple[1]) }
# }

###
# Data sources
###

variable "data_sources" {
  type = list(string)
  default = [
    "bot"
  ]
}

###
# Auth variables
###

# variable "AWS_ACCESS_KEY_ID" {
#   type = string
# }

# variable "AWS_SECRET_ACCESS_KEY" {
#   type = string
# }

variable "aws_profile" {
  type    = string
  default = "default"  # Set a default or leave blank
}

variable "lambda_funcs" {
  type = list(string)
  default = [
    "bot"
  ]
}
