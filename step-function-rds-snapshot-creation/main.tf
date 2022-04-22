data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

## Step Function ##
resource "aws_sfn_state_machine" "RDSBackupStateMachine" {
  name     = "${var.ProjectName}-state-machine"
  role_arn = aws_iam_role.StepFunctionRole.arn
  tags = local.common_tags

  definition = <<EOF
{
  "Comment": "A state machine to create DB snapshot and check status until it is created",
  "StartAt": "GetDBInstanceDetails",
  "States": {
    "GetDBInstanceDetails": {
      "Type": "Task",
      "Next": "CheckIfInstanceAvailable",
      "Parameters": {
        "DbInstanceIdentifier.$": "$.DbName"
      },
      "Resource": "arn:aws:states:::aws-sdk:rds:describeDBInstances"
    },
    "CheckIfInstanceAvailable": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.DbInstances[0].DbInstanceStatus",
          "StringEquals": "available",
          "Next": "CreateDBSnapshot"
        }
      ]
    },
    "CreateDBSnapshot": {
      "Type": "Task",
      "Parameters": {
        "DbInstanceIdentifier.$": "$.DbInstances[0].DbInstanceIdentifier",
        "DbSnapshotIdentifier.$": "States.Format('{}-{}', $.DbInstances[0].DbInstanceIdentifier, $$.Execution.Name)"
      },
      "Resource": "arn:aws:states:::aws-sdk:rds:createDBSnapshot",
      "Next": "GetDBSnapshotStatus",
      "ResultPath": "$.CreatedSnapshotResult"
    },
    "GetDBSnapshotStatus": {
      "Type": "Task",
      "Next": "IsSnapshotCreated",
      "Parameters": {
        "DbInstanceIdentifier.$": "$.DbInstances[0].DbInstanceIdentifier",
        "DbSnapshotIdentifier.$": "$.CreatedSnapshotResult.DbSnapshot.DbSnapshotIdentifier"
      },
      "Resource": "arn:aws:states:::aws-sdk:rds:describeDBSnapshots",
      "ResultPath": "$.CreatedSnapshotResult"
    },
    "IsSnapshotCreated": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.CreatedSnapshotResult.DbSnapshots[0].Status",
          "StringEquals": "creating",
          "Next": "Wait"
        },
        {
          "Variable": "$.CreatedSnapshotResult.DbSnapshots[0].Status",
          "StringEquals": "available",
          "Next": "Success"
        }
      ]
    },
    "Success": {
      "Type": "Succeed"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 60,
      "Next": "TransformSnapshotInfo"
    },
    "TransformSnapshotInfo": {
      "Type": "Pass",
      "Next": "GetDBSnapshotStatus",
      "Parameters": {
        "DbInstances.$": "$.DbInstances",
        "CreatedSnapshotResult": {
          "DbSnapshot.$": "$.CreatedSnapshotResult.DbSnapshots[0]"
        }
      }
    }
  }
}
EOF
}

## Eventbridge ##
resource "aws_cloudwatch_event_rule" "TriggerRDSBackupRule" {
  name                = "TriggerRDSBackup"
  description         = "Trigger RDS Backup nightly"
  schedule_expression = "cron(0 0 * * ? *)"
  is_enabled = false
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "TriggerRDSBackupTarget" {
  rule      = aws_cloudwatch_event_rule.TriggerRDSBackupRule.name
  arn       = aws_sfn_state_machine.RDSBackupStateMachine.arn
  role_arn = aws_iam_role.StepFunctionStartRole.arn
  input = jsonencode({"DbName": "retool"})
}

## API Gateway
resource "aws_api_gateway_rest_api" "StepFunctionRDSSnapshot" {
  name        = "StepFunctionRDSSnapshot"
  description = "API to invoke step function which creates RDS snapshot"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "StepFunctionRDSSnapshotResource" {
  rest_api_id = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  parent_id   = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.root_resource_id
  path_part   = "createrdssnapshot"
}

resource "aws_api_gateway_method" "StepFunctionRDSSnapshotMethod" {
  rest_api_id   = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  resource_id   = aws_api_gateway_resource.StepFunctionRDSSnapshotResource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "StepFunctionRDSSnapshotIntegration" {
  rest_api_id          = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  resource_id          = aws_api_gateway_resource.StepFunctionRDSSnapshotResource.id
  http_method          = aws_api_gateway_method.StepFunctionRDSSnapshotMethod.http_method
  type                 = "AWS"
  integration_http_method = "POST"
  uri = "arn:aws:apigateway:${data.aws_region.current.name}:states:action/StartExecution"
  credentials = aws_iam_role.TriggerStepFunctionFromAPIRole.arn
  passthrough_behavior = "WHEN_NO_MATCH"
  request_templates = {"application/json" = <<EOF
#set($data = $input.path('$'))
#set($input = "{""DbName"": ""$data.DbName""}")
{
    "input": "$util.escapeJavaScript($input)",
    "stateMachineArn": "${aws_sfn_state_machine.RDSBackupStateMachine.arn}"
}
  EOF
  }
}

resource "aws_api_gateway_deployment" "StepFunctionRDSSnapshotDeployment" {
  rest_api_id = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  stage_name = "invoke"
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.StepFunctionRDSSnapshotResource.id,
      aws_api_gateway_method.StepFunctionRDSSnapshotMethod.id,
      aws_api_gateway_integration.StepFunctionRDSSnapshotIntegration.id,
    ]))
  }
}

resource "aws_api_gateway_integration_response" "StepFunctionRDSSnapshotIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  resource_id = aws_api_gateway_resource.StepFunctionRDSSnapshotResource.id
  http_method = aws_api_gateway_method.StepFunctionRDSSnapshotMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on = [aws_api_gateway_integration.StepFunctionRDSSnapshotIntegration]
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.StepFunctionRDSSnapshot.id
  resource_id = aws_api_gateway_resource.StepFunctionRDSSnapshotResource.id
  http_method = aws_api_gateway_method.StepFunctionRDSSnapshotMethod.http_method
  status_code = "200"
}

output "APIGatewayTriggerStepFunctionEndpoint" {
  value = "${aws_api_gateway_deployment.StepFunctionRDSSnapshotDeployment.invoke_url}/${aws_api_gateway_resource.StepFunctionRDSSnapshotResource.path_part}"
}