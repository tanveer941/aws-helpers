data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

## Step Function ##
resource "aws_sfn_state_machine" "RDSBackupStateMachine" {
  name     = "${var.ProjectName}-state-machine"
  role_arn = aws_iam_role.StepFunctionRole.arn

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
        "DbSnapshotIdentifier.$": "States.Format('{}-{}', $.DbInstances[0].DbInstanceIdentifier, $.DbInstances[0].DbInstanceIdentifier)"
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
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "TriggerRDSBackupTarget" {
  rule      = aws_cloudwatch_event_rule.TriggerRDSBackupRule.name
  arn       = aws_sfn_state_machine.RDSBackupStateMachine.arn
  role_arn = aws_iam_role.StepFunctionStartRole.arn
  input = jsonencode({"DbName": "retool"})
}
