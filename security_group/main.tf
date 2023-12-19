variable "name" {
  description = "安全组名称"
}

variable "rules" {
  description = "安全组规则"
  default     = []
}

resource "alicloud_security_group" "example_security_group" {
  name        = var.name
  description = "默认安全组规则"

  dynamic "rule" {
    for_each = var.rules
    content {
      description       = rule.value["description"]
      ip_protocol       = rule.value["ip_protocol"]
      port_range        = rule.value["port_range"]
      cidr_blocks       = rule.value["cidr_blocks"]
      security_group_id = alicloud_security_group.example_security_group.id
    }
  }
}
