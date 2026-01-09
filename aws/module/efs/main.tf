variable "vpc_id" {
  type = string
}

variable "eks_name" {
  type = string
}

variable "eks_subnet_ids" {
  type = set(string)
}

variable "node_prefix_list_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

data "aws_subnet" "eks_subnets" {
  for_each = var.eks_subnet_ids
  id       = each.key
}

# 创建 efs
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.8.0"

  # File system
  name = "${var.eks_name}-eks"
  # creation_token = local.name
  encrypted = true
  # kms_key_arn    = module.kms.key_arn

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  # provisioned_throughput_in_mibps = 256

  lifecycle_policy = {
    transition_to_ia                    = "AFTER_30_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  # File system policy
  attach_policy = false

  # Mount targets / security group
  mount_targets              = { for subnet in data.aws_subnet.eks_subnets : subnet.availability_zone => { subnet_id = subnet.id } }
  security_group_name        = "eks-for-flink-efs"
  security_group_description = "allow eks of flink access efs"
  security_group_vpc_id      = var.vpc_id

  # 对eks节点子网放行 2049 端口
  security_group_rules = {
    ingress = {
      type            = "ingress"
      description     = "Allow eks node access efs"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      prefix_list_ids = [var.node_prefix_list_id]
    }

    egress = {
      type            = "egress"
      description     = "Allow eks node access efs"
      from_port       = 0
      to_port         = 0
      protocol        = "all"
      prefix_list_ids = [var.node_prefix_list_id]
    }
  }

  # Backup policy
  enable_backup_policy = true

  # Replication configuration
  create_replication_configuration = false


  tags = merge(
    var.tags,
    {
      Name = "eks-for-flink-${var.eks_name}"
    },
  )
}

output "id" {
  value = module.efs.id
}