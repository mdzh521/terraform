resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = var.nat_eip_name
    },
  )
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.nat_subnet_id

  tags = merge(
    var.tags,
    {
      Name = var.nat_gateway_name
    },
  )
}

############################## 变量 ############################

variable "nat_subnet_id" {
  description = "nat 分配子网"
  type        = string
}

variable "nat_gateway_name" {
  description = "NAT Gateway name tag"
  type        = string
  default     = "prod-nat-网关"
}

variable "nat_eip_name" {
  description = "NAT EIP name tag"
  type        = string
  default     = "prod-nat-eip"
}

variable "tags" {
  description = "Tags to add to NAT resources"
  type        = map(string)
  default     = {}
}

############################## 输出信息 ########################

output "nat_id" {
  value = aws_nat_gateway.main.id
}
