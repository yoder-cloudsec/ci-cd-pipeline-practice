terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "yoder-terraform-state-bucket"
    key = "cicd-pipeline-practice/terraform.tfstate"
    region = "eu-south-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
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