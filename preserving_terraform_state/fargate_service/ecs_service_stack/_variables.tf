#######################
### Input Variables ###
#######################
variable "ProjectName" {}
variable "AWSProfile" {}
variable "ECSImageName" {
  default = "XXXECSImageNameXXX"
}
variable "ECSClusterName" {}
variable "ECSTaskDef" {}
variable "TagContact" {}
variable "TagService" {}
variable "TagEnvironment" {}
variable "TagOrgID" {}
variable "TagCapacity" {}
variable "ScheduleExpression" {}
variable "Vpc" {
  type = string
  default = null
}
variable "Subnet1" {
  type = string
  default = null
}
variable "Subnet2" {
  type = string
  default = null
}
variable "ECSDomainName" {}
variable "ECSDNSName" {}

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