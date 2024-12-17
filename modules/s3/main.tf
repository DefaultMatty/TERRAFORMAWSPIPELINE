terraform {
    required_version = ">= 0.12"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.bucket_name}-${var.env}"
}

resource "aws_s3_object" "folders" {
    depends_on = [aws_s3_bucket.bucket]
    bucket  = "${var.bucket_name}-${var.env}"
    acl     = "private"
    key     =  "data/"
    content_type = "application/x-directory"
}

resource "aws_s3_object" "sonoton_subfolders_rawdata" {
    depends_on = [aws_s3_object.folders]
    for_each = toset(var.subfolders)
    bucket = "${var.bucket_name}-${var.env}"
    acl = "private"
    key = "data/${each.value}/"
}