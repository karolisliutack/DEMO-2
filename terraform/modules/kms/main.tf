resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.environment} health check API encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.environment}-health-check-key"
    Environment = var.environment
    Project     = "health-check-api"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.environment}-health-check-key"
  target_key_id = aws_kms_key.this.key_id
}
