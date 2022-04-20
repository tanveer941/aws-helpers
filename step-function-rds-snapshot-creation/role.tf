
data "aws_iam_policy_document" "StepFunctionRoleAssumePolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["states.amazonaws.com",
                      "events.amazonaws.com"]
      type = "Service"
    }
  }
}

## Step Function Role ##
resource "aws_iam_role" "StepFunctionRole" {
  name = "${var.ProjectName}-StepFunctionRole"
  assume_role_policy = data.aws_iam_policy_document.StepFunctionRoleAssumePolicy.json
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.Me.account_id}:policy/ADSK-Boundary"
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "StepFunctionRDSAccess" {
  role = aws_iam_role.StepFunctionRole.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

## Start Step function Execution role ##

data "aws_iam_policy_document" "StepFunctionRoleStartPolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["states.amazonaws.com",
                      "events.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "StepFunctionStartRole" {
  name = "${var.ProjectName}-StepFunctionStartRole"
  assume_role_policy = data.aws_iam_policy_document.StepFunctionRoleStartPolicy.json
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.Me.account_id}:policy/ADSK-Boundary"
  tags = local.common_tags
}

resource "aws_iam_role_policy" "StateMachineStartExecution" {
      name        = "StateMachineStartExecution"
      role   = aws_iam_role.StepFunctionStartRole.id

      policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "states:StartExecution"
        ],
        "Effect": "Allow",
        "Resource": [
          "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.Me.account_id}:stateMachine:${aws_sfn_state_machine.RDSBackupStateMachine.name}"
        ]
      }
    ]
  }
  EOF
}

## API Gateway Execution role ##
data "aws_iam_policy_document" "APIGatewayTrustPolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["apigateway.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "TriggerStepFunctionFromAPIRole" {
  name = "${var.ProjectName}-TriggerStepFunctionFromAPIRole"
  assume_role_policy = data.aws_iam_policy_document.APIGatewayTrustPolicy.json
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.Me.account_id}:policy/ADSK-Boundary"
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "APIStepFunctionAccess" {
  role = aws_iam_role.TriggerStepFunctionFromAPIRole.id
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}