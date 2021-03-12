data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

### ECR Resources ###
resource "aws_ecr_repository" "ECRRepo" {
  name = var.RepoName
  tags = local.common_tags
}

### ECR Lifecycle policy ###
resource "aws_ecr_lifecycle_policy" "LifeCyclePolicy" {
  repository = aws_ecr_repository.ECRRepo.name
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 2 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["1.0.0"],
                "countType": "imageCountMoreThan",
                "countNumber": 2
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

### VPC Resources ###
#####################
resource "aws_security_group" "SecurityGroup" {
  name = "${var.ProjectName}-SecurityGroup"
  vpc_id = var.Vpc
  egress {
    description = "All"
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.common_tags
}

###  Codepipeline resources  ###

resource "aws_codepipeline" "CPPipe" {
  name = "${var.ProjectName}-Pipeline"
  role_arn = aws_iam_role.PipelineRole.arn
  artifact_store {
    location = var.CPArtifactBucket
    type = "S3"
  }
  stage {
    name = "Source"
    action {
      category = "Source"
      name = "Source"
      owner = "AWS"
      provider = "S3"
      version = "1"
      configuration = {
        PollForSourceChanges = false
        S3Bucket = var.CodeBucket
        S3ObjectKey = var.CodeZip
      }
      output_artifacts = [
        "SourceCode"
      ]
      region = data.aws_region.current.name
    }
  }
  dynamic "stage" {
    for_each = var.UseContainer ? [1] : []
    content {
      name = "Loader-Build"
      action {
        category = "Build"
        name = "Loader-Build"
        owner = "AWS"
        provider = "CodeBuild"
        version = "1"
        configuration = {
          ProjectName = aws_codebuild_project.Loader[0].name
        }
        input_artifacts = [
          "SourceCode"
        ]
        output_artifacts = [
          "Loader-Deployment"
        ]
        region = data.aws_region.current.name
      }
    }
  }
  dynamic "stage" {
    for_each = var.UseContainer ? [1] : []
    content {
      name = "Loader-Deploy"
      action {
        category = "Build"
        name = "Loader-Deploy"
        owner = "AWS"
        provider = "CodeBuild"
        version = "1"
        configuration = {
          ProjectName = aws_codebuild_project.DeployLoader[0].name
        }
        input_artifacts = [
          "Loader-Deployment"
        ]
        region = data.aws_region.current.name
      }
    }
  }
}