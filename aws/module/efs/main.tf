variable "vpc_id" {
  description = "VPC ID that hosts the EKS nodes and EFS mount targets"
  type        = string
}

variable "eks_name" {
  description = "EKS cluster name used for EFS resource naming"
  type        = string
}

variable "eks_subnet_ids" {
  description = "Subnets where EFS mount targets are created"
  type        = set(string)
}

variable "node_subnet_cidrs" {
  description = "CIDR blocks for EKS node subnets"
  type        = list(string)
}

variable "tags" {
  description = "Tags to add to EFS resources"
  type        = map(string)
  default     = {}
}

variable "efs_config" {
  description = "EFS file system and security group configuration"
  type        = any
  default     = {}
}

data "aws_subnet" "eks_subnets" {
  for_each = var.eks_subnet_ids
  id       = each.key
}

locals {
  efs_config = var.efs_config

  name                   = coalesce(try(local.efs_config.name, null), "${var.eks_name}-eks")
  security_group_name    = coalesce(try(local.efs_config.security_group_name, null), "${var.eks_name}-efs")
  security_group_desc    = try(local.efs_config.security_group_description, "Allow EKS nodes to access EFS")
  name_tag               = coalesce(try(local.efs_config.name_tag, null), local.name)
  additional_tags        = try(local.efs_config.tags, {})
  provisioned_throughput = try(local.efs_config.provisioned_throughput_in_mibps, null)
}

# 创建 efs
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 2.0"

  # File system
  name = local.name
  # creation_token = local.name
  encrypted = try(local.efs_config.encrypted, true)
  # kms_key_arn    = module.kms.key_arn

  performance_mode                = try(local.efs_config.performance_mode, "generalPurpose")
  throughput_mode                 = try(local.efs_config.throughput_mode, "elastic")
  provisioned_throughput_in_mibps = local.provisioned_throughput

  lifecycle_policy = {
    transition_to_ia                    = try(local.efs_config.lifecycle_policy.transition_to_ia, "AFTER_30_DAYS")
    transition_to_primary_storage_class = try(local.efs_config.lifecycle_policy.transition_to_primary_storage_class, "AFTER_1_ACCESS")
  }

  # File system policy
  attach_policy = try(local.efs_config.attach_policy, false)

  # Mount targets / security group
  mount_targets              = { for subnet in data.aws_subnet.eks_subnets : subnet.availability_zone => { subnet_id = subnet.id } }
  security_group_name        = local.security_group_name
  security_group_description = local.security_group_desc
  security_group_vpc_id      = var.vpc_id

  # 对eks节点子网放行 2049 端口
  security_group_ingress_rules = {
    for index, cidr in var.node_subnet_cidrs : "node_${index}" => {
      description = "Allow eks node ${cidr} access efs"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
    }
  }

  security_group_egress_rules = {
    for index, cidr in var.node_subnet_cidrs : "node_${index}" => {
      description = "Allow efs egress to eks node ${cidr}"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
    }
  }

  # Backup policy
  enable_backup_policy = try(local.efs_config.enable_backup_policy, true)

  # Replication configuration
  create_replication_configuration = try(local.efs_config.create_replication_configuration, false)

  tags = merge(
    var.tags,
    local.additional_tags,
    {
      Name = local.name_tag
    },
  )
}

output "id" {
  description = "EFS file system ID"
  value       = module.efs.id
}

output "security_group_id" {
  description = "Security group ID created for the EFS file system"
  value       = module.efs.security_group_id
}
