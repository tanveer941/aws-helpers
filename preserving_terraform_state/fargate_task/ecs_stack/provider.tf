### Initialization Values ###
terraform {
  required_version = ">= 0.13.0, < 0.15.0"
  backend "s3" {
    bucket = "bucket_name"
    key    = "Dev/task.tfstate"
    region = "ap-south-1"
    dynamodb_table = "Red-Thunder"
    profile = "default"
  }
}

provider "aws" {
  version = "~> 3.0"
  profile = var.AWSProfile
}