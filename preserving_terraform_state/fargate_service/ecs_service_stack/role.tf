
####################
### Data Sources ###
####################

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

#####################
### IAM Resources ###
#####################
resource "aws_iam_role" "ECSExecuteRole" {
  name = "${var.ProjectName}-ECSExecuteRole"
  assume_role_policy = data.aws_iam_policy_document.ECSExecuteRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSExecuteRoleECS" {
  role = aws_iam_role.ECSExecuteRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ECSTaskRole" {
  name = "${var.ProjectName}-ECSTaskRole"
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

resource "aws_iam_role" "ECSAutoScaleRole" {
  name = "${var.ProjectName}-ECSAutoScaleRole"
  assume_role_policy = data.aws_iam_policy_document.ECSAutoScaleRoleAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ECSAutoScaleRoleAS" {
  role = aws_iam_role.ECSAutoScaleRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}