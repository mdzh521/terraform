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

variable "node_class_name" {
  description = "Karpenter EC2NodeClass name"
  type        = string
  default     = "al2023"
}

variable "node_ami_alias" {
  description = "Karpenter AMI alias used by the EC2NodeClass"
  type        = string
  default     = "al2023@v20250915"
}

variable "node_class" {
  description = "Karpenter EC2NodeClass spec settings"
  type        = any
  default     = {}
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
  type        = any
  default     = {}

  validation {
    condition = alltrue([
      for _, node_pool in var.node_pools : length(try(node_pool.instance_types, [])) > 0
    ])
    error_message = "Each node pool must include at least one instance type."
  }
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
  node_class           = var.node_class
  node_class_name      = coalesce(try(local.node_class.name, null), var.node_class_name)
  node_ami_alias       = coalesce(try(local.node_class.ami_alias, null), var.node_ami_alias)
  node_class_tags      = merge(var.tags, try(local.node_class.tags, {}), { component = "k8s" })
  node_class_user_data = <<-EOT
    #!/bin/bash
    mkdir -p ~ec2-user/.ssh/
    touch ~ec2-user/.ssh/authorized_keys
    cat >> ~ec2-user/.ssh/authorized_keys <<EOF
    ${data.aws_key_pair.ssh_key.public_key}
    EOF
    chmod -R go-w ~ec2-user/.ssh/authorized_keys
    chown -R ec2-user ~ec2-user/.ssh
  EOT

  node_class_manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = local.node_class_name
    }
    spec = merge(
      {
        role               = var.iam_role_name
        detailedMonitoring = try(local.node_class.detailed_monitoring, true)
        amiSelectorTerms = [
          {
            alias = local.node_ami_alias
          }
        ]
        kubelet = try(local.node_class.kubelet, {
          imageGCLowThresholdPercent  = 60
          imageGCHighThresholdPercent = 70
        })
        subnetSelectorTerms        = [for id in var.eks_subnet_ids : { id = id }]
        securityGroupSelectorTerms = [for id in var.node_sg_ids : { id = id }]
        tags                       = local.node_class_tags
        metadataOptions = try(local.node_class.metadata_options, {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2
          httpTokens              = "required"
        })
        blockDeviceMappings = try(local.node_class.block_device_mappings, [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize          = "100Gi"
              volumeType          = "gp3"
              iops                = 3000
              encrypted           = true
              throughput          = 150
              deleteOnTermination = true
            }
          }
        ])
        userData = try(local.node_class.user_data, local.node_class_user_data)
      },
      try(local.node_class.extra_spec, {}),
    )
  }

  node_pool_taints = {
    for node_pool_name, node_pool in var.node_pools : node_pool_name => [
      for taint_name, taint in try(node_pool.taints, {}) : {
        key    = try(taint.key, taint_name)
        value  = try(taint.value, taint)
        effect = try(taint.effect, "NoSchedule")
      }
    ]
  }

  node_pool_manifests = {
    for node_pool_name, node_pool in var.node_pools : node_pool_name => {
      apiVersion = "karpenter.sh/v1"
      kind       = "NodePool"
      metadata = {
        name = node_pool_name
      }
      spec = merge(
        {
          template = {
            metadata = {
              labels = try(node_pool.labels, {})
            }
            spec = {
              nodeClassRef = {
                group = "karpenter.k8s.aws"
                kind  = "EC2NodeClass"
                name  = local.node_class_name
              }
              taints      = local.node_pool_taints[node_pool_name]
              expireAfter = try(node_pool.expire_after, "Never")
              requirements = concat(
                [
                  {
                    key      = "node.kubernetes.io/instance-type"
                    operator = "In"
                    values   = try(node_pool.instance_types, [])
                  },
                  {
                    key      = "kubernetes.io/arch"
                    operator = "In"
                    values   = try(node_pool.arch, ["amd64"])
                  },
                  {
                    key      = "karpenter.sh/capacity-type"
                    operator = "In"
                    values   = try(node_pool.capacity_types, ["on-demand"])
                  },
                ],
                try(node_pool.requirements, []),
              )
            }
          }
          disruption = try(node_pool.disruption, {
            consolidationPolicy = "WhenEmpty"
            consolidateAfter    = "10s"
          })
          weight = try(node_pool.weight, 100)
        },
        try(node_pool.cpu_limit, null) != null || try(node_pool.memory_limit, null) != null ? {
          limits = merge(
            try(node_pool.cpu_limit, null) != null ? { cpu = node_pool.cpu_limit } : {},
            try(node_pool.memory_limit, null) != null ? { memory = node_pool.memory_limit } : {},
          )
        } : {},
        try(node_pool.extra_spec, {}),
      )
    }
  }
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
  yaml_body         = yamlencode(local.node_class_manifest)
  wait_for_rollout  = false
  force_new         = true
  server_side_apply = true
}

# NodePool
resource "kubectl_manifest" "node_pool" {
  for_each         = var.node_pools
  yaml_body        = yamlencode(local.node_pool_manifests[each.key])
  wait_for_rollout = false
  force_new        = true

  depends_on = [
    kubectl_manifest.node_class,
    aws_eks_access_entry.karpenter,
  ]
}

output "public_key" {
  value = data.aws_key_pair.ssh_key.public_key
}
