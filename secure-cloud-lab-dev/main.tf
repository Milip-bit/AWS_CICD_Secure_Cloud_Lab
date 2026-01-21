#Test of Trufflehog 3
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
    key            = "global/s3/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "test-bucket" {
  bucket = "milip-secure-lab-bucket-001"

  # checkov:skip=CKV_AWS_145: "Uzywamy standardowego szyfrowania SSE-S3 zamiast KMS zeby uniknac kosztow w Labie"
  # checkov:skip=CKV_AWS_18: "Logowanie dostepu wymaga dodatkowego bucketa, pomijamy w Labie"
  # checkov:skip=CKV_AWS_144: "Replikacja miedzy regionami nie jest wymagana w srodowisku Dev"
  # checkov:skip=CKV2_AWS_61: "Lifecycle configuration nie jest wymagana w Labie"
  # checkov:skip=CKV2_AWS_62: "Powiadomienia o zdarzeniach nie sa wymagane"
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
    Project     = "SecurePipeline"
  }
}
resource "aws_s3_bucket_versioning" "test_bucket_versioning" {
  bucket = aws_s3_bucket.test-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "test-bucket-block" {
  bucket = aws_s3_bucket.test-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
