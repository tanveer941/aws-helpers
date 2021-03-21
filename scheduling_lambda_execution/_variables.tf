#######################
### Input Variables ###
#######################
variable "ProjectName" {}
variable "AWSProfile" {}
variable "TagContact" {}
variable "ScheduleExpression" {}
variable "CodeBucket" {}
variable "BucketKeyZip" {}
variable "package_type" {
  type        = string
  default     = "Zip"
  description = "The Lambda deployment package type. Valid values are Zip and Image. Defaults to Zip."
}


#######################
### Local Variables ###
#######################
locals {
  common_tags = {
    Contact = var.TagContact
  }
}