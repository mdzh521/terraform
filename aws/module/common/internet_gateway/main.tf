resource "aws_internet_gateway" "gw" {
  vpc_id = var.vpc_id
  tags = {
    Name = var.gateway_name
  }
}

resource "aws_route" "gateway_route" {
  route_table_id         = var.route_table_id
  destination_cidr_block = var.destination_cidr_block
  gateway_id             = aws_internet_gateway.gw.id
}

############################### 变量信息 #############################3

variable "vpc_id" {
  description = "vpc ID"
}

variable "gateway_name" {
  description = "互联网网关名称"
  default     = "prod-ec2-gateway"
}

variable "route_table_id" {
  description = "默认路由表ID"
}

variable "destination_cidr_block" {
  description = "源地址"
}

################################ 输出信息 ###############################3
output "gateway_id" {
  value = aws_internet_gateway.gw.id
}