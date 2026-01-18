# 🛡️ Secure Cloud Pipeline

## 📖 Project Overview

This project demonstrates a **DevSecOps** approach to infrastructure provisioning. The goal is to build an automated CI/CD pipeline using **GitHub Actions** that deploys **AWS** resources via **Terraform**.

> **Crucially:** This pipeline implements a **Shift-Left Security** strategy. It acts as a gatekeeper, blocking any infrastructure deployment that fails security compliance checks (SAST, Secret Scanning, IaC Scanning).

---

## 🏗️ Architecture

_(Diagram placeholder)_

**Workflow Description:**

`Developer` ➔ `Git Push` ➔ `GitHub Actions` ➔ `Security Scanners (TruffleHog, Checkov)` ➔ `Terraform Plan` ➔ `Terraform Apply` ➔ `AWS Cloud`

---

## 🛠️ Tech Stack

| Category              | Technology      | Status     |
| :-------------------- | :-------------- | :--------- |
| **Cloud**             | AWS (Free Tier) | 🟢 Active  |
| **IaC**               | Terraform       | 🟢 Active  |
| **CI/CD**             | GitHub Actions  | 🟢 Active  |
| **Secrets Detection** | TruffleHog      | 🟡 Planned |
| **IaC Scanning**      | Checkov         | 🟡 Planned |
| **SAST**              | Semgrep         | 🟡 Planned |

---

## ⚡ Initial Setup & Guardrails

Before writing any code, the environment was secured to emulate enterprise standards:

- **AWS Cost Management:**
  - Configured **AWS Budgets** to alert on **$1 spend threshold** (prevention of "bill shock").
- **IAM Hardening:**
  - Root account secured with **hardware/virtual MFA**.
  - Created dedicated **IAM User** for development (following _Least Privilege Principle_).
- **Repository Security:**
  - `.gitignore` configured immediately to prevent state file/secret leakage.
