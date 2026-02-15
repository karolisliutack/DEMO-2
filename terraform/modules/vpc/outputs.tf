output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets for Lambda"
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "Security group ID for Lambda function"
  value       = aws_security_group.lambda.id
}
