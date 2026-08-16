locals {
  subnet_map = {
    for subnet in var.subnets : subnet.key => subnet
  }
}

resource "aws_subnet" "subnet" {
  for_each                = local.subnet_map
  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name
    },
  )
}

##################### 变量 ###################
variable "vpc_id" {
  description = "vpc ID 选择"
  type        = string
}

variable "subnets" {
  description = "子网定义"
  type = list(object({
    key                     = string
    name                    = string
    cidr                    = string
    availability_zone       = string
    map_public_ip_on_launch = bool
    tags                    = optional(map(string), {})
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet is required."
  }

  validation {
    condition = alltrue([
      for subnet in var.subnets : trimspace(subnet.key) != ""
    ])
    error_message = "Each subnet key must not be empty."
  }

  validation {
    condition     = length(distinct([for subnet in var.subnets : subnet.key])) == length(var.subnets)
    error_message = "Each subnet key must be unique."
  }
}

variable "tags" {
  description = "Tags to add to all subnets"
  type        = map(string)
  default     = {}
}

###################### 输出信息 ######################
output "subnet_ids" {
  value = [for subnet in var.subnets : aws_subnet.subnet[subnet.key].id]
}

output "subnet_id_map" {
  value = {
    for key, subnet in aws_subnet.subnet : key => subnet.id
  }
}
