resource "aws_route_table" "example" {
  vpc_id = var.vpc_id

  dynamic "route" {
    for_each = var.routes
    content {
      cidr_block     = route.value.cidr_block
      gateway_id     = try(route.value.gateway_id, null)
      nat_gateway_id = try(route.value.nat_gateway_id, null)
    }
  }

  tags = {
    Name = var.route_table_name
  }
}


############################### 变量 ###############################
variable "vpc_id" {
  description = "vpc ID"
  type        = string
}

variable "routes" {
  description = "路由规则"
  type = list(object({
    cidr_block     = string
    gateway_id     = optional(string)
    nat_gateway_id = optional(string)
  }))

  validation {
    condition = alltrue([
      for route in var.routes :
      length([
        for target in [try(route.gateway_id, null), try(route.nat_gateway_id, null)] :
        target if target != null && target != ""
      ]) == 1
    ])
    error_message = "Each route must set exactly one target: gateway_id or nat_gateway_id."
  }
}

variable "route_table_name" {
  description = "路由表名称"
  type        = string
}

########################### 路由表输出 #################################3
output "route_table_id" {
  value = aws_route_table.example.id
}
