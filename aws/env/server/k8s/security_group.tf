variable "eks_sg_id" {
  type = string
}

variable "node_prefix_list_id" {
  type = string
}

variable "elb_prefix_list_id" {
  type = string
}

# 放行 elb 子网
resource "aws_vpc_security_group_ingress_rule" "elb_subnets" {
  security_group_id = var.eks_sg_id

  prefix_list_id = var.elb_prefix_list_id
  # from_port      = 0
  # to_port        = 0
  ip_protocol = "-1"

  tags = {
    Name = "elb 子网"
  }

  # lifecycle {
  #   prevent_destroy = true
  # }
}


# 放行 node 子网
resource "aws_vpc_security_group_ingress_rule" "eks_subnets" {
  security_group_id = var.eks_sg_id

  prefix_list_id = var.node_prefix_list_id
  # from_port      = 0
  # to_port        = 0
  ip_protocol = "-1"

  tags = {
    Name = "eks node 子网"
  }

  # lifecycle {
  #   prevent_destroy = true
  # }
}