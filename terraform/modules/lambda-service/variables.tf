variable "name" {
  description = "Name of the service"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Security group ID for Lambda"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "ecr_auth_token" {
  description = "ECR authorization token for Docker provider"
  type = object({
    proxy_endpoint = string
    user_name      = string
    password       = string
  })
}