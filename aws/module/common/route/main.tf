resource "aws_route_table" "example" {
  vpc_id = var.vpc_id

  dynamic "route" {
    for_each = var.routes
    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.gateway_id
    }
  }

  tags = {
    Name = var.route_table_name
  }
}


############################### 变量 ###############################
variable "vpc_id" {
  description = "vpc ID"
}

variable "routes" {
  description = "路由规则"
  type = list(object({
    cidr_block = string
    gateway_id = string
  }))
}

variable "route_table_name" {
  description = "路由表名称"
}