# Trigger deployment
terraform {
  required_version = ">= 1.0.0"
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "milip-tf-state-backend-001"
    key            = "prod/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "prod-bucket" {
  bucket = "milip-secure-lab-bucket-prod-001"                                             

  # checkov:skip=CKV_AWS_145: "Using standard SSE-S3 encryption instead of KMS to avoid extra costs in Lab"
  # checkov:skip=CKV_AWS_18: "Access logging requires an extra bucket; skipped for Lab simplicity"
  # checkov:skip=CKV_AWS_144: "Cross-region replication is not required for the Dev environment"
  # checkov:skip=CKV2_AWS_61: "Lifecycle configuration is not required for this Lab resource"
  # checkov:skip=CKV2_AWS_62: "S3 event notifications are not required for this use case"

  tags = {
    Name        = "My Production Bucket"
    Environment = "Prod"
    Project     = "SecurePipeline"
  }
}
resource "aws_s3_bucket_versioning" "prod_bucket_versioning" {
  bucket = aws_s3_bucket.prod-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "prod-bucket-block" {
  bucket = aws_s3_bucket.prod-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}