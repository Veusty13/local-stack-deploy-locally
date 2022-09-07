import json
import os
import uuid

import boto3


def lambda_handler(event, context):

    record = event["Records"][0]
    body = json.loads(record["body"])
    message = body["Message"]
    binary_message = str.encode(message)
    bucket_name = "test-bucket"
    key = f"lambda_output/binary_message_{uuid.uuid4()}"
    localstack_hostname = os.environ["LOCALSTACK_HOSTNAME"]
    client = boto3.client(
        "s3", endpoint_url=f"http://{localstack_hostname}:4566", region_name="us-west-2"
    )
    print(f"about to save file {key} in bucket {bucket_name}")
    client.put_object(
        Body=binary_message,
        Bucket=bucket_name,
        Key=key,
    )
