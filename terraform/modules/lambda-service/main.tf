# Get AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 1. ECR repository for your container image
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. ECR Repository Policy (allows Lambda to pull images)
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
      }
    ]
  })
}

# 3. Build Docker image
resource "docker_image" "app_image" {
  name = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
  
  build {
    context    = "${path.root}/../app"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"
    
    # Build args if needed
    build_args = {
      BUILDKIT_INLINE_CACHE = "1"
    }
  }

  # Rebuild when source files change
  triggers = {
    dockerfile_hash   = filemd5("${path.root}/../app/Dockerfile")
    main_py_hash     = filemd5("${path.root}/../app/main.py")
    requirements_hash = filemd5("${path.root}/../app/requirements.txt")
    image_tag        = var.image_tag
  }

  # Keep image locally after destroy
  keep_locally = false
}

# 4. Push image to ECR
resource "docker_registry_image" "app_image" {
  name          = docker_image.app_image.name
  keep_remotely = true

  triggers = {
    image_id = docker_image.app_image.image_id
  }
}

# 5. Lambda function (container image)
resource "aws_lambda_function" "this" {
  function_name = var.name
  package_type  = "Image"
  image_uri     = docker_registry_image.app_image.name
  role          = var.lambda_role_arn
  timeout       = 30
  memory_size   = 128

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      ENVIRONMENT = "production"
    }
  }

  # Ensure the image is pushed before creating the Lambda
  depends_on = [
    docker_registry_image.app_image,
    aws_ecr_repository_policy.this
  ]
}

# 6. CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
}

# 7. API Gateway setup
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.name}-api"
}

# 7.1 Root "/" Method + Integration
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.root_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}

# 7.2 Proxy "{proxy+}" Resource, Method & Integration
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.this.invoke_arn
}

# 8. Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigtw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# 9. Single Deployment + Stage
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.root_integration,
    aws_api_gateway_integration.lambda_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.root_integration,
      aws_api_gateway_integration.lambda_integration,
      aws_api_gateway_rest_api.api.body
    ]))
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}