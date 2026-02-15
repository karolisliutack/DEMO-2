resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-health-check-function"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.environment}-health-check-function-logs"
    Environment = var.environment
    Project     = "health-check-api"
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_function" "this" {
  filename         = var.lambda_zip_path
  function_name    = "${var.environment}-health-check-function"
  role             = var.lambda_role_arn
  handler          = "health_check.lambda_handler"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime          = "python3.12"
  memory_size      = 128
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.environment}-health-check-function"
    Environment = var.environment
    Project     = "health-check-api"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
