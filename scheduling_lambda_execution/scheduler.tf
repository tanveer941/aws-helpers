# scheduler
resource "aws_cloudwatch_event_rule" "LambdaScheduler" {
  name = "${var.ProjectName}-Scheduler"
  schedule_expression = var.ScheduleExpression
  tags = local.common_tags
}
resource "aws_cloudwatch_event_target" "CBReportSchedulerTarget" {
  rule = aws_cloudwatch_event_rule.LambdaScheduler.name
  arn = aws_lambda_function.InvokerTaskLambda.arn
}
resource "aws_lambda_permission" "CBReportSchedulerPermission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.InvokerTaskLambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.LambdaScheduler.arn
}