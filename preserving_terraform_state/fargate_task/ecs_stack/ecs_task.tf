
data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

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
        "awslogs-region": "${data.aws_region.current.name}",
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
  name = "/ecs/${var.ProjectName}_job"
}
