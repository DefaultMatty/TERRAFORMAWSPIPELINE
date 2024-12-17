variable "bucket_name" {
    type = string
    description = "Bucket name"
}

variable "env" {
    type = string
    description = "Environment (dev | staging | prod)"
}

variable "subfolders" {
  type = list(string)
  description = "List of data source names."
}