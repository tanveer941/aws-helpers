import os
import boto3
import zipfile


### Zip Constants ###
#####################
OMIT_DIRS = ['.git', '.idea', '.vs', 'bin', 'obj', 'publish', '.terraform']
OMIT_EXTENSIONS = ['.pyc', '.zip', '.user', '.exe']

CODE_ZIP = "lambda_code.zip"


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

def zip_lambda():
    if os.path.exists(CODE_ZIP):
        os.remove(CODE_ZIP)
    zip_tree('../scheduling_lambda_execution', CODE_ZIP, '', True)
    zip_file = zipfile.ZipFile(CODE_ZIP, 'a', zipfile.ZIP_DEFLATED)
    zip_file.close()

def upload_lambda_code_s3():
    s3 = boto3.resource('s3')
    bucket = s3.Bucket('fee-data-fsk')
    bucket.upload_file(CODE_ZIP, "file_sub/lambda_code.zip")

if __name__ == '__main__':
    # terraform init
    # terraform apply -input=false -auto-approve
    # terraform destroy -auto-approve
    zip_lambda()
    upload_lambda_code_s3()