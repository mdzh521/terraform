variable "vpc_id" {
  description = "VPC ID for the Aurora cluster and security group"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the DB subnet group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs are required for an Aurora DB subnet group."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to MySQL port. Keep this to EKS node subnet CIDRs by default."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one allowed CIDR block is required."
  }
}

variable "cluster_identifier" {
  description = "Target Aurora cluster identifier"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "db_subnet_group_description" {
  description = "DB subnet group description"
  type        = string
  default     = "Aurora DB subnet group"
}

variable "security_group_name" {
  description = "RDS security group name"
  type        = string
}

variable "security_group_description" {
  description = "RDS security group description"
  type        = string
  default     = "Allow EKS node subnets to access Aurora MySQL"
}

variable "engine" {
  description = "Aurora engine"
  type        = string
  default     = "aurora-mysql"
}

variable "engine_mode" {
  description = "Aurora engine mode"
  type        = string
  default     = "provisioned"
}

variable "engine_version" {
  description = "Aurora engine version"
  type        = string
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "db_cluster_parameter_group_name" {
  description = "DB cluster parameter group name"
  type        = string
  default     = null
}

variable "storage_encrypted" {
  description = "Whether cluster storage is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN or ID used for encrypted storage"
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = null
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = null
}

variable "copy_tags_to_snapshot" {
  description = "Whether to copy tags to snapshots"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled"
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "CloudWatch log exports enabled for the cluster"
  type        = list(string)
  default     = []
}

variable "iam_database_authentication_enabled" {
  description = "Whether IAM database authentication is enabled"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Whether changes are applied immediately"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on destroy"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier used when skip_final_snapshot is false"
  type        = string
  default     = null
}

variable "serverlessv2_scaling_configuration" {
  description = "Aurora Serverless v2 scaling configuration. Required when any instance uses db.serverless."
  type = object({
    min_capacity             = number
    max_capacity             = number
    seconds_until_auto_pause = optional(number)
  })
  default = null
}

variable "restore_to_point_in_time" {
  description = "Point-in-time restore configuration used for Aurora clone"
  type = object({
    source_cluster_identifier  = string
    restore_type               = optional(string, "copy-on-write")
    use_latest_restorable_time = optional(bool, true)
    restore_to_time            = optional(string)
  })
  default = null
}

variable "instances" {
  description = "Aurora cluster instances"
  type = map(object({
    instance_class                  = string
    identifier                      = optional(string)
    availability_zone               = optional(string)
    publicly_accessible             = optional(bool, false)
    db_parameter_group_name         = optional(string)
    promotion_tier                  = optional(number)
    monitoring_interval             = optional(number)
    monitoring_role_arn             = optional(string)
    performance_insights_enabled    = optional(bool)
    performance_insights_kms_key_id = optional(string)
    ca_cert_identifier              = optional(string)
    auto_minor_version_upgrade      = optional(bool, true)
    apply_immediately               = optional(bool)
    copy_tags_to_snapshot           = optional(bool)
    tags                            = optional(map(string), {})
  }))

  validation {
    condition     = length(var.instances) > 0
    error_message = "At least one Aurora cluster instance is required."
  }
}

variable "tags" {
  description = "Tags to add to RDS resources"
  type        = map(string)
  default     = {}
}
