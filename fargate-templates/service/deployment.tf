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
variable "ECSPublicSubnet1" {}
variable "ECSPublicSubnet2" {}
variable "ECSUsePublicLoadBalancer" {}
variable "ECSCertificate" {}
variable "ECSHealthCheck" {}
variable "ECSDomainName" {}
variable "ECSDNSName" {}
variable "ECSClusterName" {}
variable "ECSTaskDefName" {}
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
data "aws_iam_policy_document" "ECSAutoScaleRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["application-autoscaling.amazonaws.com"]
      type = "Service"
    }
  }
}
data "aws_route53_zone" "ECSDomainZone" {
  name = var.ECSDomainName
  private_zone = var.ECSUsePublicLoadBalancer ? false : true
}


#####################
### IAM Resources ###
#####################
resource "aws_iam_role" "ECSExecuteRole" {
  name = "${var.FSKDeploymentProjectName}-Api-ECSExecuteRole"
  assume_role_policy = data.aws_iam_policy_document.ECSExecuteRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSExecuteRoleECS" {
  role = aws_iam_role.ECSExecuteRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ECSTaskRole" {
  name = "${var.FSKDeploymentProjectName}-Api-ECSTaskRole"
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
resource "aws_iam_role" "ECSLambdaRole" {
  name = "${var.FSKDeploymentProjectName}-Api-ECSLambdaRole"
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
resource "aws_iam_role" "ECSAutoScaleRole" {
  name = "${var.FSKDeploymentProjectName}-ECSAutoScaleRole"
  assume_role_policy = data.aws_iam_policy_document.ECSAutoScaleRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSAutoScaleRoleAS" {
  role = aws_iam_role.ECSAutoScaleRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}


#####################
### ECS Resources ###
#####################
resource "aws_ecs_cluster" "ECSCluster" {
  name = var.ECSClusterName
  tags = local.common_tags
}
resource "aws_ecs_task_definition" "ECSTaskDef" {
  family = var.ECSTaskDefName
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
    "name": "${var.ECSTaskDefName}",
    "image": "${var.ECSImageName}",
    "portMappings": [
      {
        "hostPort": 80,
        "protocol": "tcp",
        "containerPort": 80
      }
    ],
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
resource "aws_ecs_service" "ECSService" {
  name = "${var.FSKDeploymentProjectName}-ECSService"
  depends_on = [
    aws_lb_listener.ECSLoadBalancerListener
  ]
  cluster = aws_ecs_cluster.ECSCluster.arn
  desired_count = 2
  launch_type = "FARGATE"
  load_balancer {
    container_name = aws_ecs_task_definition.ECSTaskDef.family
    container_port = 80
    target_group_arn = aws_lb_target_group.ECSTargetGroup.arn
  }
  propagate_tags = "SERVICE"
  task_definition = aws_ecs_task_definition.ECSTaskDef.arn
  network_configuration {
    subnets = [
      var.AppSubnet1,
      var.AppSubnet2
    ]
    assign_public_ip = false
    security_groups = [
      aws_security_group.ECSSecurityGroup.id
    ]
  }
  tags = local.common_tags
}


################################
### CloudWatch Log Resources ###
################################
resource "aws_cloudwatch_log_group" "ECSLogGroup" {
  name = "${var.FSKDeploymentProjectName}-ECSLogGroup"
}
resource "aws_cloudwatch_log_subscription_filter" "ECSLogGroupSubscription" {
  name = "${var.FSKDeploymentProjectName}-ECSLogGroupSubscription"
  destination_arn = aws_lambda_function.ECSSumoLogicLambda.arn
  filter_pattern = ""
  log_group_name = aws_cloudwatch_log_group.ECSLogGroup.name
}


#####################
### VPC Resources ###
#####################
resource "aws_security_group" "ECSSecurityGroup" {
  name = "${var.FSKDeploymentProjectName}-Container"
  vpc_id = var.AppVpc
  ingress {
    description = "HTTP"
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "All"
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}


#####################
### ELB Resources ###
#####################
resource "aws_lb_target_group" "ECSTargetGroup" {
  name = "${var.FSKDeploymentProjectName}-ECSTargetGroup"
  health_check {
    path = var.ECSHealthCheck
    protocol = "HTTP"
  }
  port = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = var.AppVpc
  tags = local.common_tags
}
resource "aws_lb" "ECSLoadBalancer" {
  name = substr(join("", [var.FSKDeploymentProjectName, "-ECSLoadBalancer"]), 0, 32)
  internal = var.ECSUsePublicLoadBalancer ? false : true
  ip_address_type = "ipv4"
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.ECSSecurityGroup.id
  ]
  subnets = [
    var.ECSUsePublicLoadBalancer ? var.ECSPublicSubnet1 : var.AppSubnet1,
    var.ECSUsePublicLoadBalancer ? var.ECSPublicSubnet2 : var.AppSubnet2
  ]
  tags = local.common_tags
}
resource "aws_lb_listener" "ECSLoadBalancerListener" {
  load_balancer_arn = aws_lb.ECSLoadBalancer.arn
  port = var.ECSUseSSL ? 443 : 80
  protocol = var.ECSUseSSL ? "HTTPS" : "HTTP"
  certificate_arn = var.ECSUseSSL ? var.ECSCertificate : null
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ECSTargetGroup.arn
  }
}


#########################
### Route53 Resources ###
#########################
resource "aws_route53_record" "ECSRecordSet" {
  name = var.ECSDNSName
  type = "A"
  zone_id = data.aws_route53_zone.ECSDomainZone.zone_id
  alias {
    evaluate_target_health = false
    name = aws_lb.ECSLoadBalancer.dns_name
    zone_id = aws_lb.ECSLoadBalancer.zone_id
  }
}


#########################
### Lambda Resources ###
#########################
resource "aws_lambda_function" "ECSSumoLogicLambda" {
  function_name = "${var.FSKDeploymentProjectName}-Api-ECSSumoLogicLambda"
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


#############################
### AutoScaling Resources ###
#############################
resource "aws_appautoscaling_target" "ECSAutoScaleTarget" {
  max_capacity = 10
  min_capacity = 2
  resource_id = "service/${aws_ecs_cluster.ECSCluster.name}/${aws_ecs_service.ECSService.name}"
  role_arn = aws_iam_role.ECSAutoScaleRole.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}
resource "aws_appautoscaling_policy" "ECSAutoScaleCPUPolicy" {
  name = "${var.FSKDeploymentProjectName}-ECSAutoScaleCPUPolicy"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.ECSAutoScaleTarget.resource_id
  scalable_dimension = aws_appautoscaling_target.ECSAutoScaleTarget.scalable_dimension
  service_namespace = aws_appautoscaling_target.ECSAutoScaleTarget.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 80
    scale_in_cooldown = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
resource "aws_appautoscaling_policy" "ECSAutoScaleMemPolicy" {
  name = "${var.FSKDeploymentProjectName}-ECSAutoScaleMemPolicy"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.ECSAutoScaleTarget.resource_id
  scalable_dimension = aws_appautoscaling_target.ECSAutoScaleTarget.scalable_dimension
  service_namespace = aws_appautoscaling_target.ECSAutoScaleTarget.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 80
    scale_in_cooldown = 300
    scale_out_cooldown = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}


###############
### Outputs ###
###############
output "ServiceURL" {
  value = var.ECSUseSSL ? "https://${var.ECSDNSName}" : "http://${var.ECSDNSName}"
}
