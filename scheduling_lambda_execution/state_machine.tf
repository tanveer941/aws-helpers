


###############################
### Step Function Resources ###
###############################
resource "aws_sfn_state_machine" "LambdaStateMachine" {
  name = "${var.ProjectName}-LambdaStateMachine"
  role_arn = aws_iam_role.LambdaStateRole.arn
  definition = <<EOF
        {
          "StartAt": "JobStarted",
          "States": {
            "JobStarted": {
              "Type": "Task",
              "Resource": "${aws_lambda_function.InvokerTaskLambda.arn}",
              "Parameters": {
                "message": "Job Started"
              },
              "ResultPath": null,
              "Next": "IterateAnimal"
            },
            "IterateAnimal": {
              "Type": "Map",
              "ItemsPath": "$.animal1",
              "MaxConcurrency": 2,
              "Parameters": {
                "animal_info.$": "$$.Map.Item.Value"
              },
              "Catch": [
                {
                  "ErrorEquals": [
                    "States.ALL"
                  ],
                  "Next": "NotifyFailure"
                }
              ],
              "ResultPath": "$.iter_res",
              "Iterator": {
                "StartAt": "GetAnimalCount",
                "States": {
                  "GetAnimalCount": {
                    "Type": "Task",
                    "Resource": "${aws_lambda_function.CountLambda.arn}",
                    "Next": "StatusTasks"
                  },
                  "StatusTasks": {
                    "Type": "Task",
                    "Resource": "${aws_lambda_function.StatusLambda.arn}",
                    "Next": "AreAllStopped"
                  },
                  "AreAllStopped": {
                    "Type": "Choice",
                    "Choices": [
                      {
                        "Variable": "$.all_stopped",
                        "BooleanEquals": false,
                        "Next": "WaitTasks"
                      }
                    ],
                    "Default": "Cascade"
                  },
                  "WaitTasks": {
                    "Type": "Wait",
                    "Seconds": 30,
                    "Next": "StatusTasks"
                  },
                  "Cascade": {
                    "Type": "Task",
                    "Resource": "${aws_lambda_function.CascadeLambda.arn}",
                    "End": true
                  }
                }
              },
              "Next": "Notify"
            },
            "Notify": {
              "Type": "Choice",
              "Choices": [
                {
                  "Variable": "$.iter_res[0].all_stopped",
                  "BooleanEquals": false,
                  "Next": "NotifyFailure"
                }
              ],
              "Default": "NotifySuccess"
            },
            "NotifySuccess": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${aws_sns_topic.LambdaTopicSuccess.arn}",
                "Message.$": "$.iter_res",
                "Subject": "SUCCESS: ${var.ProjectName}"
              },
              "Next": "JobSucceeded"
            },
            "JobSucceeded": {
              "Type": "Task",
              "Resource": "${aws_lambda_function.InvokerTaskLambda.arn}",
              "Parameters": {
                "message": "Job Succeeded"
              },
              "ResultPath": null,
              "End": true
            },
            "NotifyFailure": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "TopicArn": "${aws_sns_topic.LambdaTopicFailure.arn}",
                "Message.$": "$.iter_res",
                "Subject": "SUCCESS: ${var.ProjectName}"
              },
              "Next": "JobFailed"
            },
            "JobFailed": {
              "Type": "Task",
              "Resource": "${aws_lambda_function.InvokerTaskLambda.arn}",
              "Parameters": {
                "message": "Job Failed"
              },
              "ResultPath": null,
              "Next": "FailState"
            },
            "FailState": {
              "Type": "Fail"
            }
          }
        }
EOF
  tags = local.common_tags
}