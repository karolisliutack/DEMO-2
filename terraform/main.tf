# KMS Module - Customer Managed Key for encryption
module "kms" {
  source = "./modules/kms"

  environment = var.environment
}

# VPC Module - Network infrastructure for Lambda
module "vpc" {
  source = "./modules/vpc"

  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
}

# DynamoDB Module - Database for storing requests
module "dynamodb" {
  source = "./modules/dynamodb"

  environment = var.environment
  kms_key_arn = module.kms.key_arn

  depends_on = [module.kms]
}

# Placeholder for Lambda log group ARN (needed for IAM role creation)
# This creates a chicken-and-egg situation, so we construct the ARN manually
locals {
  lambda_log_group_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.environment}-health-check-function"
}

# IAM Module - Roles and policies
module "iam" {
  source = "./modules/iam"

  environment                   = var.environment
  dynamodb_table_arn            = module.dynamodb.table_arn
  kms_key_arn                   = module.kms.key_arn
  lambda_log_group_arn          = local.lambda_log_group_arn
  vpc_id                        = module.vpc.vpc_id
  github_repo                   = var.github_repo
  create_github_oidc_provider   = var.create_github_oidc_provider

  depends_on = [module.dynamodb, module.kms, module.vpc]
}

# Lambda Module - Serverless function
module "lambda" {
  source = "./modules/lambda"

  environment          = var.environment
  lambda_role_arn      = module.iam.lambda_role_arn
  dynamodb_table_name  = module.dynamodb.table_name
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_id    = module.vpc.security_group_id
  kms_key_arn          = module.kms.key_arn
  lambda_zip_path      = var.lambda_zip_path

  depends_on = [module.iam, module.dynamodb, module.vpc]
}

# API Gateway Module - REST API
module "api_gateway" {
  source = "./modules/api_gateway"

  environment           = var.environment
  lambda_function_arn   = module.lambda.function_arn
  lambda_invoke_arn     = module.lambda.invoke_arn
  throttle_rate_limit   = var.throttle_rate_limit
  throttle_burst_limit  = var.throttle_burst_limit
  kms_key_arn           = module.kms.key_arn

  depends_on = [module.lambda]
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/*"

  depends_on = [module.lambda, module.api_gateway]
}

# Data sources for account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
