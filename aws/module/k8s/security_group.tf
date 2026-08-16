variable "eks_sg_id" {
  description = "EKS cluster security group ID"
  type        = string
}

variable "node_subnet_cidrs" {
  description = "CIDR blocks for EKS node subnets"
  type        = list(string)
}

variable "elb_subnet_cidrs" {
  description = "CIDR blocks for ELB subnets"
  type        = list(string)
}

variable "security_group_rule_names" {
  description = "Name tags used for security group rules created by this module"
  type        = any
  default     = {}
}

# 放行 elb 子网
resource "aws_vpc_security_group_ingress_rule" "elb_subnets" {
  for_each = toset(var.elb_subnet_cidrs)

  security_group_id = var.eks_sg_id

  cidr_ipv4 = each.value
  # from_port      = 0
  # to_port        = 0
  ip_protocol = "-1"

  tags = {
    Name = try(var.security_group_rule_names.elb_subnets, "elb 子网")
  }

}

# 放行 node 子网
resource "aws_vpc_security_group_ingress_rule" "eks_subnets" {
  for_each = toset(var.node_subnet_cidrs)

  security_group_id = var.eks_sg_id

  cidr_ipv4 = each.value
  # from_port      = 0
  # to_port        = 0
  ip_protocol = "-1"

  tags = {
    Name = try(var.security_group_rule_names.node_subnets, "eks node 子网")
  }

}
