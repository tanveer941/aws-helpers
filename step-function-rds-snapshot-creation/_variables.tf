variable "ProjectName" {
  type = string
  default = null
}
variable "GroupName" {}
variable "OwnerName" {}
variable "Moniker" {}
variable "AWSProfile" {
  type = string
  default = "default"
}
variable "Vpc" {
  type = string
  default = null
}
variable "Subnet1" {
  type = string
  default = null
}
variable "CodeBucket" {
  type = string
  default = null
}
variable "TFVersion" {
  type = string
  default = "0.14.6"
}
variable "CPArtifactBucket" {
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
    group_name: var.GroupName
    owner_name: var.OwnerName
    "adsk:moniker": var.Moniker
  }
}