#######################
### Input Variables ###
#######################
variable "ProjectName" {}
variable "AWSProfile" {}
variable "TagContact" {}
variable "TagService" {
  type = string
  default = null
}
variable "TagEnvironment" {
  type = string
  default = null
}
variable "TagOrgID" {
  type = number
  default = null
}
variable "TagCapacity" {
  type = string
  default = null
}
variable "ScheduleExpression" {}
variable "CodeBucket" {}
variable "BucketKeyZip" {}
variable "package_type" {
  type        = string
  default     = "Zip"
  description = "The Lambda deployment package type. Valid values are Zip and Image. Defaults to Zip."
}
variable "SuccessTopicName" {}
variable "FailureTopicName" {}

#######################
### Local Variables ###
#######################
//tags = merge(local.common_tags, map("Name", "${title(var.service)}8-${title(var.environment)}-${each.value}"))

locals {
  common_tags = {
    Contact = var.TagContact
    Service = var.TagService
    Environment = var.TagEnvironment
    OrgID = var.TagOrgID
    Capacity = var.TagCapacity
  }
}