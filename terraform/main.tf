terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Configure Docker provider to authenticate with ECR
provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.token.proxy_endpoint
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

# Get ECR authorization token
data "aws_ecr_authorization_token" "token" {}

module "vpc" {
  source        = "./modules/vpc"
  name          = var.name
  public_cidrs  = var.public_subnets
  private_cidrs = var.private_subnets
}

# Lambda execution role
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.name}-lambda-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Allow outbound internet"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "lambda_srv" {
  source = "./modules/lambda-service"

  name            = var.name
  image_tag       = var.image_tag
  private_subnets = module.vpc.private_subnets
  lambda_sg_id    = aws_security_group.lambda_sg.id
  lambda_role_arn = aws_iam_role.lambda_exec.arn

  # Pass ECR auth token to the module
  ecr_auth_token = {
    proxy_endpoint = data.aws_ecr_authorization_token.token.proxy_endpoint
    user_name      = data.aws_ecr_authorization_token.token.user_name
    password       = data.aws_ecr_authorization_token.token.password
  }

  providers = {
    docker = docker
  }
}