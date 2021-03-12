#######################
### Input Variables ###
#######################
variable "ProjectName" {}
variable "AWSProfile" {}
variable "ECSImageName" {
  default = "XXXECSImageNameXXX"
}
variable "ECSLoaderClusterName" {}
variable "ECSTaskDefLoader" {}
variable "TagContact" {}
variable "TagService" {}
variable "TagEnvironment" {}
variable "TagOrgID" {}
variable "TagCapacity" {}
variable "ScheduleExpression" {}

#######################
### Local Variables ###
#######################
locals {
  common_tags = {
    Contact = var.TagContact
    Service = var.TagService
    Environment = var.TagEnvironment
    OrgID = var.TagOrgID
    Capacity = var.TagCapacity
  }
}