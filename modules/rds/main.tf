terraform {
    required_version = ">= 0.12"
}



####
# Lambda set up
###
data "archive_file" "zipit" {
  type = "zip"
  source_file = "rds_scripts/rds_${var.function}.py"
  output_path = "rds_${var.function}.zip"
}

resource "aws_lambda_function" "lambda_function" {
  depends_on = [data.archive_file.zipit]
  role = var.lambda_role_arn
  filename = "rds_${var.function}.zip"
  function_name = "rds_${var.function}"
  handler = "rds_${var.function}.lambda_handler"
  layers = ["arn:aws:lambda:eu-west-2:336392948345:layer:AWSSDKPandas-Python38:5"]
  runtime = "python3.8"
  timeout = 900 
  memory_size = 3008
  source_code_hash = filebase64sha256("rds_${var.function}.zip")
}


###
# Permissions for each Lambda function
###
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.source_bucket_arn
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${aws_lambda_function.lambda_function.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Execution Errors"
  treat_missing_data  = "ignore"

  alarm_actions = [var.sns_arn]

  dimensions = {
    FunctionName = "${aws_lambda_function.lambda_function.function_name}"
    Resource     = "${aws_lambda_function.lambda_function.function_name}"
  }
}