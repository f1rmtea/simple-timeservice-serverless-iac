variable "aws_region" {
  default = "us-east-1"
}
variable "name" {
  default = "simple-timeservice"
}
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}
variable "image_tag" {
  description = "ECR image tag (from CI pipeline)"
}
