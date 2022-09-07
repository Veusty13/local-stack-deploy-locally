grant-execution-permission :
	chmod +x docker-entrypoint.sh

docker-compose : 
	docker compose up

open-localstack-container-terminal : 
	docker exec -it localstack bash

list-functions : 
	docker exec -it localstack awslocal lambda list-functions

list-buckets : 
	docker exec -it localstack awslocal s3 ls

list-elements-in-bucket :
	docker exec -it localstack awslocal s3 ls s3://test-bucket/lambda_output --recursive --human-readable --summarize

list-topics : 
	docker exec -it localstack awslocal sns list-topics

list-queues : 
	docker exec -it localstack awslocal sqs list-queues

send-message : 
	docker exec -it localstack awslocal sns publish --topic-arn arn:aws:sns:us-west-2:999999999999:data-bus --message "this is an example of text, length is 38"

run-unittests : 
	python -m unittest discover function '*_test.py'