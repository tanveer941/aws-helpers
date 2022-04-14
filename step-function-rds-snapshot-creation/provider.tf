### Initialization Values ###
terraform {
#  required_version = ">= 0.13.0, < 0.15.0"
  required_version = ">= 0.15"
  backend "s3" {
    bucket = "icm-pe-dev-us-east-1-repo"
    key    = "eih-step-function/application.tfstate"
    region = "us-east-1"
    dynamodb_table = "eih-step-function"
    profile = "default"
  }
}

provider "aws" {
  version = "~> 3.0"
  region = "us-east-1"
  profile = var.AWSProfile
}