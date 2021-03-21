
data "aws_iam_policy_document" "LambdaRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
  }
}

data "aws_iam_policy_document" "LambdaEmailPolicy" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = [
      "*"
    ]
  }
}
data "aws_iam_policy_document" "LambdaStatePolicy" {
  statement {
    actions = [
      "events:PutTargets",
      "events:PutRule",
      "events:DescribeRule",
      "lambda:InvokeFunction",
      "sns:Publish",
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
  }
}

#####################
### IAM Resources ###
#####################
resource "aws_iam_role" "LambdaRole" {
  name = "${var.ProjectName}-LambdaRole"
  assume_role_policy = data.aws_iam_policy_document.LambdaRoleAssumePolicy.json
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "LambdaRoleS3" {
  role = aws_iam_role.LambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "LambdaRoleBasic" {
  role = aws_iam_role.LambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "LambdaRoleLambdaFullAccess" {
  role = aws_iam_role.LambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}
resource "aws_iam_role_policy_attachment" "LambdaRolePipelineAccess" {
  role = aws_iam_role.LambdaRole.id
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
}