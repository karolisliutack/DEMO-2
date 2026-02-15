resource "aws_dynamodb_table" "this" {
  name         = "${var.environment}-requests-db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.environment}-requests-db"
    Environment = var.environment
    Project     = "health-check-api"
    ManagedBy   = "Terraform"
  }
}
