# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "my-terraform-state-bucket1356783"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  } 
}

provider "aws" {
  region = var.aws_region
}
