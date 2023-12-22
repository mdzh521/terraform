################## 安全组设置 #####################

resource "alicloud_securith_group" "group" {
  name            = var.name
  vpc_id          = var.vpc_id
  description     = "默认安全组规则"
} 

resource "alicloud_securith_group_rule" "group_rule" {
  count             = length(var.rules)

  security_group_id = alicloud_securith_group.group.id
  type              = var.rules[count.index].type
  description       = var.rules[count.index].description
  ip_protocol       = var.rules[count.index].ip_protocol
  port_range        = var.rules[count.index].port_range
  cidr_ip           = var.rules[count.index].cidr_blocks[0]
  nic_type          = var.rules[count.index].nic_type
  priority          = var.rules[count.index].priority
}

################## 变量信息 ########################
variable "vpc_id" {
  type = string
}

variable "name" {
  description = "安全组名称"
}

variable "rules" {
  description = "安全组规则"
  default     = []
}

#################### 输出信息 ########################
output "security_id" {
  value = alicloud_securith_group.group.id
}
