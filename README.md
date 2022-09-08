# Test AWS application locally 

## Infrastructure

- 1 SNS queue
- 1 SQS queue
- 1 lambda
- 1 bucket S3 (for lambda deployment and to save lambda's output)

BONUS : could be nice to add a postgre database so that we save the count of characters in a local table

1 - A message is sent to the sns queue
2 - The sqs queue will then send this message to the lambda
3 - The lambda will send the message to s3
5 - BONUS : save the characters count in a table

## Goal 

Test the lambda using : 
 
- localstack to emulate the infrastructure in a local environment
- terraform to have infrastructure as code 
- a testing framework (to be defined) to automize testing our lambda

## Definition of done 

With a single command we should be able to launch a test using a locally deployed infrastructure.
This test should pass or fail

## Commands 

- `make docker-compose` to run containers with terraform and localstack images
- `make send-message` to sns a message to the sns topic
- `make list-elements-in-bucket` to check that the lambda function created the txt file
- `make run-unittests` to run unit tests