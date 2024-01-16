terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.23.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.0"
    }
  }

  required_version = "~> 1.2"
}

provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "example" {
  name           = "example"
  hash_key       = "ID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "ID"
    type = "S"
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

data "archive_file" "save_name" {
  type = "zip"

  source_dir  = "${path.module}/save_name"
  output_path = "${path.module}/save_name.zip"
}

data "archive_file" "health_check" {
  type = "zip"

  source_dir  = "${path.module}/health_check"
  output_path = "${path.module}/health_check.zip"
}

resource "aws_iam_role_policy_attachment" "iam_for_lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "health_check" {
  filename      = "health_check.zip"
  function_name = "health_check"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "health_check.handler"

  source_code_hash = data.archive_file.health_check.output_base64sha256

  runtime = "nodejs18.x"
}

resource "aws_lambda_function" "save_name" {
  filename      = "save_name.zip"
  function_name = "save_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "save_name.handler"

  source_code_hash = data.archive_file.save_name.output_base64sha256

  runtime = "nodejs18.x"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.example.name
    }
  }
}

resource "aws_api_gateway_rest_api" "example" {
  name        = "example"
  description = "Example REST API"
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_get" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.health_check.invoke_arn
}

resource "aws_api_gateway_resource" "save" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "save"
}

resource "aws_api_gateway_method" "save_post" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.save.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "save_post" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.save.id
  http_method = aws_api_gateway_method.save_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.save_name.invoke_arn
}