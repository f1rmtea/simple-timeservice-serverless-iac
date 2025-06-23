output "api_url" {
  description = "URL of the API Gateway endpoint"
  value       = module.lambda_srv.api_url
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.lambda_srv.ecr_repository_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda_srv.lambda_function_name
}