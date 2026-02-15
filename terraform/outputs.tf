output "api_url" {
  description = "URL of the deployed Health Check API"
  value       = module.api_gateway.api_url
}

output "api_key_value" {
  description = "API key value for authentication (keep this secret)"
  value       = module.api_gateway.api_key_value
  sensitive   = true
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "deploy_role_arn" {
  description = "ARN of the deployment role for GitHub Actions"
  value       = module.iam.deploy_role_arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = module.kms.key_arn
}
