terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-south-2"
}
# demo bucket for CI/CD pipeline practice
resource "aws_s3_bucket" "demo" {
  bucket = "yoder-cicd-pipeline-demo"

  tags = {
    Name = "cicd-pipeline-demo"
  }
}