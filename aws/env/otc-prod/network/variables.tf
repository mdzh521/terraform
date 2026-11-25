variable "aws_access_key" {
  type        = string
  description = "AWS access key for the target account"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key for the target account"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region for network resources"
}

variable "tags" {
  description = "Tags to add to network resources"
  type        = map(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Whether DNS hostnames are enabled in the VPC"
  type        = bool
}

variable "availability_zones" {
  description = "Availability zones used by each subnet group"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone is required."
  }
}

variable "subnet_groups" {
  description = "Subnet group definitions. Each group creates one subnet CIDR per availability zone."
  type = list(object({
    name                    = string
    cidr_blocks             = list(string)
    tier                    = string
    role                    = optional(string)
    map_public_ip_on_launch = optional(bool)
    tags                    = optional(map(string), {})
  }))

  validation {
    condition     = length(var.subnet_groups) > 0
    error_message = "At least one subnet group is required."
  }

  validation {
    condition = alltrue([
      for group in var.subnet_groups : trimspace(group.name) != ""
    ])
    error_message = "Each subnet group name must not be empty."
  }

  validation {
    condition     = length(distinct([for group in var.subnet_groups : lower(trimspace(group.name))])) == length(var.subnet_groups)
    error_message = "Each subnet group name must be unique."
  }

  validation {
    condition = alltrue([
      for group in var.subnet_groups : length(group.cidr_blocks) > 0
    ])
    error_message = "Each subnet group must include at least one CIDR block."
  }

  validation {
    condition = alltrue([
      for group in var.subnet_groups : length(group.cidr_blocks) == length(var.availability_zones)
    ])
    error_message = "Each subnet group must include one CIDR block per availability zone."
  }

  validation {
    condition = alltrue([
      for group in var.subnet_groups : contains(["public", "private"], lower(group.tier))
    ])
    error_message = "Each subnet group tier must be either public or private."
  }
}

variable "kubernetes_subnet_discovery_tags" {
  description = "Kubernetes and AWS Load Balancer Controller subnet discovery tags managed by the network environment."
  type = object({
    enabled                   = optional(bool, false)
    cluster_name              = optional(string, "")
    cluster_tag_subnet_groups = optional(list(string), [])
    public_lb_subnet_groups   = optional(list(string), [])
    private_lb_subnet_groups  = optional(list(string), [])
    extra_tags_by_group       = optional(map(map(string)), {})
  })
  default = {}

  validation {
    condition     = !try(var.kubernetes_subnet_discovery_tags.enabled, false) || trimspace(try(var.kubernetes_subnet_discovery_tags.cluster_name, "")) != ""
    error_message = "kubernetes_subnet_discovery_tags.cluster_name is required when enabled is true."
  }
}

variable "gateway_name" {
  description = "Internet gateway name tag"
  type        = string
}

variable "gateway_destination_cidr_block" {
  description = "CIDR block routed through the internet gateway"
  type        = string
}

variable "nat_subnet_index" {
  description = "Index of the NAT subnet where the NAT gateway is created"
  type        = number
}

variable "nat_gateway_name" {
  description = "NAT gateway name tag"
  type        = string
}

variable "nat_eip_name" {
  description = "NAT EIP name tag"
  type        = string
}

variable "nat_route_table_name" {
  description = "Name tag for the private NAT route table"
  type        = string
}

variable "nat_route_destination_cidr_block" {
  description = "CIDR block routed through the NAT gateway"
  type        = string
}

variable "security_group_name" {
  description = "Common security group name"
  type        = string
}

variable "security_group_description" {
  description = "Common security group description"
  type        = string
}

variable "security_group_tag" {
  description = "Common security group Name tag"
  type        = string
}

variable "ingress_rules" {
  description = "Common security group ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "egress_rules" {
  description = "Common security group egress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
