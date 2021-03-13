import os
import boto3
import zipfile
import subprocess
import shlex
from botocore.exceptions import ClientError

### Zip Constants ###
#####################
OMIT_DIRS = ['.git', '.idea', '.vs', 'bin', 'obj', 'publish', '.terraform']
OMIT_EXTENSIONS = ['.pyc', '.zip', '.user', '.exe']

CODE_ZIP = "code.zip"


def zip_tree(input_dir, output_zip, destination='', is_append=False):
    if not input_dir.endswith(os.sep):
        input_dir = input_dir + os.sep
    zip_action = 'a' if is_append else 'w'
    zip_file = zipfile.ZipFile(output_zip, zip_action, zipfile.ZIP_DEFLATED)
    input_dir_prefix_length = len(input_dir)
    # Walk through all children files and dirs of top level code directory
    for root, dirs, files in os.walk(input_dir):
        destination_root = os.path.join(destination, root[input_dir_prefix_length:])
        for file in files:
            if zip_this_file(file):
                zip_file.write(os.path.join(root, file), os.path.join(destination_root, file))
        for i in range(len(dirs) - 1, -1, -1):
            dir = dirs[i]
            if not zip_this_dir(dir):
                # Removing this directory from dirs prevents it from being walked in outer for loop
                dirs.remove(dir)
    zip_file.close()


def zip_this_dir(dir_name):
    for omit_dir in OMIT_DIRS:
        if dir_name == omit_dir:
            return False
    return True


def zip_this_file(file_name):
    for omit_ext in OMIT_EXTENSIONS:
        if file_name.endswith(omit_ext):
            return False
    return True

def configure_aws_credentials():
    # Check for other means of providing credentials before using profile
    if 'AWS_ACCESS_KEY_ID' not in os.environ:
        os.environ['AWS_PROFILE'] = 'default'

def check_dynamodb_exists():
    # Configure AWS credentials from profile
    configure_aws_credentials()
    dynamodb_client = boto3.client('dynamodb', region_name="us-west-2")
    table_name = 'Trig-Serv'
    try:
        dynamodb_client.describe_table(
            TableName=table_name
        )
        print('DynamoDB table: ' + table_name + ' exists')
    except ClientError as err:
        if err.response['Error']['Code'] != 'ResourceNotFoundException':
            raise
        print('Creating DynamoDB table: ' + table_name + '...')
        dynamodb_client.create_table(
            TableName=table_name,
            KeySchema=[
                {
                    'AttributeName': 'LockID',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'LockID',
                    'AttributeType': 'S'
                }
            ],
            BillingMode='PAY_PER_REQUEST',
            Tags=[
                {
                    'Key': 'Contact',
                    'Value': "Bellwethers@ihsmarkit.com"
                },
                {
                    'Key': 'Service',
                    'Value': "CAPS:FeeData"
                },
                {
                    'Key': 'Environment',
                    'Value': "Dev"
                },
                {
                    'Key': 'OrgID',
                    'Value': "01444"
                },
                {
                    'Key': 'Capacity',
                    'Value': "BAU"
                }
            ]
        )
        waiter = dynamodb_client.get_waiter('table_exists')
        waiter.wait(
            TableName=table_name,
            WaiterConfig={
                'Delay': 5,
                'MaxAttempts': 10
            }
        )

def zip_the_code():
    if os.path.exists(CODE_ZIP):
        os.remove(CODE_ZIP)
    zip_tree(os.path.join('..', 'fargate_task'), CODE_ZIP, 'fargate_task', True)
    zip_tree(os.path.join('..', 'fargate_service'), CODE_ZIP, 'fargate_service', True)
    zip_file = zipfile.ZipFile("code.zip", 'a', zipfile.ZIP_DEFLATED)
    zip_file.close()

def upload_code_s3_to_trigger_deployment():
    s3 = boto3.resource('s3')
    bucket = s3.Bucket('ihsmarkit-energy-dev-codepipeline')
    bucket.upload_file("code.zip", "Trig-Serv/Dev/code.zip")

def deploy_app():
    check_dynamodb_exists()
    zip_the_code()
    upload_code_s3_to_trigger_deployment()

def command_execution(cmd, cwd=None):
    command = shlex.split(cmd)
    retval = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=cwd)
    while True:
        line = retval.stdout.readline().rstrip()
        print(line)
        if not line and retval.poll() is not None:
            break
    if retval.returncode != 0:
        raise subprocess.CalledProcessError(retval.returncode, cmd)

def create_pipeline():
    command_execution('terraform init')
    command_execution('terraform apply -input=false -auto-approve')

def teardown_pipeline():

    # delete ecs task stack
    task_stack_path = os.path.join(os.path.join('..', 'fargate_task'), 'ecs_stack')
    command_execution('terraform init', cwd=task_stack_path)
    command_execution('terraform destroy -auto-approve', cwd=task_stack_path)

    # delete ecs service stack
    task_stack_path = os.path.join(os.path.join('..', 'fargate_service'), 'ecs_service_stack')
    command_execution('terraform init', cwd=task_stack_path)
    command_execution('terraform destroy -auto-approve', cwd=task_stack_path)

    # delete main pipeline stack
    command_execution('terraform init')
    command_execution('terraform destroy -auto-approve')

    # deleting the dynamo DB table
    print('Deleting dynamo db table...')
    dynamodb_client = boto3.client('dynamodb', region_name='us-west-2')
    dynamodb_client.delete_table(
        TableName='Trig-Serv'
    )
    waiter = dynamodb_client.get_waiter('table_not_exists')
    waiter.wait(
        TableName='Trig-Serv',
        WaiterConfig={
            'Delay': 5,
            'MaxAttempts': 10
        }
    )

if __name__ == '__main__':
    teardown_pipeline()
    deploy_app()
    create_pipeline()

