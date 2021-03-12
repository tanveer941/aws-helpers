### IAM Role ###
data "aws_iam_policy_document" "LambdaRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}
data "aws_iam_policy_document" "CPPolicy" {
  statement {
    actions = [
      "apigateway:*",
      "application-autoscaling:*",
      "autoscaling:*",
      "cloudformation:*",
      "cloudwatch:*",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive",
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "codepipeline:StartPipelineExecution",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "ec2:*",
      "ecs:*",
      "elasticbeanstalk:*",
      "elasticloadbalancing:*",
      "glue:*",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "lambda:*",
      "opsworks:CreateDeployment",
      "opsworks:DescribeApps",
      "opsworks:DescribeCommands",
      "opsworks:DescribeDeployments",
      "opsworks:DescribeInstances",
      "opsworks:DescribeStacks",
      "opsworks:UpdateApp",
      "opsworks:UpdateStack",
      "rds:*",
      "s3:*",
      "sns:*",
      "sqs:*",
      "states:*"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.Me.account_id}:role/*"
    ]
  }
  statement {
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:GetPolicy",
      "iam:ListPolicyVersions"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.Me.account_id}:policy/*"
    ]
  }
}
data "aws_iam_policy_document" "CodeBuildAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["codebuild.amazonaws.com"]
      type = "Service"
    }
  }
}
data "aws_iam_policy_document" "CodePipelineAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["codepipeline.amazonaws.com"]
      type = "Service"
    }
  }
}

## Loader Role ##
resource "aws_iam_role" "LoaderRole" {
  name = "${var.ProjectName}-LoaderRole"
  assume_role_policy = data.aws_iam_policy_document.CodeBuildAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy" "LoaderRolePolicy" {
  name = "${var.ProjectName}-LoaderRolePolicy"
  role = aws_iam_role.LoaderRole.id
  policy = data.aws_iam_policy_document.CPPolicy.json
}
resource "aws_iam_role_policy_attachment" "LoaderRoleS3" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "LoaderRoleCW" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
resource "aws_iam_role_policy_attachment" "LoaderRoleEC2" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_iam_role_policy_attachment" "LoaderRoleSSM" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "LoaderRoleR53" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}
resource "aws_iam_role_policy_attachment" "LoaderRoleCWE" {
  role = aws_iam_role.LoaderRole.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchEventsFullAccess"
}

## Pipeline Role ##
resource "aws_iam_role" "PipelineRole" {
  name = "${var.ProjectName}-PipelineRole"
  assume_role_policy = data.aws_iam_policy_document.CodePipelineAssumePolicy.json
  tags = local.common_tags
}
resource "aws_iam_role_policy" "CPRolePolicy" {
  name = "${var.ProjectName}-PipelineRolePolicy"
  role = aws_iam_role.PipelineRole.id
  policy = data.aws_iam_policy_document.CPPolicy.json
}