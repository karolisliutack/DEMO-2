variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be either 'staging' or 'prod'."
  }
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
  nullable    = false
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
  nullable    = false
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100

  validation {
    condition     = var.throttle_rate_limit > 0
    error_message = "Throttle rate limit must be greater than 0."
  }
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 200

  validation {
    condition     = var.throttle_burst_limit > 0
    error_message = "Throttle burst limit must be greater than 0."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encrypting CloudWatch logs"
  type        = string
  nullable    = false
}
