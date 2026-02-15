variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for Lambda access"
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  nullable    = false
}

variable "lambda_log_group_arn" {
  description = "ARN of the Lambda function's CloudWatch log group"
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID where Lambda will run"
  type        = string
  nullable    = false
}

variable "github_repo" {
  description = "GitHub repository in format 'org/repo' for OIDC trust"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$", var.github_repo))
    error_message = "GitHub repo must be in format 'org/repo'."
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider (set to false if it already exists)"
  type        = bool
  default     = false
}
