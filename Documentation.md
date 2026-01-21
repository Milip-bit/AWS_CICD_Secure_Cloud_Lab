# 📘 AWS Secure Cloud Pipeline – Comprehensive Technical Documentation

**Author:** Filip (DevSecOps Engineer)
**Date:** January 2026
**Project Status:** Phase 3 Completed (DevSecOps Integration)

---

## 1. Executive Summary

This project demonstrates the implementation of a **Secure-by-Design** cloud infrastructure pipeline. The goal was to move away from manual console operations ("ClickOps") to a fully automated **Infrastructure as Code (IaC)** model using Terraform and GitHub Actions.

A critical focus was placed on **Shift-Left Security**—integrating security controls (Static Analysis, Secret Scanning, Policy Compliance) into the earliest stages of the CI/CD pipeline, ensuring that insecure code is rejected before it ever reaches the cloud.

---

## 2. Phase 0: Security Foundations & FinOps

Before provisioning any resources, the AWS environment was hardened according to industry best practices.

### 2.1. Identity & Access Management (IAM)

- **Root Account Protection:** Enabled MFA (Multi-Factor Authentication) on the root account to prevent catastrophic takeover.
- **Least Privilege Access:** Created a dedicated IAM User `devsecops-admin` for daily operations, avoiding the use of the root account.
- **Local Security:** Configured AWS CLI credentials locally (`~/.aws/credentials`) ensuring no keys were hardcoded in scripts.

### 2.2. FinOps Guardrails

- **AWS Budgets:** Implemented a budget alert with a threshold of **$1.00**.
- **Rationale:** To provide early detection of resource misconfiguration (e.g., leaving large EC2 instances running) or potential account compromise (e.g., crypto-mining attacks).

---

## 3. Phase 1: Infrastructure as Code (Terraform)

The infrastructure layer was designed for scalability, security, and team collaboration.

### 3.1. Project Structure (Monorepo)

Adopted a directory structure supporting multiple environments:

```text
AWS_CICD_Project/
├── secure-cloud-lab-dev/   # Development Environment (Current Focus)
│   ├── main.tf
│   ├── .tflint.hcl
│   └── .gitignore
├── secure-cloud-lab-prod/  # Production Environment (Placeholder)
└── README.md

```

### 3.2. Repository Hygiene (`.gitignore`)

Configured Git to strictly ignore sensitive local Terraform files:

- `.terraform/`
- `*.tfstate`, `*.tfstate.backup`
- `*.tfvars`

### 3.3. Remote State Management

Instead of storing the `terraform.tfstate` file locally (which poses security risks and hinders collaboration), a Remote Backend architecture was deployed:

- **Storage (S3):** The state file is stored in a private S3 bucket with **Server-Side Encryption (SSE-S3)** enabled.
- **Locking (DynamoDB):** A DynamoDB table `terraform-locks` is used to prevent race conditions. If two pipelines run simultaneously, the database locks the state file to prevent corruption.

---

## 4. Phase 2: CI/CD with OIDC Authentication

This phase focused on eliminating long-lived credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) from the CI/CD pipeline.

### 4.1. The Solution: OpenID Connect (OIDC)

We configured a **Federated Identity** trust between GitHub and AWS.

1. **Identity Provider:** Added GitHub's OIDC URL (`https://token.actions.githubusercontent.com`) to AWS IAM.
2. **Thumbprint Validation:** Configured the specific SHA-1 certificate thumbprints for GitHub servers to establish a chain of trust.

### 4.2. IAM Role Configuration

Created a specialized role: `GitHubActions-Terraform-Role`.
**Trust Policy:**
This JSON policy ensures that **only this specific GitHub repository** can assume the role.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Milip-bit/AWS_CICD_Secure_Cloud_Lab:*"
        }
      }
    }
  ]
}
```

---

## 5. Phase 3: DevSecOps Integration (Shift-Left)

This phase transformed the pipeline from a simple "deployer" into a "security gatekeeper."

### 5.1. Static Code Analysis (TFLint)

- **Tool:** TFLint
- **Purpose:** Validates Terraform code for syntax errors, deprecated syntax, and cloud provider-specific issues (e.g., invalid instance types).
- **Configuration:** Added `.tflint.hcl` and enforced `required_version` in `main.tf` to standardize the Terraform version across the team.

### 5.2. Secret Scanning (TruffleHog)

- **Tool:** TruffleHog (v3/main)
- **Purpose:** Scans the repository history for leaked credentials.
- **Key Configuration:**
- `fetch-depth: 0`: Forces the pipeline to pull the entire git history, not just the latest commit, ensuring deep scanning.
- `--only-verified`: Checks if found keys are active to reduce false positives.

### 5.3. Infrastructure Security Scanning (Checkov)

- **Tool:** Checkov (by Prisma Cloud)
- **Purpose:** Scans Terraform code against CIS Benchmarks and security best practices.
- **Implementation & Risk Acceptance:**
- **Identified Issue:** The S3 bucket lacked versioning (Critical Risk).
- **Fix:** Updated `main.tf` to enable versioning.
- **Risk Acceptance:** Several checks (e.g., KMS encryption, Cross-Region Replication) were excessively costly for a Lab environment. These were explicitly skipped using inline comments:

```hcl
# checkov:skip=CKV_AWS_145: "Skipping KMS encryption to reduce lab costs"

```

---

## 6. Engineering Challenges & Troubleshooting Log

A summary of the critical issues encountered and resolved during implementation.

### Issue 1: "Request ARN is invalid" (The OIDC Thumbprint Saga)

- **Symptom:** The CI/CD pipeline failed to authenticate with AWS, displaying a generic `Invalid ARN` error.
- **Root Cause:** The AWS IAM Identity Provider did not have the correct/current Certificate Thumbprint for GitHub, causing the SSL handshake to fail.
- **Resolution:** Manually retrieved the GitHub OIDC thumbprints (`6938fd4d...`) and updated the provider via AWS CLI:

```bash
aws iam update-open-id-connect-provider-thumbprint ...

```

### Issue 2: The Double ARN Injection

- **Symptom:** Authentication failed despite fixing the thumbprint.
- **Root Cause:** The GitHub Secret `AWS_ACCOUNT_ID` contained the full ARN string (`arn:aws:iam::123...`) instead of just the ID (`123...`). The pipeline code concatenated this, resulting in `arn:aws:iam::arn:aws:iam::123...`.
- **Resolution:** Updated the GitHub Secret to contain only the numeric ID and adjusted the YAML workflow to construct the ARN dynamically.

### Issue 3: Shallow Clone Scanning

- **Symptom:** TruffleHog passed successfully in milliseconds without actually scanning the history.
- **Root Cause:** GitHub Actions defaults to `fetch-depth: 1` (shallow clone). TruffleHog cannot scan history that isn't there.
- **Resolution:** Updated the `actions/checkout` step to use `fetch-depth: 0`.

---

## 7. Current Workflow Architecture

The final `.github/workflows/terraform-dev.yaml` pipeline executes the following steps:

1. **Checkout Code** (Full History).
2. **TruffleHog Scan** (Fails on secrets).
3. **Setup & Run TFLint** (Fails on syntax/quality).
4. **Run Checkov** (Fails on insecure config).
5. **Configure AWS Credentials** (OIDC).
6. **Terraform Init & Plan**.

This architecture ensures that **no insecure or broken code can ever be deployed to the cloud.**
