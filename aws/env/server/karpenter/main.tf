variable "cluster_name" {
  description = "k8s cluster name"
  type        = string
}

variable "iam_role_name" {
  description = "iam role name"
  type        = string
}

variable "iam_role_arn" {
  description = "iam role name"
  type        = string
}

variable "ec2_ssh_key" {
  description = "ssh key name"
  type        = string
}

variable "eks_subnet_ids" {
  description = "eks子网ID"
  type        = list(string)
}

variable "node_sg_ids" {
  description = "添加到node节点的安全组ID"
  type        = list(string)
  default     = []
}

variable "node_pools" {
  description = "节点池配置"
  type = map(object({
    cpu_limit      = optional(string)
    memory_limit   = optional(string)
    instance_types = list(string)
    labels         = optional(map(string), {})
    taints         = optional(any, {})
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# 获取 ssh key
data "aws_key_pair" "ssh_key" {
  key_name           = var.ec2_ssh_key
  include_public_key = true
}

locals {
  node_class_name = "al2023"
  node_ami_alias  = "al2023@v20250915" # 节点使用的镜像

  tags = merge(var.tags, {
    component = "k8s"
  })
}

# 为 karpenter role 创建 access entry， 否则无法访问 apiServer 注册节点到 k8s 上
resource "aws_eks_access_entry" "karpenter" {
  cluster_name  = var.cluster_name
  principal_arn = var.iam_role_arn
  type          = "EC2_LINUX"

  tags = var.tags
}

# EC2NodeClass
resource "kubectl_manifest" "node_class" {
  yaml_body = templatefile("${path.module}/manifests/node-class.yaml", {
    name               = local.node_class_name
    ami_alias          = local.node_ami_alias
    iam_role           = var.iam_role_name
    node_subnet_id_map = jsonencode([for id in var.eks_subnet_ids : { "id" = id }])
    node_sg_id_map     = jsonencode([for id in var.node_sg_ids : { "id" = id }])
    tags               = jsonencode(local.tags)
    ssh_public_key     = data.aws_key_pair.ssh_key.public_key
  })
  wait_for_rollout  = false
  force_new         = true
  server_side_apply = true

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

# NodePool
resource "kubectl_manifest" "node_pool" {
  for_each = var.node_pools
  yaml_body = templatefile("${path.module}/manifests/node-pool.yaml", {
    name            = each.key
    node_class_name = local.node_class_name
    labels          = jsonencode(each.value.labels)
    taints          = jsonencode([for k, v in each.value.taints : { key = k, value = v, effect = "NoSchedule" }])
    instance_types  = jsonencode(each.value.instance_types)
    cpu_limit       = each.value.cpu_limit
    memory_limit    = each.value.memory_limit
  })
  wait_for_rollout = false
  force_new        = true

  depends_on = [
    kubectl_manifest.node_class,
    aws_eks_access_entry.karpenter,
  ]

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

output "public_key" {
  value = data.aws_key_pair.ssh_key.public_key
}