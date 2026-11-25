variable "aws_access_key" {
  type        = string
  description = "AWS access key for the target account"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key for the target account"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region for RDS resources"
  default     = "ap-east-1"
}
