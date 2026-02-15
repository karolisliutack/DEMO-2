# Serverless Health Check API

A production-ready serverless health check API built on AWS, provisioned with Terraform and deployed via GitHub Actions CI/CD pipelines. The API accepts GET and POST requests, validates payloads, and persists request records to DynamoDB with automatic TTL-based cleanup.

---

## Architecture Overview

```
                         +-------------------+
                         |   GitHub Actions   |
                         | (CI/CD Pipeline)   |
                         +--------+----------+
                                  |
                                  | Deploys via Terraform
                                  v
                +----------------------------------------+
                |              AWS Cloud                  |
                |                                        |
                |   +-------------+    +--------------+  |
                |   | API Gateway |    |  CloudWatch   |  |
                |   | (REST API)  |    |   (Logs)      |  |
                |   | + API Key   |    +--------------+  |
                |   +------+------+          ^           |
                |          |                 |           |
                |          | Invoke          | Logs      |
                |          v                 |           |
                |   +------+------+----------+           |
                |   |             VPC                    |
                |   |  +-------------------------+      |
                |   |  |    Private Subnets       |      |
                |   |  |  +------------------+    |      |
                |   |  |  | Lambda Function  |    |      |
                |   |  |  | (Python 3.12)    |    |      |
                |   |  |  +--------+---------+    |      |
                |   |  +-----------|-------------+      |
                |   |  |    Public Subnets        |      |
                |   |  |  +------------------+    |      |
                |   |  |  |  NAT Gateway     |    |      |
                |   |  |  +------------------+    |      |
                |   |  +-------------------------+      |
                |   +--------------|---------------------+
                |                  |                      |
                |                  v                      |
                |   +------+-------+--+  +------------+  |
                |   |    DynamoDB      |  |    KMS     |  |
                |   | (PAY_PER_REQUEST)|  | (CMK for   |  |
                |   | + TTL + PITR     |  |  encrypt)  |  |
                |   +------------------+  +------------+  |
                +----------------------------------------+
```

The architecture follows a fully serverless pattern. Incoming HTTP requests hit **API Gateway**, which enforces API key authentication and throttling before invoking the **Lambda function**. The Lambda runs inside a **VPC** (private subnets) for network isolation. It processes the request, logs to **CloudWatch**, and writes request records to **DynamoDB**. All data at rest is encrypted using a **KMS Customer Managed Key**. A NAT Gateway in the public subnets provides the Lambda with outbound internet access required to reach DynamoDB.

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml            # Main deployment pipeline (staging + prod)
│       ├── destroy.yml           # Infrastructure teardown workflow
│       └── pr-check.yml          # Pull request validation checks
├── lambda/
│   ├── health_check.py           # Lambda function source code
│   └── requirements.txt          # Python dependencies (boto3)
├── terraform/
│   ├── main.tf                   # Root module - orchestrates all child modules
│   ├── variables.tf              # Input variable definitions with validation
│   ├── outputs.tf                # Output values (API URL, key, resource names)
│   ├── providers.tf              # AWS provider and Terraform version constraints
│   ├── backend.tf                # S3 backend configuration (partial)
│   ├── staging.tfvars            # Staging environment variable values
│   ├── prod.tfvars               # Production environment variable values
│   └── modules/
│       ├── kms/                  # KMS Customer Managed Key for encryption
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── vpc/                  # VPC with public/private subnets, NAT Gateway
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── dynamodb/             # DynamoDB table with encryption, TTL, PITR
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                  # IAM roles and policies (Lambda exec, GitHub OIDC)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── lambda/               # Lambda function resource and CloudWatch log group
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── api_gateway/          # REST API, stage, usage plan, API key
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── README.md                     # This file
```

---

## Prerequisites

Before deploying this project, ensure the following are in place:

- **AWS Account** with permissions to create: VPC, Lambda, API Gateway, DynamoDB, KMS, IAM roles, CloudWatch log groups, NAT Gateway, and Elastic IPs
- **Terraform** >= 1.5 (the CI/CD pipeline uses ~1.9.0)
- **AWS CLI** configured with valid credentials (for local deployments)
- **Python 3.12** (for local Lambda development and testing)
- **S3 Bucket** for Terraform remote state storage (must be pre-created)

### GitHub Repository Secrets

The following secrets must be configured in your GitHub repository under **Settings > Secrets and variables > Actions**:

| Secret Name | Description | Example |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key for deployments | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key for deployments | `wJal...` |
| `AWS_REGION` | Target AWS region | `eu-west-1` |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state | `my-terraform-state-bucket` |

### GitHub Environment Configuration

A GitHub Environment named **`production`** must be configured with **required reviewers** enabled. This provides a manual approval gate before any deployment to production. To set this up:

1. Go to your repository **Settings > Environments**.
2. Create an environment named `production`.
3. Enable **Required reviewers** and add the appropriate team members.

---

## CI/CD Pipeline

The project uses three GitHub Actions workflows to manage the full lifecycle of the infrastructure.

### 1. Deploy Infrastructure (`deploy.yml`)

This is the primary deployment workflow. It runs on two triggers:

- **Push to `main` branch**: Automatically deploys to staging.
- **Manual dispatch (`workflow_dispatch`)**: Allows selecting either `staging` or `prod` as the target environment.

The pipeline executes in the following stages:

**Stage 1 -- Security and Compliance Scanning**

All security scans must pass before any deployment proceeds:

- **tfsec**: Static analysis of Terraform code for AWS security best practices and misconfigurations.
- **Checkov**: Policy-as-code scanner for Terraform that checks against CIS benchmarks and cloud security best practices.
- **pip-audit**: Scans Python dependencies in `lambda/requirements.txt` for known vulnerabilities using the OSV database.
- **Bandit**: Python static application security testing (SAST) tool that identifies common security issues in Python code (e.g., hardcoded passwords, SQL injection, insecure function calls). Results are uploaded as artifacts for review.

**Stage 2 -- Package Lambda Function**

After security scans pass:

1. Installs Python 3.12 dependencies from `lambda/requirements.txt` into a build directory.
2. Copies the Lambda source code into the build directory.
3. Creates a versioned zip archive named `lambda-<GIT_SHA_8>.zip` using the first 8 characters of the commit SHA.
4. Uploads the zip as a GitHub Actions artifact (retained for 90 days).

**Stage 3 -- Terraform Plan**

Runs `terraform plan` against the target environment(s):

- On push to main: Plans for staging only.
- On manual dispatch: Plans for both staging and production.
- The plan output is saved as an artifact and summarized in the GitHub Actions step summary.

**Stage 4a -- Deploy to Staging**

Runs automatically on push to `main` or when staging is manually selected:

1. Downloads the Lambda artifact and the Terraform plan.
2. Initializes Terraform with the staging state file.
3. Applies the saved plan (`terraform apply staging.tfplan`).
4. Captures and reports the API URL and Lambda version in the step summary.

**Stage 4b -- Deploy to Production**

Runs only on manual dispatch with `prod` selected:

1. The job is gated by the `production` GitHub Environment, which requires manual approval from designated reviewers.
2. Once approved, it follows the same download-init-apply sequence as staging but using the production plan and state file.
3. Records the deployer identity in the step summary for audit purposes.

**Concurrency Control**: Deployments to the same environment are serialized (not cancelled) via the `concurrency` setting, preventing race conditions on Terraform state.

### 2. Destroy Infrastructure (`destroy.yml`)

A manually triggered workflow for tearing down infrastructure:

1. **Confirmation gate**: Requires typing the environment name to confirm destruction, preventing accidental teardowns.
2. **Environment protection**: Production destruction requires manual approval via the `production` GitHub Environment.
3. **Destroy plan**: Runs `terraform plan -destroy` first to show what will be removed, logged in the step summary.
4. **Production safeguard**: For production, includes a 5-second delay and explicit warning before proceeding.
5. **Verification**: Logs the destruction event including who triggered it and when.

State files in S3 are preserved after destruction for audit trail purposes.

### 3. Pull Request Validation (`pr-check.yml`)

Runs automatically on pull requests targeting `main` when changes are detected in `terraform/`, `lambda/`, or `.github/workflows/`:

1. **Security scanning**: Same tfsec, Checkov, pip-audit, and Bandit checks as the deploy pipeline.
2. **Terraform format check**: Runs `terraform fmt -check -recursive` and posts a PR comment with diff output if formatting issues are found.
3. **Terraform validate**: Validates the configuration syntax and internal consistency.
4. **Terraform plan for both environments**: Runs `terraform plan` against both staging and production state, posting the full plan output as PR comments for reviewers.
5. **PR summary comment**: Generates a summary table showing pass/fail status for all checks.

Concurrent runs for the same PR are cancelled in favor of the latest push, keeping feedback current.

---

## Deployment Instructions

### Deploying to Staging

**Automatic (recommended):**

1. Merge or push your changes to the `main` branch.
2. The deploy workflow triggers automatically, targeting the staging environment.
3. Monitor progress in the GitHub **Actions** tab.
4. Once complete, the API URL and Lambda version appear in the workflow step summary.

**Manual trigger:**

1. Go to the repository **Actions** tab.
2. Select the **"Deploy Serverless Health Check API"** workflow.
3. Click **"Run workflow"**.
4. Set **environment** to `staging`.
5. Click **"Run workflow"** to start.

### Deploying to Production

Production deployments require manual trigger and approval:

1. Go to the repository **Actions** tab.
2. Select the **"Deploy Serverless Health Check API"** workflow.
3. Click **"Run workflow"**.
4. Set **environment** to `prod`.
5. Click **"Run workflow"** to start.
6. The workflow will execute security scanning, Lambda packaging, and Terraform planning.
7. The `deploy-prod` job will pause, awaiting manual approval.
8. A designated reviewer must navigate to the pending deployment and click **"Approve and deploy"** in the GitHub Environment protection rules.
9. Once approved, Terraform apply proceeds against the production environment.

### Manual Deployment (Local)

For local development or debugging, you can deploy directly from your machine:

```bash
# Navigate to the Terraform directory
cd terraform

# Initialize Terraform with the staging backend
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=staging/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="encrypt=true"

# Preview the changes
terraform plan -var-file=staging.tfvars

# Apply the changes
terraform apply -var-file=staging.tfvars
```

For production, replace `staging` with `prod` in the backend key and var-file:

```bash
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="encrypt=true"

terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

> **Note**: When deploying locally, ensure the Lambda zip artifact is available. The CI/CD pipeline handles packaging automatically, but for local runs you may need to package it manually or set `TF_VAR_lambda_zip_path` to point to a pre-built zip.

---

## Testing the Endpoint

### Get the API URL and Key

After deployment, retrieve the API endpoint and key from Terraform outputs:

```bash
cd terraform

# Get the API URL
terraform output api_url

# Get the API key (sensitive value)
terraform output -raw api_key_value
```

### Example curl Commands

**GET request (health check):**

```bash
curl -H "x-api-key: YOUR_API_KEY" \
  https://YOUR_API_ID.execute-api.eu-west-1.amazonaws.com/staging/health
```

Expected response (200):

```json
{
  "status": "healthy",
  "message": "Health check passed",
  "record_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "timestamp": "2026-01-15T12:00:00.000000"
}
```

**POST request with payload:**

```bash
curl -X POST \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"payload": {"test": "data"}}' \
  https://YOUR_API_ID.execute-api.eu-west-1.amazonaws.com/staging/health
```

Expected response (200):

```json
{
  "status": "healthy",
  "message": "Request processed and saved",
  "record_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "timestamp": "2026-01-15T12:00:00.000000"
}
```

**POST request missing the required "payload" field (returns 400):**

```bash
curl -X POST \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"wrong_key": "data"}' \
  https://YOUR_API_ID.execute-api.eu-west-1.amazonaws.com/staging/health
```

Expected response (400):

```json
{
  "error": "Validation Error",
  "message": "Missing required field: 'payload'"
}
```

**Request without API key (returns 403):**

```bash
curl https://YOUR_API_ID.execute-api.eu-west-1.amazonaws.com/staging/health
```

Expected response (403):

```json
{
  "message": "Forbidden"
}
```

---

## Security Features

This project implements multiple layers of security:

- **KMS Customer Managed Key**: A dedicated CMK encrypts DynamoDB data at rest and Lambda environment variables, providing full control over key rotation and access policies.
- **VPC-Deployed Lambda**: The Lambda function runs in private subnets with no direct internet ingress, reducing the attack surface.
- **API Gateway API Key Authentication**: All requests must include a valid API key in the `x-api-key` header. Keys are managed through API Gateway usage plans.
- **Request Validation**: POST requests are validated to require a `payload` field. Invalid JSON and missing fields return 400 errors.
- **DDoS Protection via Throttling**: API Gateway enforces rate limiting (staging: 100 req/s, 200 burst; production: 500 req/s, 1000 burst) to protect against abuse.
- **Least-Privilege IAM Roles**: IAM policies grant only the specific permissions needed (DynamoDB PutItem on the specific table, KMS Encrypt/Decrypt on the specific key, CloudWatch Logs on the specific log group). No wildcard resource permissions.
- **IaC Security Scanning**: Every deployment and pull request runs tfsec and Checkov to catch security misconfigurations in Terraform code before they reach AWS.
- **Dependency Scanning**: pip-audit checks Python dependencies for known CVEs. Bandit performs static analysis on Python source code for common security anti-patterns.
- **Point-in-Time Recovery (PITR)**: Enabled on the DynamoDB table, allowing restoration to any point within the last 35 days.
- **Encrypted Terraform State**: The S3 backend is configured with `encrypt = true` for state file encryption at rest.
- **Pinned GitHub Actions**: All third-party actions are pinned to specific commit SHAs to prevent supply chain attacks.
- **Minimal Workflow Permissions**: GitHub Actions permissions are scoped per-job following the principle of least privilege.

---

## Design Choices and Assumptions

- **Modular Terraform**: Infrastructure is split into six reusable modules (`kms`, `vpc`, `dynamodb`, `iam`, `lambda`, `api_gateway`) for maintainability, testability, and potential reuse across projects. Each module has clearly defined inputs and outputs.

- **PAY_PER_REQUEST DynamoDB**: On-demand capacity mode is selected for cost-effectiveness with variable and unpredictable workloads. No capacity planning is required, and you pay only for actual read/write operations.

- **NAT Gateway**: Required for the Lambda function in private VPC subnets to reach DynamoDB via the public AWS endpoint. In production environments with high traffic, consider adding VPC endpoints for DynamoDB to reduce NAT Gateway data processing costs and improve latency.

- **API Key Authentication**: A straightforward authentication mechanism suitable for service-to-service communication and simple access control. For user-facing authentication, consider upgrading to Amazon Cognito or a Lambda authorizer.

- **S3 Backend with Partial Configuration**: Terraform state is stored in S3 for team collaboration and durability. The backend uses partial configuration so the same Terraform code can target different environments with different state files.

- **Separate tfvars per Environment**: Environment-specific configuration (VPC CIDRs, throttle limits) is isolated in dedicated variable files (`staging.tfvars`, `prod.tfvars`), enabling consistent and repeatable deployments across environments.

- **Python 3.12**: The latest stable Python runtime supported by AWS Lambda, providing performance improvements and access to modern language features.

- **90-Day TTL on DynamoDB Items**: Health check records are automatically cleaned up after 90 days via DynamoDB's TTL feature, keeping storage costs bounded without manual intervention.

- **eu-west-1 Region**: The default deployment region (Ireland), configurable via the `aws_region` variable in tfvars files.

- **Separate VPC CIDRs per Environment**: Staging uses `10.0.0.0/16` and production uses `10.1.0.0/16`, enabling VPC peering between environments if needed in the future without CIDR conflicts.

- **Git SHA-Based Lambda Versioning**: Lambda packages are tagged with the first 8 characters of the git commit SHA, providing traceability from a deployed artifact back to the exact source code commit.

---

## Cleanup / Teardown

### Via GitHub Actions (Recommended)

1. Go to the repository **Actions** tab.
2. Select the **"Destroy Infrastructure"** workflow.
3. Click **"Run workflow"**.
4. Select the target **environment** (`staging` or `prod`).
5. In the **confirmation** field, type the exact environment name (e.g., `staging`).
6. Click **"Run workflow"**.
7. For production, a reviewer must approve the destruction via the GitHub Environment protection rules.

The workflow will display all resources to be destroyed in the step summary before proceeding.

### Via Local Terraform

```bash
cd terraform

# Initialize with the target environment backend
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=staging/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="encrypt=true"

# Destroy all resources
terraform destroy -var-file=staging.tfvars
```

Replace `staging` with `prod` to tear down the production environment.

> **Warning**: Destroying infrastructure is irreversible. All data in DynamoDB will be permanently deleted. Terraform state files in S3 are preserved after destruction for audit purposes.
