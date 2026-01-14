# provider "aws" {
#   access_key = var.aws_access_key
#   secret_key = var.aws_secret_key
#   region = "ap-east-1"
# }

# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   token                  = data.aws_eks_cluster_auth.this.token
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#     token                  = data.aws_eks_cluster_auth.this.token
#   }
# }

# provider "kubectl" {
#   apply_retry_count      = 10
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   load_config_file       = false
#   token                  = data.aws_eks_cluster_auth.this.token
# }

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# provider "helm" {
#   alias = "eks"

#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#     token                  = data.aws_eks_cluster_auth.this.token
#   }
# }

provider "kubectl" {
  alias                  = "eks"
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}


data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_caller_identity" "current" {}

locals {
  name   = "otc-prod"
  region = "ap-east-1"
  vpc_id = "vpc-053d208ce9f8be481"

  # node 子网ID
  node_subnet_ids = [
    "subnet-0b94bfa63608fd123",
    "subnet-04aff912f207b7930",
    "subnet-00eba1a9593aa0ec4",
  ]
  control_plane_subnet_ids = [
    "subnet-0b94bfa63608fd123",
    "subnet-04aff912f207b7930",
    "subnet-00eba1a9593aa0ec4",
  ]

  node_prefix_list_id = "pl-0f024aef608c0a6b9"
  elb_prefix_list_id  = "pl-06d35b55640ae28d6"

  # vpc下互联网网关ID
  # igw_id = "igw-0928486ff7ac71c73"

  # 磁盘大小
  node_disk_size = 200

  # 密钥对
  ec2_ssh_key = "my-eks-key"

  # jump 安全组ID
  jump_sg_id = "sg-0ac58e61bcd7b1bc4"

  # nat 子网，创建 node 专用 nat 时使用
  # nat_subnet_id = "subnet-03a7f6b7e6b093709"

  # 用来导出kubeconfig 的sa
  eks_kubeconfig_sa = "kubeconfig-sa"

  tags = {
    platform  = "aws-hk"
    owner     = "ops"
    project   = "saas"
  }

  timeouts = {
    create = "20m"
    delete = "20m"
  }
}

# efs 存储
module "efs" {
  source = "./efs"

  vpc_id   = local.vpc_id
  eks_name = local.name

  # eks node 子网
  eks_subnet_ids = local.node_subnet_ids

  tags = local.tags

  # node 子网前缀列表ID
  node_prefix_list_id = local.node_prefix_list_id
}

################################################################################
# iam-irsa
################################################################################
module "efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role = true
  role_name   = "${local.name}-efs-csi-role"

  provider_url = module.eks.oidc_provider

  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  ]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:efs-csi-controller-sa"
  ]
}


################################################################################
# Cluster
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.13.0"

  cluster_name                         = local.name
  cluster_version                      = "1.34"
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true

  vpc_id                     = local.vpc_id
  subnet_ids                 = local.control_plane_subnet_ids
  create_node_security_group = false # default is true

  # 控制面板对node子网放行
  cluster_security_group_additional_rules = {
    ingress_nodes_subnets = {
      description     = "eks of flink node subnets"
      protocol        = "all"
      from_port       = 0
      to_port         = 0
      type            = "ingress"
      prefix_list_ids = [local.node_prefix_list_id]
    }
  }

  iam_role_additional_policies = {
    # 解决 ebs 权限问题
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    use_name_prefix = false
    subnet_ids      = local.node_subnet_ids

    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [local.jump_sg_id]

    use_custom_launch_template      = true
    launch_template_description     = "eks ${local.name} 专用"
    launch_template_use_name_prefix = false

    key_name                = local.ec2_ssh_key
    ebs_optimized           = true
    disable_api_termination = true # 关闭删除保护
    # 磁盘配置
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = local.node_disk_size
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 150
          delete_on_termination = true
        }
      }
    }
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }
    monitoring = {
      enabled = true
    }

    # 配置 kubelet 参数
    cloudinit_pre_nodeadm = [
      {
        content_type = "application/node.eks.aws"
        content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  imageGCLowThresholdPercent: 60
                  imageGCHighThresholdPercent: 70
          EOT
      }
    ]
    timeouts = local.timeouts
    tags     = local.tags
  }

  eks_managed_node_groups = {
    otc-backend = {
      description    = "核心系统组件专用"
      instance_types = ["m7i.xlarge"]
      min_size       = 1
      max_size       = 10
      desired_size   = 4
      # 为节点添加k8s 标签，用于给karpenter选择节点时使用
      labels = {
        component = "otc-backend"
      }

      # 为节点添加污点，仅允许核心组件在其上运行
      # taints = {
      #   dedicated = {
      #     key    = "dedicated"
      #     value  = "system-addons"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
      tags     = local.tags
      timeouts = local.timeouts
    }
    # standby = {
    #   description    = "兜底的备用节点组"
    #   instance_types = ["m7i.xlarge"]
    #   min_size       = 0
    #   max_size       = 10
    #   desired_size   = 0
    #   # 为节点添加k8s 标签，用于给karpenter选择节点时使用
    #   labels = {
    #     component = "standby"
    #   }
    #   tags     = local.tags
    #   timeouts = local.timeouts
    # }
    heavy-load = {
      cluster_version = "1.34"
      description     = "非业务重服务专用节点组"
      ami_type        = "AL2023_x86_64_STANDARD" # 必须指定 AL2023 AMI 才能使用 cloudinit_pre_nodeadm
      instance_types  = ["m7i.xlarge"]
      min_size        = 1
      max_size        = 10
      desired_size    = 1

      # 指定唯一的启动模板名称，避免与已存在的启动模板冲突
      launch_template_name = "${local.name}-heavy-load-v2"

      labels = {
        tier      = "heavy-load"
        stack     = "heavy-load"
        component = "heavy-load"
      }
      taints = {
        dedicated = {
          key    = "dedicated"
          value  = "heavy-load"
          effect = "NO_SCHEDULE"
        }
      }

      # 在具体的 node pool 配置 cloudinit_pre_nodeadm，来覆盖 eks_managed_node_group_defaults 里的配置
      # 避免直接修改 eks_managed_node_group_defaults，影响其它node pool(导致重建所有节点)
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  imageGCLowThresholdPercent: 60
                  imageGCHighThresholdPercent: 70
                  containerLogMaxSize: 50Mi
                  containerLogMaxFiles: 5
                  containerLogMaxWorkers: 10
                  containerLogMonitorInterval: 10s
          EOT
        }
      ]

      tags     = local.tags
      timeouts = local.timeouts
    }
  }

  tags = local.tags
}


module "k8s" {
  source = "./k8s"

  eks_name = local.name

  # 为导出 kubeconfig 创建的 sa 的 name
  kubeconfig_sa_name = local.eks_kubeconfig_sa
  # eks 安全组ID
  eks_sg_id                          = module.eks.cluster_primary_security_group_id
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_endpoint                   = module.eks.cluster_endpoint

  # 镜像仓库相关信息
  # registry_server   = var.registry_server
  # registry_username = var.registry_username
  # registry_password = var.registry_password

  # efs 实例ID
  efs_id = module.efs.id

  node_prefix_list_id = local.node_prefix_list_id
  elb_prefix_list_id  = local.elb_prefix_list_id
}


module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.16"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      addon_version = "v1.11.4-eksbuild.22"
      configuration_values = jsonencode({
        nodeSelector = {
          "component" = "otc-backend"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "otc-backend"
            effect   = "NoSchedule"
          }
        ]
        autoScaling = {
          enabled     = true
          minReplicas = 4
          maxReplicas = 10
        }
        # 覆盖默认的Corefile，将 lameduck 设置为 30s, 原始值是 5s
        # ref: https://docs.aws.amazon.com/zh_cn/eks/latest/best-practices/scale-cluster-services.html#_coredns_lameduck_duration
        # ! 升级 coredns 时，要注意原始的 corefile 是否发生改变，要基于新的 corefile 调整
        corefile = <<-EOF
          .:53 {
              errors
              health {
                  lameduck 30s
              }
              ready
              kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
              }
              prometheus :9153
              forward . /etc/resolv.conf
              cache 30
              loop
              reload
              loadbalance
          }
        EOF
        resources = {
          requests = {
            memory = "100Mi"
            cpu    = "600m"
          }
          limits = {
            memory = "2Gi"
            cpu    = "2"
          }
        }
      })
    }
    vpc-cni = {
      addon_version = "v1.20.2-eksbuild.1"
    }
    kube-proxy = {
      addon_version = "v1.32.6-eksbuild.8"
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.48.0-eksbuild.2"
    }
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    chart_version           = "1.7.1"
    source_policy_documents = data.aws_iam_policy_document.aws_load_balancer_controller_additional[*].json
    values = [
      jsonencode({
        #- --aws-api-throttle=Elastic Load Balancing v2:RegisterTargets|DeregisterTargets=8:40,Elastic Load Balancing v2:Describe.*=50:150
        awsApiThrottle                            = "Elastic Load Balancing v2:RegisterTargets|DeregisterTargets=8:40,Elastic Load Balancing v2:Describe.*=50:150"
        serviceMaxConcurrentReconciles            = "30"   #- --service-max-concurrent-reconciles=30
        targetgroupbindingMaxConcurrentReconciles = "50"   #- --targetgroupbinding-max-concurrent-reconciles=50
        syncPeriod                                = "720h" #- --sync-period=720h
        ingressMaxConcurrentReconciles            = "30"   #- --ingress-max-concurrent-reconciles=30
        controllerConfig = {
          featureGates = {
            EnableRGTAPI = "true"
          }
        }
        enableEndpointSlices = "true"

        resources = {
          requests = {
            cpu    = "200m"
            memory = "400Mi"
          }
          limits = {
            cpu    = "2048m"
            memory = "2048Mi"
          }
        }
      }),
    ]
  }

  enable_aws_efs_csi_driver = true # efs存储
  aws_efs_csi_driver = {
    chart_version = "2.5.6"
  }

  enable_metrics_server = true
  enable_karpenter = true
  karpenter = {
    # chart_version 与 插件版本(appVersion)的对应关系
    # ref: https://github.com/aws/karpenter-provider-aws/blob/main/charts/karpenter/Chart.yaml#L5
    chart_version = "1.7.1"
    namespace     = "kube-system" # ref: https://github.com/aws/karpenter-provider-aws/issues/6973#issuecomment-2340814219
    role_name     = "${module.eks.cluster_name}-karpenter-role"

    # karpenter 1.7.1 新增 iam:ListInstanceProfiles 权限依赖
    # TODO: 待 eks-blueprints-addons 新版本自动添加后，即可删除
    source_policy_documents = [data.aws_iam_policy_document.karpenter_17.json]
    role_name_use_prefix    = false
    # 此处为 karpenter 添加 nodeSelector, 让控制器跑在 system-addons 节点上
    values = [
      <<-EOT
        nodeSelector:
          component: "system-addons"
        tolerations:
          - key: "dedicated"
            operator: "Equal"
            value: "system-addons"
            effect: "NoSchedule"
      EOT
    ]
  }

  tags = local.tags

  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

# karpenter 1.7.1 新增 iam:ListInstanceProfiles 权限依赖
# TODO: 待 eks-blueprints-addons 新版本自动添加后，即可删除
data "aws_iam_policy_document" "karpenter_17" {
  statement {
    sid       = "karpenter17required"
    actions   = ["iam:ListInstanceProfiles"]
    resources = ["*"]
  }
}

module "karpenter_resource" {
  source         = "./karpenter"
  cluster_name   = module.eks.cluster_name
  iam_role_name  = module.eks_blueprints_addons.karpenter.node_iam_role_name
  iam_role_arn   = module.eks_blueprints_addons.karpenter.node_iam_role_arn
  ec2_ssh_key    = local.ec2_ssh_key
  eks_subnet_ids = local.node_subnet_ids
  node_sg_ids = compact([
    local.jump_sg_id,
    module.eks.node_security_group_id,
    module.eks.cluster_primary_security_group_id,
  ])

  node_pools = {
    karpenter-132 = {
      cpu_limit : "20", # 20个r8i.4xlarge
      memory_limit : "64Gi",
      instance_types : ["m7i.xlarge"],
      labels : {},
      taints : {}
    }
  }

  tags = local.tags

  depends_on = [
    module.eks_blueprints_addons
  ]
}

# 为 ALB controller 添加额外的策略
data "aws_iam_policy_document" "aws_load_balancer_controller_additional" {
  statement {
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}