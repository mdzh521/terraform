provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  alias = "eks"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  alias                  = "eks"
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = local.name
}

locals {
  name   = var.cluster_name
  region = var.aws_region

  network_outputs     = data.terraform_remote_state.network.outputs
  subnet_ids_by_group = local.network_outputs.subnet_ids_by_group
  network_subnet_plan = try(local.network_outputs.subnet_plan.active, [])
  subnet_cidrs_by_group = try(local.network_outputs.subnet_cidrs_by_group, {
    for group in distinct([for subnet in local.network_subnet_plan : subnet.group]) : group => [
      for subnet in local.network_subnet_plan : subnet.cidr
      if subnet.group == group
    ]
  })

  vpc_id                   = local.network_outputs.vpc_id
  node_subnet_ids          = local.subnet_ids_by_group[var.network_subnet_groups.node]
  control_plane_subnet_ids = local.subnet_ids_by_group[var.network_subnet_groups.control_plane]
  lb_subnet_ids            = local.subnet_ids_by_group[var.network_subnet_groups.lb]
  node_subnet_cidrs        = local.subnet_cidrs_by_group[var.network_subnet_groups.node]
  lb_subnet_cidrs          = local.subnet_cidrs_by_group[var.network_subnet_groups.lb]
  common_security_group_id = local.network_outputs.common_security_group

  cluster_config              = var.cluster_config
  node_subnet_cluster_ingress = try(local.cluster_config.node_subnet_cluster_ingress, {})
  node_subnet_cluster_ingress_rules = try(local.node_subnet_cluster_ingress.enabled, true) ? {
    ingress_nodes_subnets = {
      description = try(local.node_subnet_cluster_ingress.description, "Allow EKS node subnets to access the EKS cluster security group")
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = local.node_subnet_cidrs
    }
  } : {}

  cluster_security_group_additional_rules = merge(
    local.node_subnet_cluster_ingress_rules,
    try(local.cluster_config.security_group_additional_rules, {}),
  )

  eks_addons = {
    for addon_name, addon in var.eks_addons : addon_name => merge(
      addon,
      try(addon.configuration_values, null) == null ? {} : {
        configuration_values = jsonencode(addon.configuration_values)
      },
    )
  }
  eks_addons_before_compute = {
    for addon_name, addon in local.eks_addons : addon_name => merge(addon, {
      before_compute = true
    })
    if contains(["vpc-cni"], addon_name)
  }
  eks_blueprints_addons = {
    for addon_name, addon in local.eks_addons : addon_name => merge(
      addon,
      addon_name == "aws-ebs-csi-driver" ? {
        service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
      } : {},
    )
    if !contains(keys(local.eks_addons_before_compute), addon_name)
  }

  tags   = var.tags
  addons = var.addons

  aws_load_balancer_controller_addon = try(local.addons.aws_load_balancer_controller, {})
  aws_load_balancer_controller_values = merge(
    try(local.aws_load_balancer_controller_addon.values, {}),
    {
      region = local.region
      vpcId  = local.vpc_id
    },
  )
  aws_load_balancer_controller = merge(
    try(local.aws_load_balancer_controller_addon.config, {}),
    {
      chart_version = try(local.aws_load_balancer_controller_addon.chart_version, "1.7.1")
      source_policy_documents = concat(
        data.aws_iam_policy_document.aws_load_balancer_controller_additional[*].json,
        try(local.aws_load_balancer_controller_addon.source_policy_documents, []),
      )
      values = [jsonencode(local.aws_load_balancer_controller_values)]
    },
  )

  aws_efs_csi_driver_addon = try(local.addons.aws_efs_csi_driver, {})
  aws_efs_csi_driver = merge(
    try(local.aws_efs_csi_driver_addon.config, {}),
    {
      chart_version                   = try(local.aws_efs_csi_driver_addon.chart_version, "2.5.6")
      namespace                       = try(local.aws_efs_csi_driver_addon.namespace, "kube-system")
      controller_service_account_name = try(local.aws_efs_csi_driver_addon.controller_service_account_name, "efs-csi-controller-sa")
      node_service_account_name       = try(local.aws_efs_csi_driver_addon.node_service_account_name, "efs-csi-node-sa")
      role_name                       = coalesce(try(local.aws_efs_csi_driver_addon.role_name, null), "${local.name}-efs-csi-role")
      role_name_use_prefix            = try(local.aws_efs_csi_driver_addon.role_name_use_prefix, false)
    },
  )

  metrics_server_addon = try(local.addons.metrics_server, {})
  metrics_server       = try(local.metrics_server_addon.config, {})

  karpenter_addon = try(local.addons.karpenter, {})
  karpenter = merge(
    try(local.karpenter_addon.config, {}),
    {
      chart_version = try(local.karpenter_addon.chart_version, "1.7.1")
      namespace     = try(local.karpenter_addon.namespace, "kube-system")
      role_name     = coalesce(try(local.karpenter_addon.role_name, null), "${local.name}-karpenter-role")
      source_policy_documents = concat(
        [data.aws_iam_policy_document.karpenter_17.json],
        try(local.karpenter_addon.source_policy_documents, []),
      )
      role_name_use_prefix = try(local.karpenter_addon.role_name_use_prefix, false)
      values               = [yamlencode(try(local.karpenter_addon.values, {}))]
    },
  )

  node_group_defaults = var.node_group_defaults
  eks_managed_node_group_defaults = merge(
    local.node_group_defaults,
    {
      subnet_ids = local.node_subnet_ids

      vpc_security_group_ids = distinct(compact(concat(
        [local.common_security_group_id],
        try(local.node_group_defaults.vpc_security_group_ids, []),
      )))

      launch_template_description = try(local.node_group_defaults.launch_template_description, "eks ${local.name} 专用")
      kubernetes_version          = var.kubernetes_version
      key_name                    = var.ec2_ssh_key
      tags                        = merge(local.tags, try(local.node_group_defaults.tags, {}))
    },
  )

  eks_managed_node_groups = {
    for node_group_name, node_group in var.eks_managed_node_groups : node_group_name => merge(
      local.eks_managed_node_group_defaults,
      {
        launch_template_name = var.launch_template_name_suffix != "" ? "${local.name}-${node_group_name}-${var.launch_template_name_suffix}" : "${local.name}-${node_group_name}"
      },
      node_group,
      {
        tags     = merge(try(local.eks_managed_node_group_defaults.tags, {}), try(node_group.tags, {}))
        timeouts = merge(try(local.eks_managed_node_group_defaults.timeouts, {}), try(node_group.timeouts, {}))
      },
    )
  }
}

# efs 存储
module "efs" {
  source = "../../module/efs"

  vpc_id     = local.vpc_id
  eks_name   = local.name
  efs_config = var.efs_config

  # eks node 子网
  eks_subnet_ids = local.node_subnet_ids

  tags = local.tags

  node_subnet_cidrs = local.node_subnet_cidrs
}

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${local.name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

################################################################################
# Cluster
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                    = local.name
  kubernetes_version      = var.kubernetes_version
  endpoint_public_access  = try(local.cluster_config.endpoint_public_access, true)
  endpoint_private_access = try(local.cluster_config.endpoint_private_access, true)

  endpoint_public_access_cidrs           = try(local.cluster_config.endpoint_public_access_cidrs, ["0.0.0.0/0"])
  enabled_log_types                      = try(local.cluster_config.enabled_log_types, ["api", "audit", "authenticator"])
  authentication_mode                    = try(local.cluster_config.authentication_mode, "API_AND_CONFIG_MAP")
  cloudwatch_log_group_retention_in_days = try(local.cluster_config.cloudwatch_log_group_retention_in_days, 90)

  vpc_id                     = local.vpc_id
  subnet_ids                 = local.control_plane_subnet_ids
  create_node_security_group = try(local.cluster_config.create_node_security_group, false)

  security_group_additional_rules = local.cluster_security_group_additional_rules
  iam_role_additional_policies    = try(local.cluster_config.iam_role_additional_policies, {})

  enable_cluster_creator_admin_permissions = try(local.cluster_config.enable_cluster_creator_admin_permissions, true)

  addons = local.eks_addons_before_compute

  eks_managed_node_groups = local.eks_managed_node_groups

  tags = local.tags
}


module "k8s" {
  source = "../../module/k8s"

  providers = {
    kubernetes = kubernetes.eks
  }

  eks_name = local.name

  # 为导出 kubeconfig 创建的 sa 的 name
  kubeconfig_sa_name   = try(var.k8s_config.kubeconfig_sa_name, "kubeconfig-sa")
  kubeconfig_namespace = try(var.k8s_config.kubeconfig_namespace, "kube-system")
  kubeconfig_output_path = coalesce(
    try(var.k8s_config.kubeconfig_output_path, null),
    "${path.module}/output/kubeconfig",
  )
  # eks 安全组ID
  eks_sg_id                          = module.eks.cluster_primary_security_group_id
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_endpoint                   = module.eks.cluster_endpoint

  # efs 实例ID
  efs_id = module.efs.id

  node_subnet_cidrs = local.node_subnet_cidrs
  elb_subnet_cidrs  = local.lb_subnet_cidrs

  storage_classes           = try(var.k8s_config.storage_classes, {})
  security_group_rule_names = try(var.k8s_config.security_group_rule_names, {})
}


module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  providers = {
    helm       = helm.eks
    kubernetes = kubernetes.eks
  }

  cluster_name      = local.name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = var.kubernetes_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  observability_tag = null
  create_delay_dependencies = concat(
    [for node_group in values(module.eks.eks_managed_node_groups) : node_group.node_group_arn],
    [aws_iam_role_policy_attachment.ebs_csi_driver.id],
  )

  eks_addons = local.eks_blueprints_addons

  enable_aws_load_balancer_controller = try(local.aws_load_balancer_controller_addon.enabled, false)
  aws_load_balancer_controller        = local.aws_load_balancer_controller

  enable_aws_efs_csi_driver = try(local.aws_efs_csi_driver_addon.enabled, false)
  aws_efs_csi_driver        = local.aws_efs_csi_driver

  enable_metrics_server = try(local.metrics_server_addon.enabled, false)
  metrics_server        = local.metrics_server

  enable_karpenter = try(local.karpenter_addon.enabled, false)
  karpenter        = local.karpenter

  tags = local.tags
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
  source = "../../module/karpenter"
  count  = try(local.karpenter_addon.enabled, false) ? 1 : 0

  providers = {
    kubectl = kubectl.eks
  }

  cluster_name    = local.name
  iam_role_name   = module.eks_blueprints_addons.karpenter.node_iam_role_name
  iam_role_arn    = module.eks_blueprints_addons.karpenter.node_iam_role_arn
  ec2_ssh_key     = var.ec2_ssh_key
  node_class_name = try(var.karpenter_node_class.name, "al2023")
  node_ami_alias  = try(var.karpenter_node_class.ami_alias, "al2023@v20250915")
  node_class      = var.karpenter_node_class
  eks_subnet_ids  = local.node_subnet_ids
  node_sg_ids = compact([
    local.common_security_group_id,
    module.eks.node_security_group_id,
    module.eks.cluster_primary_security_group_id,
  ])

  node_pools = var.karpenter_node_pools

  tags = local.tags
}

# 为 ALB controller 添加额外的策略
data "aws_iam_policy_document" "aws_load_balancer_controller_additional" {
  statement {
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}
