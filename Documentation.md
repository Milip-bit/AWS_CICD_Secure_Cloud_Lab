# 📘 AWS Secure Cloud Pipeline – Comprehensive Technical Documentation

**Author:** Filip (DevSecOps Engineer)
**Date:** January 2026
**Project Status:** Completed (Multi-Environment DevSecOps Pipeline)

---

## 1. Executive Summary

This project demonstrates the implementation of a **Secure-by-Design** cloud infrastructure pipeline. The goal was to eliminate manual console operations ("ClickOps") in favor of a fully automated **Infrastructure as Code (IaC)** model using Terraform and GitHub Actions.

A critical focus was placed on **Shift-Left Security**—integrating security controls (Static Analysis, Secret Scanning, Policy Compliance) into the earliest stages of the CI/CD pipeline, ensuring that insecure code is rejected before it ever reaches the AWS cloud.

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

Adopted a directory structure supporting multiple environments within a single repository:

```text
AWS_CICD_Project/
├── secure-cloud-lab-dev/   # Development Environment
│   ├── main.tf
│   ├── .tflint.hcl
│   └── .gitignore
├── secure-cloud-lab-prod/  # Production Environment
│   ├── main.tf             # Mirrored configuration with Prod-specific values
│   └── .tflint.hcl
└── README.md

```

### 3.2. Remote State Management

Instead of storing the `terraform.tfstate` file locally (which poses security risks and hinders collaboration), a Remote Backend architecture was deployed:

- **Storage (S3):** The state file is stored in a private S3 bucket with **Server-Side Encryption (SSE-S3)** enabled.
- **Isolation:** `dev` state is stored at key `dev/terraform.tfstate`, and `prod` state at `prod/terraform.tfstate`.
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

### 5.2. Secret Scanning (TruffleHog)

- **Tool:** TruffleHog (v3/main)
- **Purpose:** Scans the repository history for leaked credentials.
- **Key Configuration:**
- `fetch-depth: 0`: Forces the pipeline to pull the entire git history, not just the latest commit, ensuring deep scanning.
- `--only-verified`: Checks if found keys are active to reduce false positives.

### 5.3. Infrastructure Security Scanning (Checkov)

- **Tool:** Checkov (by Prisma Cloud)
- **Purpose:** Scans Terraform code against CIS Benchmarks and security best practices.
- **Risk Acceptance Strategy:**
- **Fix:** Critical issues (like missing S3 versioning) were fixed in `main.tf`.
- **Skip:** Cost-prohibitive rules for a Lab environment (like KMS encryption or Cross-Region Replication) were explicitly skipped using inline comments with justifications:

```hcl
# checkov:skip=CKV_AWS_145: "Using standard SSE-S3 encryption instead of KMS to avoid extra costs in Lab"

```

---

## 6. Phase 4: Multi-Environment Lifecycle Management

We implemented full lifecycle control for both Development and Production environments.

### 6.1. Deployment Strategy

- **Trigger:** Push to `main` branch.
- **Logic:**
- Changes in `secure-cloud-lab-dev/` trigger the Dev pipeline.
- Changes in `secure-cloud-lab-prod/` trigger the Prod pipeline.

- **Action:** `terraform apply -auto-approve` is executed only if all security gates pass.

### 6.2. Destruction Strategy (FinOps)

- **Trigger:** Manual (`workflow_dispatch`).
- **Implementation:** Two separate workflows (`terraform-destroy.yaml` and `terraform-destroy-prod.yaml`) were created.
- **Mechanism:** Each workflow sets the specific `working-directory` to ensure Terraform loads the correct state file (`dev` vs `prod`) before executing `destroy`.

---

## 7. Engineering Challenges & Troubleshooting Log

A summary of the critical issues encountered and resolved during implementation.

### Issue 1: "Request ARN is invalid" (The OIDC Thumbprint Saga)

- **Symptom:** The CI/CD pipeline failed to authenticate with AWS, displaying a generic `Invalid ARN` error.
- **Root Cause:** The AWS IAM Identity Provider did not have the correct/current Certificate Thumbprint for GitHub, causing the SSL handshake to fail.
- **Resolution:** Manually retrieved the GitHub OIDC thumbprints and updated the provider via AWS CLI.

### Issue 2: The Double ARN Injection

- **Symptom:** Authentication failed despite fixing the thumbprint.
- **Root Cause:** The GitHub Secret `AWS_ACCOUNT_ID` was misused in the YAML string interpolation, resulting in a malformed ARN: `arn:aws:iam::arn:aws:iam::123...`.
- **Resolution:** Corrected the YAML configuration to properly construct the ARN.

### Issue 3: Shallow Clone Scanning

- **Symptom:** TruffleHog passed successfully in milliseconds without actually scanning the history.
- **Root Cause:** GitHub Actions defaults to `fetch-depth: 1` (shallow clone). TruffleHog cannot scan history that isn't there.
- **Resolution:** Updated the `actions/checkout` step to use `fetch-depth: 0`.

### Issue 4: "NoSuchBucket" during Prod Initialization

- **Symptom:** The Prod pipeline failed to initialize the backend.
- **Root Cause:** The `secure-cloud-lab-prod/main.tf` configuration pointed to a backend bucket name that did not exist (a copy-paste error implying a separate backend bucket for prod).
- **Resolution:** Updated the configuration to use the **same** physical S3 bucket as Dev, but with a different `key` path (`prod/terraform.tfstate`).

---

## 8. Conclusion

The resulting architecture is a robust, enterprise-grade foundation for cloud infrastructure. It ensures that security is not an afterthought but a prerequisite for deployment, while maintaining the flexibility to manage multiple environments and control costs effectively.
