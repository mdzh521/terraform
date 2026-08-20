// 创建 Aurora 使用的 DB subnet group，只放到 network 环境里的 mysql 私有子网。
resource "aws_db_subnet_group" "this" {
  name        = var.db_subnet_group_name
  description = var.db_subnet_group_description
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = var.db_subnet_group_name
    },
  )
}

// 创建 RDS 专用安全组。这里使用内联规则，是为了避免 AWS 默认放开全部出站流量。
resource "aws_security_group" "this" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  // 入站只允许 allowed_cidr_blocks 里的网段访问 MySQL 端口。
  // env/rds 默认只会传入 k8s 节点子网，不会传公网 IP 或其它业务网段。
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks

    content {
      description = "Allow MySQL from EKS node subnet ${ingress.value}"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  // 出站同样只保留到 k8s 节点子网的 MySQL 端口，和入站范围保持一致。
  dynamic "egress" {
    for_each = var.allowed_cidr_blocks

    content {
      description = "Allow MySQL responses to EKS node subnet ${egress.value}"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [egress.value]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.security_group_name
    },
  )
}

// 创建目标 Aurora cluster。当前 env/rds 会通过 restore_to_point_in_time
// 从源集群做 copy-on-write 克隆，不会对源库执行停机或变更操作。
resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier

  engine         = var.engine
  engine_mode    = var.engine_mode
  engine_version = var.engine_version

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  port                   = var.port

  db_cluster_parameter_group_name     = var.db_cluster_parameter_group_name
  storage_encrypted                   = var.storage_encrypted
  kms_key_id                          = var.kms_key_id
  backup_retention_period             = var.backup_retention_period
  preferred_backup_window             = var.preferred_backup_window
  preferred_maintenance_window        = var.preferred_maintenance_window
  copy_tags_to_snapshot               = var.copy_tags_to_snapshot
  deletion_protection                 = var.deletion_protection
  enabled_cloudwatch_logs_exports     = var.enabled_cloudwatch_logs_exports
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  apply_immediately                   = var.apply_immediately
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : var.final_snapshot_identifier

  // 只有当实例里包含 db.serverless 时才需要这个配置。
  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverlessv2_scaling_configuration == null ? [] : [var.serverlessv2_scaling_configuration]

    content {
      min_capacity             = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity             = serverlessv2_scaling_configuration.value.max_capacity
      seconds_until_auto_pause = try(serverlessv2_scaling_configuration.value.seconds_until_auto_pause, null)
    }
  }

  // Aurora 跨 VPC 克隆的核心配置。
  // restore_type=copy-on-write 时，创建速度通常比全量 snapshot restore 更快。
  dynamic "restore_to_point_in_time" {
    for_each = var.restore_to_point_in_time == null ? [] : [var.restore_to_point_in_time]

    content {
      source_cluster_identifier  = restore_to_point_in_time.value.source_cluster_identifier
      restore_type               = try(restore_to_point_in_time.value.restore_type, "copy-on-write")
      use_latest_restorable_time = try(restore_to_point_in_time.value.use_latest_restorable_time, true)
      restore_to_time            = try(restore_to_point_in_time.value.restore_to_time, null)
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_identifier
    },
  )
}

// 创建 Aurora cluster instance。实例数量、规格和 AZ 都由 env/rds 的 rds_config.instances 控制。
resource "aws_rds_cluster_instance" "this" {
  for_each = var.instances

  identifier         = coalesce(try(each.value.identifier, null), "${var.cluster_identifier}-${each.key}")
  cluster_identifier = aws_rds_cluster.this.id

  engine         = aws_rds_cluster.this.engine
  engine_version = aws_rds_cluster.this.engine_version
  instance_class = each.value.instance_class

  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = try(each.value.db_parameter_group_name, null)
  availability_zone       = try(each.value.availability_zone, null)
  publicly_accessible     = try(each.value.publicly_accessible, false)
  promotion_tier          = try(each.value.promotion_tier, null)

  monitoring_interval             = try(each.value.monitoring_interval, null)
  monitoring_role_arn             = try(each.value.monitoring_role_arn, null)
  performance_insights_enabled    = try(each.value.performance_insights_enabled, null)
  performance_insights_kms_key_id = try(each.value.performance_insights_kms_key_id, null)
  ca_cert_identifier              = try(each.value.ca_cert_identifier, null)

  auto_minor_version_upgrade = try(each.value.auto_minor_version_upgrade, true)
  apply_immediately          = coalesce(try(each.value.apply_immediately, null), var.apply_immediately)
  copy_tags_to_snapshot      = coalesce(try(each.value.copy_tags_to_snapshot, null), var.copy_tags_to_snapshot)

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = coalesce(try(each.value.identifier, null), "${var.cluster_identifier}-${each.key}")
    },
  )
}
