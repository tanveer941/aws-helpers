
data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

data "aws_route53_zone" "ECSDomainZone" {
  name = var.ECSDomainName
  private_zone = true
}

#####################
### ECS Resources ###
#####################
resource "aws_ecs_cluster" "ECSCluster" {
  name = var.ECSClusterName
  tags = local.common_tags
}


resource "aws_ecs_task_definition" "ECSTaskDef" {
  family = var.ECSTaskDef
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
    "name": "${var.ECSTaskDef}",
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
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
  tags = local.common_tags
}

resource "aws_security_group" "SecurityGroup" {
  name = "${var.ProjectName}-Api"
  vpc_id = var.Vpc
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

### ELB Resources ###
#####################
resource "aws_lb_target_group" "ECSTargetGroup" {
  name = "${var.ProjectName}-ECSTargetGroup"
  health_check {
    path = "/api/health"
    protocol = "HTTP"
  }
  port = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = var.Vpc
  tags = local.common_tags
}
resource "aws_lb" "ECSLoadBalancer" {
  name = substr(join("", [var.ProjectName, "-ECSLoadBalancer"]), 0, 32)
  internal = true
  ip_address_type = "ipv4"
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.SecurityGroup.id
  ]
  subnets = [
    var.Subnet1,
    var.Subnet2
  ]
  tags = local.common_tags
}
resource "aws_lb_listener" "ECSLoadBalancerListener" {
  load_balancer_arn = aws_lb.ECSLoadBalancer.arn
  port = 80
  protocol = "HTTP"
  certificate_arn = null
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ECSTargetGroup.arn
  }
}

resource "aws_ecs_service" "ECSService" {
  name = "${var.ProjectName}-ECSService"
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
      var.Subnet1,
      var.Subnet2
    ]
    assign_public_ip = false
    security_groups = [
      aws_security_group.SecurityGroup.id
    ]
  }
  tags = local.common_tags
}


################################
### CloudWatch Log Resources ###
################################
resource "aws_cloudwatch_log_group" "ECSLogGroup" {
  name = "/ecs/${var.ProjectName}_server"
}

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
  name = "${var.ProjectName}-ECSAutoScaleCPUPolicy"
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
  name = "${var.ProjectName}-ECSAutoScaleMemPolicy"
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
  value = "http://${var.ECSDNSName}"
}