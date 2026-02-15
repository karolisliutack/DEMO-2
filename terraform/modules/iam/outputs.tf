output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "deploy_role_arn" {
  description = "ARN of the deployment role for GitHub Actions"
  value       = aws_iam_role.deploy.arn
}
