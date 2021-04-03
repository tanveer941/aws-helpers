
#####################
### SNS Resources ###
#####################
resource "aws_sns_topic" "LambdaTopicSuccess" {
  name = var.SuccessTopicName
  tags = local.common_tags
}
resource "aws_sns_topic" "LambdaTopicFailure" {
  name = var.FailureTopicName
  tags = local.common_tags
}

