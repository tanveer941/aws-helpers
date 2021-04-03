data "aws_caller_identity" "Me" {}
data "aws_region" "current" {}

### Lambda Resource ###
resource "aws_lambda_function" "InvokerTaskLambda" {
  function_name = "${var.ProjectName}-Lambda"
  role = aws_iam_role.LambdaRole.arn
  handler = "log_message.handler"
  runtime = "python3.7"
  s3_bucket = var.CodeBucket
  s3_key = var.BucketKeyZip
  environment {
    variables = {
      MY_INPUT = "dummy"
    }
  }
  timeout = 300
  package_type = var.package_type
  tags = local.common_tags
}

resource "aws_lambda_function" "CountLambda" {
  function_name = "${var.ProjectName}-Count-Lambda"
  role = aws_iam_role.LambdaRole.arn
  handler = "get_animal_count.handler"
  runtime = "python3.7"
  s3_bucket = var.CodeBucket
  s3_key = var.BucketKeyZip
  environment {
    variables = {
      MY_INPUT = "dummy"
    }
  }
  timeout = 300
  package_type = var.package_type
  tags = local.common_tags
}

resource "aws_lambda_function" "StatusLambda" {
  function_name = "${var.ProjectName}-Status-Lambda"
  role = aws_iam_role.LambdaRole.arn
  handler = "process_status.handler"
  runtime = "python3.7"
  s3_bucket = var.CodeBucket
  s3_key = var.BucketKeyZip
  environment {
    variables = {
      MY_INPUT = "dummy"
    }
  }
  timeout = 300
  package_type = var.package_type
  tags = local.common_tags
}

resource "aws_lambda_function" "CascadeLambda" {
  function_name = "${var.ProjectName}-Cascade-Lambda"
  role = aws_iam_role.LambdaRole.arn
  handler = "cascade_data.handler"
  runtime = "python3.7"
  s3_bucket = var.CodeBucket
  s3_key = var.BucketKeyZip
  environment {
    variables = {
      MY_INPUT = "dummy"
    }
  }
  timeout = 300
  package_type = var.package_type
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.InvokerTaskLambda.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}


