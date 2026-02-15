variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for DynamoDB encryption"
  type        = string
  nullable    = false
}
