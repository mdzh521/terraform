variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.34"
  description = "EKS Kubernetes version"
}

variable "network_state_path" {
  type        = string
  default     = "../network/terraform.tfstate"
  description = "Path to the network Terraform local state file"
}

variable "network_subnet_groups" {
  type = object({
    control_plane = string
    node          = string
    lb            = string
  })
  default = {
    control_plane = "k8s"
    node          = "k8s"
    lb            = "lb"
  }
  description = "Network subnet group names exported by the network environment"
}

variable "cluster_config" {
  type        = any
  description = "EKS cluster-level settings passed to terraform-aws-modules/eks"
  default = {
    endpoint_public_access                   = true
    endpoint_private_access                  = true
    endpoint_public_access_cidrs             = ["0.0.0.0/0"]
    enabled_log_types                        = ["api", "audit", "authenticator"]
    authentication_mode                      = "API_AND_CONFIG_MAP"
    enable_cluster_creator_admin_permissions = true
    create_node_security_group               = false
    cloudwatch_log_group_retention_in_days   = 90

    node_subnet_cluster_ingress = {
      enabled     = true
      description = "Allow EKS node subnets to access the EKS cluster security group"
    }

    security_group_additional_rules = {}

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }
}

variable "ec2_ssh_key" {
  type        = string
  default     = "my-eks-key"
  description = "EC2 key pair name used by EKS managed nodes and Karpenter nodes"
}

variable "launch_template_name_suffix" {
  type        = string
  default     = "v2"
  description = "Optional suffix appended to generated EKS managed node group launch template names"
}

variable "node_group_defaults" {
  type        = any
  description = "Default settings merged into every EKS managed node group"
  default = {
    use_name_prefix = false

    attach_cluster_primary_security_group = true

    use_custom_launch_template      = true
    launch_template_use_name_prefix = false

    ami_type                = "AL2023_x86_64_STANDARD"
    ebs_optimized           = true
    disable_api_termination = true
    enable_monitoring       = true

    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 200
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

    timeouts = {
      create = "60m"
      delete = "60m"
    }

    tags = {}
  }
}

variable "eks_managed_node_groups" {
  type        = any
  description = "EKS managed node groups. Values are merged with node_group_defaults."
  default = {
    otc-backend = {
      description    = "核心系统组件专用"
      instance_types = ["m7i.xlarge"]
      min_size       = 1
      max_size       = 10
      desired_size   = 4

      labels = {
        component = "otc-backend"
      }
    }

    heavy-load = {
      description    = "非业务重服务专用节点组"
      instance_types = ["m7i.xlarge"]
      min_size       = 1
      max_size       = 10
      desired_size   = 1

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
    }
  }
}

variable "efs_config" {
  type        = any
  description = "EFS settings used by the EFS module"
  default = {
    name                            = null
    encrypted                       = true
    performance_mode                = "generalPurpose"
    throughput_mode                 = "elastic"
    provisioned_throughput_in_mibps = null
    lifecycle_policy = {
      transition_to_ia                    = "AFTER_30_DAYS"
      transition_to_primary_storage_class = "AFTER_1_ACCESS"
    }
    attach_policy                    = false
    security_group_name              = null
    security_group_description       = "Allow EKS nodes to access EFS"
    enable_backup_policy             = true
    create_replication_configuration = false
    name_tag                         = null
    tags                             = {}
  }
}

variable "k8s_config" {
  type        = any
  description = "Kubernetes resources created after the EKS API endpoint is available"
  default = {
    kubeconfig_sa_name     = "kubeconfig-sa"
    kubeconfig_namespace   = "kube-system"
    kubeconfig_output_path = null

    storage_classes = {
      efs = {
        enabled             = true
        name                = "efs"
        reclaim_policy      = "Delete"
        volume_binding_mode = "WaitForFirstConsumer"
        parameters = {
          provisioningMode = "efs-ap"
          directoryPerms   = "777"
        }
      }

      gp2 = {
        patch_default = true
        name          = "gp2"
        is_default    = false
      }

      gp3 = {
        enabled                = true
        name                   = "gp3"
        is_default             = true
        reclaim_policy         = "Delete"
        allow_volume_expansion = true
        volume_binding_mode    = "WaitForFirstConsumer"
        parameters = {
          fsType    = "ext4"
          encrypted = "true"
          type      = "gp3"
        }
      }
    }

    security_group_rule_names = {
      elb_subnets  = "elb 子网"
      node_subnets = "eks node 子网"
    }
  }
}

variable "eks_addons" {
  type        = any
  description = "EKS managed add-ons. configuration_values is defined as an object and encoded by this environment."
  default = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.11"
      configuration_values = {
        nodeSelector = {
          component = "otc-backend"
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
      }
    }

    vpc-cni = {
      addon_version = "v1.23.0-eksbuild.1"
    }

    kube-proxy = {
      addon_version = "v1.34.6-eksbuild.18"
    }

    aws-ebs-csi-driver = {
      addon_version = "v1.63.1-eksbuild.1"
      timeouts = {
        create = "45m"
        update = "45m"
        delete = "30m"
      }
    }
  }
}

variable "addons" {
  type        = any
  description = "Helm-based add-ons managed by eks-blueprints-addons"
  default = {
    aws_load_balancer_controller = {
      enabled       = true
      chart_version = "1.7.1"
      values = {
        awsApiThrottle                            = "Elastic Load Balancing v2:RegisterTargets|DeregisterTargets=8:40,Elastic Load Balancing v2:Describe.*=50:150"
        serviceMaxConcurrentReconciles            = "30"
        targetgroupbindingMaxConcurrentReconciles = "50"
        syncPeriod                                = "720h"
        ingressMaxConcurrentReconciles            = "30"
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
      }
      config = {}
    }

    aws_efs_csi_driver = {
      enabled                         = true
      chart_version                   = "2.5.6"
      namespace                       = "kube-system"
      controller_service_account_name = "efs-csi-controller-sa"
      node_service_account_name       = "efs-csi-node-sa"
      role_name                       = null
      role_name_use_prefix            = false
      config                          = {}
    }

    metrics_server = {
      enabled = true
      config  = {}
    }

    karpenter = {
      enabled              = true
      chart_version        = "1.7.1"
      namespace            = "kube-system"
      role_name            = null
      role_name_use_prefix = false
      values = {
        nodeSelector = {
          component = "otc-backend"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "otc-backend"
            effect   = "NoSchedule"
          }
        ]
      }
      config = {}
    }
  }
}

variable "karpenter_node_class" {
  type        = any
  description = "Karpenter EC2NodeClass settings"
  default = {
    name                = "al2023"
    ami_alias           = "al2023@v20250915"
    detailed_monitoring = true

    kubelet = {
      imageGCLowThresholdPercent  = 60
      imageGCHighThresholdPercent = 70
    }

    metadata_options = {
      httpEndpoint            = "enabled"
      httpProtocolIPv6        = "disabled"
      httpPutResponseHopLimit = 2
      httpTokens              = "required"
    }

    block_device_mappings = [
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
    ]

    tags       = {}
    extra_spec = {}
  }
}

variable "karpenter_node_pools" {
  type        = any
  description = "Karpenter NodePool definitions rendered by the local karpenter module"
  default = {
    karpenter-132 = {
      cpu_limit      = "20"
      memory_limit   = "64Gi"
      instance_types = ["m7i.xlarge"]
      arch           = ["amd64"]
      capacity_types = ["on-demand"]
      expire_after   = "Never"
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "10s"
      }
      weight = 100
      labels = {}
      taints = {}
    }
  }
}

variable "tags" {
  type = map(string)
  default = {
    platform = "aws-hk"
    owner    = "ops"
    project  = "saas"
  }
  description = "Common tags applied to resources created by this environment"
}
