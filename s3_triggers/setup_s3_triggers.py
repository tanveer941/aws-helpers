import boto3
import json
from botocore.exceptions import ClientError

REGION = 'us-west-2'
S3_BUCKET_NAME = 'example_bucket'
LAMBDA_TO_INVOKE = 'example_lambda'
PREFIX = 'my/bucket/path'
SUFFIX = '.docx'

def setup_triggers_s3_bucket():
    # Get existing bucket triggers
    bucket_triggers = get_existing_bucket_triggers(S3_BUCKET_NAME)
    print("Deleted existing bucket triggers: " + str(bucket_triggers))

    # Delete the existing triggers from bucket
    remove_all_function_triggers_for_bucket(LAMBDA_TO_INVOKE, S3_BUCKET_NAME)

    # set the triggers for the bucket
    create_s3_triggers(LAMBDA_TO_INVOKE, S3_BUCKET_NAME, PREFIX, SUFFIX)

def is_resource_policy_statement_exists(lambda_name, policy_statement_id):
    client = boto3.client('lambda', region_name=REGION)
    try:
        response = client.get_policy(FunctionName=lambda_name)
        statement_list = json.loads(response['Policy'])['Statement']
        for policy_statement in statement_list:
            sid = policy_statement['Sid']
            if sid == policy_statement_id:
                return True
    except ClientError as err:
        if err.response['Error']['Code'] != 'ResourceNotFoundException':
            raise
    return False


def get_account_id(lambda_name):
    function_arn = get_function_configuration_by_config_name(lambda_name, 'FunctionArn')
    start_index = function_arn.index(REGION+':') + len(REGION+':')
    end_index = function_arn.index(':function:')
    return function_arn[start_index:end_index]


def create_s3_triggers(lambda_name, bucket_name, prefix, suffix):

    # Allow the lambda's policy grant invoke permissions to all the buckets
    policy_statement_id = 'awswrappers-invoke-permission-all-buckets'
    if is_resource_policy_statement_exists(lambda_name, policy_statement_id):
        return

    account_id = get_account_id(lambda_name)
    client = boto3.client('lambda', region_name=REGION)
    client.add_permission(
        FunctionName=lambda_name,
        StatementId=policy_statement_id,
        Action='lambda:InvokeFunction',
        Principal='s3.amazonaws.com',
        SourceAccount=account_id
    )

    client = boto3.client('s3')
    triggers = client.get_bucket_notification_configuration(Bucket=bucket_name)
    triggers.pop('ResponseMetadata', None)
    if 'LambdaFunctionConfigurations' in triggers:
        lambda_triggers = triggers['LambdaFunctionConfigurations']
    else:
        lambda_triggers = []

    function_arn = get_function_configuration_by_config_name(lambda_name, 'FunctionArn')
    filter_rules = []
    if prefix is not None:
        filter_rules.append({'Name': 'Prefix', 'Value': prefix})
    if suffix is not None:
        filter_rules.append({'Name': 'Suffix', 'Value': suffix})
    new_trigger = {
        'LambdaFunctionArn': function_arn,
        'Events': ['s3:ObjectCreated:*'],
        'Filter': {'Key': {'FilterRules': filter_rules}}
    }

    lambda_triggers.append(new_trigger)
    triggers['LambdaFunctionConfigurations'] = lambda_triggers
    client.put_bucket_notification_configuration(Bucket=bucket_name, NotificationConfiguration=triggers)


def get_function_configuration_by_config_name(lambda_name, config_name):

    client = boto3.client('lambda', region_name=REGION)
    response = client.get_function_configuration(FunctionName=lambda_name)
    return response[config_name]


def remove_all_function_triggers_for_bucket(lambda_name, bucket_name):
    client = boto3.client('s3')
    triggers = client.get_bucket_notification_configuration(Bucket=bucket_name)
    triggers.pop('ResponseMetadata', None)
    if 'LambdaFunctionConfigurations' in triggers:
        lambda_triggers = triggers['LambdaFunctionConfigurations']
    else:
        return
    new_lambda_triggers_list = []
    function_to_delete_arn = get_function_configuration_by_config_name(lambda_name, 'FunctionArn')
    for trigger in lambda_triggers:
        arn = trigger['LambdaFunctionArn']
        if arn != function_to_delete_arn:
            new_lambda_triggers_list.append(trigger)

    triggers['LambdaFunctionConfigurations'] = new_lambda_triggers_list
    print("triggers::", triggers)
    client.put_bucket_notification_configuration(Bucket=bucket_name, NotificationConfiguration=triggers)


def get_existing_bucket_triggers(raw_bucket_name):
    client = boto3.client('s3')
    triggers = client.get_bucket_notification_configuration(Bucket=raw_bucket_name)
    if 'LambdaFunctionConfigurations' in triggers:
        lambda_triggers = triggers['LambdaFunctionConfigurations']
    else:
        lambda_triggers = []
    return lambda_triggers

if __name__ == '__main__':
    setup_triggers_s3_bucket()