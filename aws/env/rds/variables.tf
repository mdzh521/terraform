variable "network_state_path" {
  type        = string
  default     = "../network/terraform.tfstate"
  description = "Path to the network Terraform local state file"
}

variable "network_subnet_groups" {
  type = object({
    db  = string
    k8s = string
  })
  default = {
    db  = "mysql"
    k8s = "k8s"
  }
  description = "Network subnet group names exported by the network environment"
}

variable "tags" {
  description = "Tags to add to RDS resources"
  type        = map(string)
  default     = {}
}

variable "rds_config" {
  type        = any
  description = "Aurora clone configuration"
  default = {
    cluster_identifier           = "nebux-otc-new"
    source_cluster_identifier    = "nebux"
    engine                       = "aurora-mysql"
    engine_mode                  = "provisioned"
    engine_version               = "8.0.mysql_aurora.3.10.3"
    port                         = 3306
    db_cluster_parameter_group   = "default.aurora-mysql8.0"
    storage_encrypted            = true
    kms_key_id                   = "arn:aws:kms:ap-east-1:380524635782:key/311d2ca1-bfef-4527-8f58-a3ee774a2d45"
    backup_retention_period      = 1
    preferred_backup_window      = "13:04-13:34"
    preferred_maintenance_window = "tue:12:16-tue:12:46"
    deletion_protection          = true
    copy_tags_to_snapshot        = true
    cloudwatch_logs_exports      = ["audit", "error", "slowquery"]
    restore_type                 = "copy-on-write"
    use_latest_restorable_time   = true

    serverlessv2_scaling_configuration = {
      min_capacity = 0
      max_capacity = 16
    }

    instances = {
      serverless = {
        identifier                   = "nebux-otc-new-serverless"
        instance_class               = "db.serverless"
        availability_zone            = "ap-east-1b"
        publicly_accessible          = false
        db_parameter_group_name      = "default.aurora-mysql8.0"
        monitoring_interval          = 60
        monitoring_role_arn          = "arn:aws:iam::380524635782:role/rds-monitoring-role"
        performance_insights_enabled = true
      }
      provisioned = {
        identifier                   = "nebux-otc-new-ap-east-1a"
        instance_class               = "db.r5.large"
        availability_zone            = "ap-east-1a"
        publicly_accessible          = false
        db_parameter_group_name      = "default.aurora-mysql8.0"
        monitoring_interval          = 60
        monitoring_role_arn          = "arn:aws:iam::380524635782:role/rds-monitoring-role"
        performance_insights_enabled = true
      }
    }
  }
}
