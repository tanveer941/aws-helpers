#######################
### Input Variables ###
#######################
variable "FSKDeploymentProjectName" {}
variable "AWSProfile" {}
variable "ECSImageName" {
  default = "XXXECSImageNameXXX"
}
variable "ECSUseSSL" {}
variable "ECSLogRegion" {}
variable "AppVpc" {}
variable "AppSubnet1" {}
variable "AppSubnet2" {}
variable "InvokeSecurityGroup" {}
variable "ECSPublicSubnet1" {}
variable "ECSPublicSubnet2" {}
variable "ECSUsePublicLoadBalancer" {}
variable "ECSCertificate" {}
variable "ECSHealthCheck" {}
variable "ECSDomainName" {}
variable "ECSDNSName" {}
variable "ECSClusterName" {}
variable "ECSTaskDefName" {}
variable "ECSLoaderClusterName" {}
variable "ECSTaskDefLoader" {}
variable "LambdaUseScheduler" {}
variable "LambdaStateMachineSchedule" {}
variable "SuccessTopicName" {}
variable "FailureTopicName" {}
variable "SumoEndpoint" {}
variable "CodeBucket" {}
variable "TagContact" {}
variable "TagService" {}
variable "TagEnvironment" {}
variable "TagOrgID" {}
variable "TagCapacity" {}
variable "BatchScheduleExpression" {}
variable "ReportScheduleExpression" {}


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


#############################
### Initialization Values ###
#############################
terraform {
  required_version = "~> 0.13"
  backend "s3" {}
}

provider "aws" {
  version = "~> 3.3.0"
  region = var.ECSLogRegion
  profile = var.AWSProfile
  ignore_tags {
    key_prefixes = ["c7n:"]
  }
}


####################
### Data Sources ###
####################
data "aws_caller_identity" "Me" {}
data "aws_iam_policy_document" "ECSExecuteRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type = "Service"
    }
  }
}
data "aws_iam_policy_document" "ECSTaskRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type = "Service"
    }
  }
}
data "aws_iam_policy_document" "ECSLambdaRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}


#####################
### IAM Resources ###
#####################
resource "aws_iam_role" "ECSExecuteRole" {
  name = "${var.FSKDeploymentProjectName}-ECSExecuteRole"
  assume_role_policy = data.aws_iam_policy_document.ECSExecuteRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSExecuteRoleECS" {
  role = aws_iam_role.ECSExecuteRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ECSTaskRole" {
  name = "${var.FSKDeploymentProjectName}-ECSTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ECSTaskRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSTaskRoleS3" {
  role = aws_iam_role.ECSTaskRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "ECSTaskRoleSM" {
  role = aws_iam_role.ECSTaskRole.id
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
resource "aws_iam_role_policy_attachment" "ECSTaskRoleCW" {
  role = aws_iam_role.ECSTaskRole.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
resource "aws_iam_role" "ECSLambdaRole" {
  name = "${var.FSKDeploymentProjectName}-ECSLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.ECSLambdaRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSLambdaRoleS3" {
  role = aws_iam_role.ECSLambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "ECSLambdaRoleECS" {
  role = aws_iam_role.ECSLambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
resource "aws_iam_role_policy_attachment" "ECSLambdaRoleLambda" {
  role = aws_iam_role.ECSLambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


#####################
### ECS Resources ###
#####################
resource "aws_ecs_cluster" "ECSCluster" {
  name = var.ECSLoaderClusterName
  tags = local.common_tags
}
resource "aws_ecs_task_definition" "ECSTaskDef" {
  family = var.ECSTaskDefLoader
  cpu = "512"
  execution_role_arn = aws_iam_role.ECSExecuteRole.arn
  memory = "1024"
  network_mode = "awsvpc"
  requires_compatibilities = [
    "FARGATE"
  ]
  task_role_arn = aws_iam_role.ECSTaskRole.arn
  container_definitions = <<EOF
[
  {
    "name": "${var.ECSTaskDefLoader}",
    "image": "${var.ECSImageName}",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.ECSLogGroup.name}",
        "awslogs-region": "${var.ECSLogRegion}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
  tags = local.common_tags
}


################################
### CloudWatch Log Resources ###
################################
resource "aws_cloudwatch_log_group" "ECSLogGroup" {
  name = "/ecs/${var.FSKDeploymentProjectName}_loader"
}
resource "aws_cloudwatch_log_subscription_filter" "ECSLogGroupSubscription" {
  name = "${var.FSKDeploymentProjectName}-ECSLogGroupSubscription"
  destination_arn = aws_lambda_function.ECSSumoLogicLambda.arn
  filter_pattern = ""
  log_group_name = aws_cloudwatch_log_group.ECSLogGroup.name
}


#########################
### Lambda Resources ###
#########################
resource "aws_lambda_function" "ECSSumoLogicLambda" {
  function_name = "${var.FSKDeploymentProjectName}-ECSSumoLogicLambda"
  handler = "cloudwatchlogs_lambda.handler"
  role = aws_iam_role.ECSLambdaRole.arn
  runtime = "nodejs10.x"
  environment {
    variables = {
      SUMO_ENDPOINT = var.SumoEndpoint
    }
  }
  s3_bucket = "zipfiles-${var.ECSLogRegion}"
  s3_key = "cloudwatchlogs.zip"
  timeout = 300
  tags = local.common_tags
}
resource "aws_lambda_permission" "ECSLogGroupSubscriptionPermission" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ECSSumoLogicLambda.function_name
  principal = "logs.${var.ECSLogRegion}.amazonaws.com"
  source_account = data.aws_caller_identity.Me.account_id
}
