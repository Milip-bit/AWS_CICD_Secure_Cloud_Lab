terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "milip-tf-state-backend-001"  # Nazwa bucketu z Kroku 1
    key            = "global/s3/terraform.tfstate" # Ścieżka do pliku wewnątrz bucketu
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"         # Nazwa tabeli z Kroku 2
    encrypt        = true                      # Szyfrowanie stanu na dysku AWS
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "test-bucket" {
  bucket = "milip-secure-lab-bucket-001"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
    Project     = "SecurePipeline"
  }
}

resource "aws_s3_bucket_public_access_block" "test-bucket-block" {
  bucket = aws_s3_bucket.test-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
