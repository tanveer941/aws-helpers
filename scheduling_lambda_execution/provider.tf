### Initialization Values ###
terraform {
  required_version = ">= 0.13.0, < 0.15.0"
  backend "local" {}
}

provider "aws" {
  version = "~> 3.0"
  profile = var.AWSProfile
}