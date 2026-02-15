# Production Environment Configuration

environment = "prod"
aws_region  = "eu-west-1"

# VPC Configuration
vpc_cidr = "10.1.0.0/16"
private_subnet_cidrs = [
  "10.1.1.0/24",
  "10.1.2.0/24"
]
public_subnet_cidrs = [
  "10.1.101.0/24",
  "10.1.102.0/24"
]

# API Gateway Throttling
throttle_rate_limit  = 500
throttle_burst_limit = 1000

# GitHub Repository for OIDC (update with your repo)
github_repo = "karolisliutack/DEMO-2"

# Set to true if GitHub OIDC provider doesn't exist in your AWS account yet
create_github_oidc_provider = false
