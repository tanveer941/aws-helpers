##Overview
- Step function to take snapshot as backup for the RDS instance
- It is scheduled to take everyday
- Input the scheduler is in the `input` section of `aws_cloudwatch_event_target`

##Pre-setup
Before we go ahead to create resources in AWS we need to setup a few things for the terraform to work
- Run the python file `pre-setup.py`, this will create dynamoDB table to lock terraform state

##Execution
- Execute `terraform init` in the project directory
- To create resources run the command `terraform apply -input=false -auto-approve`
- To delete/remove resources run `terraform destroy -auto-approve`









{
  "DbName": "retool"
}