## Overview
- Step function to take snapshot as backup for the RDS instance
- It is scheduled to take everyday
- Input the scheduler is in the `input` section of `aws_cloudwatch_event_target`

## Pre-setup
Before we go ahead to create resources in AWS we need to setup a few things for the terraform to work
- Run the python file `pre-setup.py`, this will create dynamoDB table to lock terraform state
- To uniquely name the snapshot being created the execution name is appended with the database name
- The execution name is alpha-numeric and is unique for every execution started. It is accessed by the step function context object through `$$.Execution.Name`

## Execution
- Execute `terraform init` in the project directory
- To create resources run the command `terraform apply -input=false -auto-approve`
- To delete/remove resources run `terraform destroy -auto-approve`

## Output
- Towards the end of the Terraform deployment the output is the invoke url
- The invoke url can be used in postman as 'POST' method
- The input body for the request is a json `{"DbName": "retool"}`

### Note:
- The API is deployed to its respective stage during resource creation itself
- On triggering the API from postman, the response is `Internal server error` but the state machine is triggered
- Go to the API Gateway in the AWS console to redeploy the API. Try again, it returns a valid response with the state machine execution ID
