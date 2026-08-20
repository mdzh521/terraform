// 读取 network 环境的本地 state，复用已经创建好的 VPC、mysql 子网和 k8s 子网网段。
data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = var.network_state_path
  }
}

locals {
  // network 环境已经按 subnet group 输出了子网 ID 和 CIDR。
  // 这里 db 使用 mysql 组，allowed_cidr_blocks 使用 k8s 组。
  network_outputs     = data.terraform_remote_state.network.outputs
  subnet_ids_by_group = local.network_outputs.subnet_ids_by_group
  subnet_cidrs_by_group = try(local.network_outputs.subnet_cidrs_by_group, {
    for group in distinct([for subnet in local.network_outputs.subnet_plan.active : subnet.group]) : group => [
      for subnet in local.network_outputs.subnet_plan.active : subnet.cidr
      if subnet.group == group
    ]
  })

  vpc_id           = local.network_outputs.vpc_id
  db_subnet_ids    = local.subnet_ids_by_group[var.network_subnet_groups.db]
  k8s_subnet_cidrs = local.subnet_cidrs_by_group[var.network_subnet_groups.k8s]

  // rds_config 集中放目标 Aurora 名称、源集群、版本、备份窗口、实例规格等配置。
  rds_config                = var.rds_config
  source_cluster_identifier = try(local.rds_config.source_cluster_identifier, "nebux")
  cluster_identifier        = try(local.rds_config.cluster_identifier, "nebux-otc-new")
  db_subnet_group_name      = try(local.rds_config.db_subnet_group_name, local.cluster_identifier)
  security_group_name       = try(local.rds_config.security_group_name, "${local.cluster_identifier}-rds")
  final_snapshot_identifier = try(
    local.rds_config.final_snapshot_identifier,
    "${local.cluster_identifier}-final",
  )

  tags = merge(
    var.tags,
    try(local.rds_config.tags, {}),
    {
      managed_by = "terraform"
      component  = "rds"
    },
  )
}

// 在 plan 阶段查询源 Aurora cluster，提前确认源集群存在。
// 后面的 clone 会使用这个源集群 ID。
data "aws_rds_cluster" "source" {
  cluster_identifier = local.source_cluster_identifier
}

// 创建目标 Aurora 及其安全组。默认只允许 k8s 节点子网访问 3306。
module "rds" {
  source = "../../module/rds"

  vpc_id              = local.vpc_id
  subnet_ids          = local.db_subnet_ids
  allowed_cidr_blocks = local.k8s_subnet_cidrs

  cluster_identifier          = local.cluster_identifier
  db_subnet_group_name        = local.db_subnet_group_name
  db_subnet_group_description = try(local.rds_config.db_subnet_group_description, "Aurora MySQL subnet group for ${local.cluster_identifier}")
  security_group_name         = local.security_group_name
  security_group_description  = try(local.rds_config.security_group_description, "Allow EKS node subnets to access Aurora MySQL")

  engine                              = try(local.rds_config.engine, "aurora-mysql")
  engine_mode                         = try(local.rds_config.engine_mode, "provisioned")
  engine_version                      = local.rds_config.engine_version
  port                                = try(local.rds_config.port, 3306)
  db_cluster_parameter_group_name     = try(local.rds_config.db_cluster_parameter_group, null)
  storage_encrypted                   = try(local.rds_config.storage_encrypted, true)
  kms_key_id                          = try(local.rds_config.kms_key_id, null)
  backup_retention_period             = try(local.rds_config.backup_retention_period, 7)
  preferred_backup_window             = try(local.rds_config.preferred_backup_window, null)
  preferred_maintenance_window        = try(local.rds_config.preferred_maintenance_window, null)
  copy_tags_to_snapshot               = try(local.rds_config.copy_tags_to_snapshot, true)
  deletion_protection                 = try(local.rds_config.deletion_protection, true)
  enabled_cloudwatch_logs_exports     = try(local.rds_config.cloudwatch_logs_exports, [])
  iam_database_authentication_enabled = try(local.rds_config.iam_database_authentication_enabled, false)
  apply_immediately                   = try(local.rds_config.apply_immediately, true)
  skip_final_snapshot                 = try(local.rds_config.skip_final_snapshot, false)
  final_snapshot_identifier           = local.final_snapshot_identifier
  serverlessv2_scaling_configuration  = try(local.rds_config.serverlessv2_scaling_configuration, null)

  // 使用 Aurora point-in-time restore 的 copy-on-write 模式做跨 VPC clone。
  // use_latest_restorable_time=true 表示克隆到当前可恢复的最新时间点。
  restore_to_point_in_time = {
    source_cluster_identifier  = data.aws_rds_cluster.source.id
    restore_type               = try(local.rds_config.restore_type, "copy-on-write")
    use_latest_restorable_time = try(local.rds_config.use_latest_restorable_time, true)
    restore_to_time            = try(local.rds_config.restore_to_time, null)
  }

  instances = local.rds_config.instances
  tags      = local.tags
}
