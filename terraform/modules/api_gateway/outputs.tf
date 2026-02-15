output "api_url" {
  description = "URL of the deployed API"
  value       = "${aws_api_gateway_stage.this.invoke_url}/health"
}

output "api_key_id" {
  description = "ID of the API key"
  value       = aws_api_gateway_api_key.this.id
}

output "api_key_value" {
  description = "Value of the API key"
  value       = aws_api_gateway_api_key.this.value
  sensitive   = true
}

output "execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.this.execution_arn
}
