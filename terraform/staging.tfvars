# Staging Environment Configuration

environment = "staging"
aws_region  = "eu-west-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
private_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
public_subnet_cidrs = [
  "10.0.101.0/24",
  "10.0.102.0/24"
]

# API Gateway Throttling
throttle_rate_limit  = 100
throttle_burst_limit = 200

# GitHub Repository for OIDC (update with your repo)
github_repo = "karolisliutack/DEMO-2"

# Set to true if GitHub OIDC provider doesn't exist in your AWS account yet
create_github_oidc_provider = false
