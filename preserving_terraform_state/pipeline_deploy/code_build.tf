
### CodeBuild Resources ###
###########################
resource "aws_codebuild_project" "Loader" {
  count = var.UseContainer ? 1 : 0
  name = "${var.ProjectName}-Loader"
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/standard:4.0"
    type = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name = "AWS_ACCOUNT_ID"
      type = "PLAINTEXT"
      value = data.aws_caller_identity.Me.account_id
    }
    environment_variable {
      name = "IMAGE_NAME"
      type = "PLAINTEXT"
      value = "${data.aws_caller_identity.Me.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${var.RepoName}"
    }
    environment_variable {
      name = "PROJECT_DIR"
      type = "PLAINTEXT"
      value = "fargate_task/job"
    }
    environment_variable {
      name = "DEPLOYMENT_PROJECT_NAME"
      type = "PLAINTEXT"
      value = var.ProjectName
    }
    environment_variable {
      name = "RELEASE_VERSION"
      type = "PLAINTEXT"
      value = "1.0.0"
    }
  }
  service_role = aws_iam_role.LoaderRole.arn
  source {
    type = "CODEPIPELINE"
    buildspec = "fargate_task/buildspec.yml"
  }
  vpc_config {
    security_group_ids = [
      aws_security_group.SecurityGroup.id
    ]
    subnets = [
      var.Subnet1,
      var.Subnet2
    ]
    vpc_id = var.Vpc
  }
  tags = local.common_tags
}

resource "aws_codebuild_project" "DeployLoader" {
  count = var.UseContainer ? 1 : 0
  name = "${var.ProjectName}-DeployLoader"
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/standard:4.0"
    type = "LINUX_CONTAINER"
    environment_variable {
      name = "DEPLOYMENT_PROJECT_NAME"
      type = "PLAINTEXT"
      value = var.ProjectName
    }
    environment_variable {
      name = "BUCKET"
      type = "PLAINTEXT"
      value = var.CodeBucket
    }
    environment_variable {
      name = "TF_STATE_S3_KEY"
      type = "PLAINTEXT"
      value = var.ContainerStateKey
    }
    environment_variable {
      name = "TF_VERSION"
      type = "PLAINTEXT"
      value = var.TFVersion
    }
  }
  service_role = aws_iam_role.LoaderRole.arn
  source {
    type = "CODEPIPELINE"
    buildspec = "deploy_terraform.yml"
  }
  vpc_config {
    security_group_ids = [
      aws_security_group.SecurityGroup.id
    ]
    subnets = [
      var.Subnet1,
      var.Subnet2,
    ]
    vpc_id = var.Vpc
  }
  tags = local.common_tags
}