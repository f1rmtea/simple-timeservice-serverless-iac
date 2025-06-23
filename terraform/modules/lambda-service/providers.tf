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

provider "docker" {
  alias = "default"
  
  dynamic "registry_auth" {
    for_each = var.ecr_auth_token != null ? [1] : []
    content {
      address  = var.ecr_auth_token.proxy_endpoint
      username = var.ecr_auth_token.user_name
      password = var.ecr_auth_token.password
    }
  }
}
