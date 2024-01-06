resource "aws_security_group" "allow" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name = var.security_group_tag
  }
}

################## 变量信息 ##################

variable "security_group_name" {
  description = "安全组名称"
  default     = "common-prod"
}

variable "security_group_description" {
  description = "安全组描述信息"
}

variable "vpc_id" {
  description = "vpc ID"
}

variable "security_group_tag" {
  description = "安全组标签名称"
  default     = "common-prod-tag"
}

variable "ingress_rules" {
  description = "入站规则列表"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "egress_rules" {
  description = "出站规则列表"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

######################3################## 输出信息 ############################
output "security_group_id" {
  value = aws_security_group.allow.id
}