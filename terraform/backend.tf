# Backend configuration for Terraform state
#
# This uses S3 for state storage and DynamoDB for state locking.
# The backend is configured with partial configuration to allow
# different state files per environment.
#
# Initialize with:
#   terraform init \
#     -backend-config="bucket=your-terraform-state-bucket" \
#     -backend-config="key=${environment}/health-check-api/terraform.tfstate" \
#     -backend-config="region=eu-west-1" \
#     -backend-config="dynamodb_table=your-terraform-lock-table"
#
# Or create a backend config file (e.g., backend-staging.hcl):
#   bucket         = "your-terraform-state-bucket"
#   key            = "staging/health-check-api/terraform.tfstate"
#   region         = "eu-west-1"
#   dynamodb_table = "your-terraform-lock-table"
#   encrypt        = true
#
# Then initialize with:
#   terraform init -backend-config=backend-staging.hcl

terraform {
  backend "s3" {
    # bucket         = "configured-via-init"
    # key            = "configured-via-init"
    # region         = "configured-via-init"
    # dynamodb_table = "configured-via-init"
    encrypt = true
  }
}
