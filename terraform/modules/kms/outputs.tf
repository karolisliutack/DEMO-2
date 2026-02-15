output "key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = aws_kms_key.this.arn
}
