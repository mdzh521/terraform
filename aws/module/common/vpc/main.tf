resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    "Name" = var.name
  }
}

######################## 变量文件 ########################

variable "vpc_cidr_block" {
  description = "vpc 网段信息"
  default     = "10.10.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "dns 主机名"
  type        = bool
  default     = true
}

variable "name" {
  description = "vpc 名称"
  default     = "tf-demo-vpc"
}

######################## vpc id 输出 #########################
output "vpc_id" {
  value = aws_vpc.main.id
}