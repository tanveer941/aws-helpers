variable "ProjectName" {
  type = string
  default = null
}
variable "TagContact" {
  type = string
  default = null
}
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
variable "AWSProfile" {
  type = string
  default = "default"
}
variable "ImageName" {
  type = string
  default = null
}
variable "ImageTag" {
  type = string
  default = null
}
variable "ScheduleExpression" {
  type = string
  default = null
}
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
variable "UseContainer" {
  type = string
  default = "true"
}
variable "CodeBucket" {
  type = string
  default = null
}
variable "ContainerStateKey" {
  type = string
  default = "true"
}
variable "TFVersion" {
  type = string
  default = "0.14.6"
}
variable "CPArtifactBucket" {
  type = string
  default = null
}
variable "CodeZip" {
  type = string
  default = null
}
variable "RepoName" {
  type = string
  default = null
}

##### Local Variables #######
locals {
  common_tags = {
    Contact = var.TagContact
    Service = var.TagService
    Environment = var.TagEnvironment
    OrgID = var.TagOrgID
    Capacity = var.TagCapacity
  }
}