import os
import time
import unittest

import boto3


class Lambdatest(unittest.TestCase):
    def test_lambda(self):

        expected_message = "this is my test message"
        localstack_hostname = os.environ["LOCALSTACK_HOSTNAME"]
        endpoint_url = f"http://{localstack_hostname}:4566"
        region_name = "us-west-2"
        client = boto3.client("sns", endpoint_url=endpoint_url, region_name=region_name)
        response = client.publish(
            TargetArn="arn:aws:sns:us-west-2:999999999999:data-bus",
            Message=expected_message,
            MessageStructure="string",
        )
        time.sleep(3)
        s3 = boto3.resource("s3", endpoint_url=endpoint_url, region_name=region_name)
        bucketname = "test-bucket"
        key = "lambda_output/message.txt"
        obj = s3.Object(bucketname, key)
        body = obj.get()["Body"].read()
        actual_message = body.decode("utf-8")
        assert expected_message == actual_message
