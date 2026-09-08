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

resource "aws_s3_bucket" "demo" {
  bucket = "yoder-cicd-pipeline-demo"

  tags = {
    Name = "cicd-pipeline-demo"
  }
}