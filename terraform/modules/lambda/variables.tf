variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  type        = string
  nullable    = false
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for the Lambda function"
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for high availability."
  }
}

variable "security_group_id" {
  description = "Security group ID for Lambda function"
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for environment variable encryption"
  type        = string
  nullable    = false
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment zip file"
  type        = string
  nullable    = false
}
