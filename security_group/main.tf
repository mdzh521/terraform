variable "security_group_ports" {
  description = "安全组规则端口列表"
  default     = [22, 80, 8080, 443]
}

provider "alicloud" {
  region = "ap-southeast-1" # 香港区域
}

resource "alicloud_security_group" "example_security_group" {
  vpc_id       = var.vpc_id
  name         = "example-security-group"
  description  = "Example Security Group"

  dynamic "rule" {
    for_each = var.security_group_ports
    content {
      type              = "ingress"
      ip_protocol       = "tcp"
      port_range        = "${rule.value}/${rule.value}"
      priority          = rule.key + 1
      policy            = "accept"
      security_group_id = alicloud_security_group.example_security_group.id
      description       = "Allow port ${rule.value}"
    }
  }
}

output "security_group_id" {
  value = alicloud_security_group.example_security_group.id
}

