output "cluster_id" {
  description = "Aurora cluster ID"
  value       = module.rds.cluster_id
}

output "cluster_endpoint" {
  description = "Aurora writer endpoint"
  value       = module.rds.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.rds.cluster_reader_endpoint
}

output "cluster_port" {
  description = "Aurora port"
  value       = module.rds.cluster_port
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = module.rds.db_subnet_group_name
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = module.rds.security_group_id
}

output "allowed_cidr_blocks" {
  description = "CIDR blocks allowed by the RDS security group"
  value       = local.k8s_subnet_cidrs
}

output "instance_ids" {
  description = "Aurora instance IDs"
  value       = module.rds.instance_ids
}

output "instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = module.rds.instance_endpoints
}
