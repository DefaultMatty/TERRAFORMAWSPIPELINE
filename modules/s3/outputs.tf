output "arn" {
    value = "${aws_s3_bucket.bucket.arn}"
}

output "bucket_name" {
    value = "${aws_s3_bucket.bucket.bucket}"
}

output "subfolders" {
    value = "${var.subfolders}"
}
//
output "id" {
    value = "${aws_s3_bucket.bucket.id}"
}