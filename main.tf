# Output value definitions

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."

  value = aws_s3_bucket.test_bucket.id
}

output "function_name" {
  description = "Name of the Lambda function."

  value = aws_lambda_function.lambda.function_name
}



# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-west-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"

}

provider "aws" {
  region = var.aws_region
  skip_credentials_validation = true
  skip_requesting_account_id = true
  skip_metadata_api_check = true
  s3_use_path_style = true

  endpoints {
    apigateway = "http://localstack:4566"
    iam = "http://localstack:4566"
    lambda = "http://localstack:4566"
    s3 = "http://localstack:4566"
    sns = "http://localstack:4566"
    sqs = "http://localstack:4566"
    cloudwatch = "http://localstack:4566"
  }
}


resource "aws_s3_bucket" "test_bucket" {
  bucket = "test-bucket"
}


data "archive_file" "lambda_zip" {
  type = "zip"

  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.test_bucket.id

  key    = "function.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

resource "aws_lambda_function" "lambda" {
  function_name = "lambda-to-test"

  s3_bucket = aws_s3_bucket.test_bucket.id
  s3_key    = aws_s3_object.lambda_zip.key

  runtime = "python3.9"
  handler = "lambda.lambda_handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    },
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.sqs_queue.arn}"
    },
    {
      "Sid": "ListObjectsInBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::test-bucket"]
    },
    {
        "Sid": "AllObjectActions",
        "Effect": "Allow",
        "Action": "s3:*Object",
        "Resource": ["arn:aws:s3:::test-bucket/*"]
    }
    ]
  })
}


resource "aws_sns_topic" "data_bus" {
  display_name = "Data Bus"
  name         = "data-bus"
}

resource "aws_sns_topic_policy" "data_bus" {
  depends_on = [aws_sns_topic.data_bus]
  arn    = aws_sns_topic.data_bus.arn
  policy = data.aws_iam_policy_document.data_bus.json
}

variable "account_arn_list" {
  type        = string
  description = "List of root account arn"
  default = "arn:aws:iam::999999999999:*"
}

data "aws_iam_policy_document" "data_bus" {

  policy_id = "${aws_sns_topic.data_bus.arn}/AllUsersInAccountCanPublish"

  statement {
    effect = "Allow"
    actions = [
      "SNS:Publish"
    ]
    resources = [
      aws_sns_topic.data_bus.arn,
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        var.account_arn_list,
      ]
    }
  }
}

variable "sqs_queue_name" {
  type        = string
  description = "name of the sqs queue"
  default = "test-queue"
}

resource "aws_sqs_queue" "sqs_queue" {
  name = var.sqs_queue_name
}

resource "aws_sns_topic_subscription" "new_message" {
  endpoint  = aws_sqs_queue.sqs_queue.arn
  protocol  = "sqs"
  topic_arn = aws_sns_topic.data_bus.arn
}

resource "aws_sqs_queue_policy" "sqs_queue" {
  queue_url = aws_sqs_queue.sqs_queue.id
  policy    = data.aws_iam_policy_document.sqs_queue.json
}


data "aws_iam_policy_document" "sqs_queue" {
  policy_id = "${aws_sqs_queue.sqs_queue.arn}/SQSAccess"

  statement {
    sid    = "ConsumerAccess"
    effect = "Allow"
    actions = [
      "SQS:ReceiveMessage",
      "SQS:DeleteMessage",
      "SQS:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.sqs_queue.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [aws_lambda_function.lambda.arn
      ]
    }
  }
  statement {
    sid    = "ProducerAccess"
    effect = "Allow"
    actions = [
      "SQS:SendMessage"
    ]
    resources = [aws_sqs_queue.sqs_queue.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        aws_sns_topic.data_bus.arn
      ]
    }
  }
}


resource "aws_lambda_event_source_mapping" "lambda_allow_sqs" {
  event_source_arn = aws_sqs_queue.sqs_queue.arn
  function_name    = aws_lambda_function.lambda.arn
  batch_size       = 1
}