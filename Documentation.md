# 📘 AWS Secure Cloud Pipeline – Technical Documentation

**Author:** Filip (DevSecOps Engineer)
**Status:** Phase 2 Completed (CI/CD with OIDC)
**Tech Stack:** AWS, Terraform, GitHub Actions, OpenID Connect (OIDC)

---

## 1. Executive Summary

This project aims to establish a secure, automated **Infrastructure as Code (IaC)** pipeline. Moving away from manual console operations ("ClickOps"), the infrastructure is defined in Terraform, version-controlled in Git, and deployed via GitHub Actions.

A key focus of this project is **Security-by-Design**, implementing strict access controls, state locking, and credential-less authentication using OIDC.

---

## 2. Phase 0: Security Foundations & FinOps

Before provisioning resources, the AWS environment was hardened to emulate enterprise standards.

### 2.1. Root Account Security

- **Action:** Enabled Multi-Factor Authentication (MFA) on the Root user.
- **Rationale:** The Root account has unlimited privileges. Compromise leads to total project loss. MFA is the first line of defense.

### 2.2. IAM Identity Management

- **Action:** Created a dedicated IAM User `devsecops-admin` for daily development.
- **Rationale:** Adhering to the **Least Privilege Principle**. Direct use of the Root account for daily tasks is a security anti-pattern.

### 2.3. FinOps Guardrails

- **Action:** Configured **AWS Budgets** with a specific alert threshold of **$1.00**.
- **Rationale:** To prevent "Bill Shock" caused by accidental resource provisioning (e.g., leaving a large EC2 instance running) or malicious activity (e.g., crypto-jacking).

---

## 3. Phase 1: Infrastructure as Code (Terraform)

The infrastructure layer was designed for scalability and collaboration.

### 3.1. Project Structure (Monorepo)

Adopted a directory structure that supports multiple environments within a single repository:

```text
AWS_CICD_Project/
├── secure-cloud-lab-dev/   # Development Environment
│   ├── main.tf
│   ├── .terraform.lock.hcl
│   └── .gitignore
├── secure-cloud-lab-prod/  # Production Environment (Placeholder)
└── README.md

```

### 3.2. Repository Security (`.gitignore`)

Configured Git to strictly ignore sensitive local files.

- **Ignored:** `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfvars`.
- **Rationale:** Terraform state files often contain unencrypted sensitive data (passwords, keys). Committing them to a public repository is a critical security vulnerability.

### 3.3. Remote State Management

Instead of storing the `terraform.tfstate` file locally, we implemented a **Remote Backend** architecture.

- **Components:**

1. **S3 Bucket:** Stores the encrypted state file.
2. **DynamoDB Table:** Manages state locking.

- **Configuration (`main.tf`):**

```hcl
terraform {
  backend "s3" {
    bucket         = "your-unique-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true              # Encryption at rest
    dynamodb_table = "terraform-locks" # Prevents race conditions
  }
}

```

- **Benefit:** Enables safe collaboration and prevents corruption if two processes (e.g., CI pipeline and a local developer) try to modify infrastructure simultaneously.

---

## 4. Phase 2: Automated CI/CD with OIDC

This phase replaced risky long-lived credentials with temporary, federated identities.

### 4.1. The OIDC Mechanism (OpenID Connect)

Instead of storing static `AWS_ACCESS_KEY_ID` and `SECRET_ACCESS_KEY` in GitHub Secrets (which can be leaked or need rotation), we configured AWS to trust GitHub as an Identity Provider.

- **Workflow:**

1. GitHub Actions requests a JWT (token) from GitHub's OIDC provider.
2. The workflow sends this token to AWS STS (Security Token Service).
3. AWS validates the token's signature and the repository claims.
4. AWS issues short-lived credentials (valid for 1 hour).

### 4.2. IAM Role Configuration

We created a specific role: `GitHubActions-Terraform-Role`.

- **Trust Policy (The Guardrail):**
  This JSON policy ensures only _this specific repository_ can assume the role.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::781007641435:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Milip-bit/AWS_CICD_Secure_Cloud_Lab:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### 4.3. GitHub Actions Workflow (`terraform-dev.yaml`)

The pipeline automates the `terraform plan` command.

**Key Snippet:**

```yaml
permissions:
  id-token: write # REQUIRED for OIDC token generation
  contents: read

steps:
  - name: Configure AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      # Dynamic ARN construction using Secrets
      role-to-assume: "arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActions-Terraform-Role"
      aws-region: "eu-north-1"
```

---

## 5. Engineering Challenges & Troubleshooting

During implementation, we encountered a critical error: **"Could not assume role with OIDC: Request ARN is invalid"**. This required deep debugging.

### Issue 1: Missing OIDC Thumbprint

- **Symptom:** AWS refused the connection immediately, but the error message was vague.
- **Root Cause:** The OIDC Identity Provider in AWS did not have the correct certificate thumbprint for GitHub. AWS could not verify the SSL chain of trust.
- **Resolution:** We manually updated the thumbprint list using the AWS CLI:

```bash
aws iam update-open-id-connect-provider-thumbprint \
  --open-id-connect-provider-arn arn:aws:iam::... \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd

```

### Issue 2: Secret Misconfiguration (The "Double ARN" Bug)

- **Symptom:** Even after fixing the thumbprint, the error persisted.
- **Root Cause:** The GitHub Secret `AWS_ACCOUNT_ID` was incorrectly set to the _full ARN string_ (`arn:aws:iam::78...`) instead of just the numeric ID (`78...`).
- **Result:** The pipeline constructed a malformed string:
  `arn:aws:iam::arn:aws:iam::781007641435:role/...`
- **Resolution:** Updated the GitHub Secret to contain **only** the 12-digit Account ID.

---

## 6. Current Status & Next Steps

**Achievements:**
✅ Secure AWS Environment (MFA, FinOps).
✅ Production-ready Terraform State (S3 + DynamoDB).
✅ Password-less CI/CD authentication via OIDC.

**Upcoming Roadmap (Phase 3):**

- **Static Analysis:** Implementing `tflint` for code quality.
- **Security Scanning:** Integrating **TruffleHog** (secret detection) and **Checkov** (IaC security scanning) to block insecure infrastructure before deployment.

---

**End of Document**
