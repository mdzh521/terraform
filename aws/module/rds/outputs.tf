output "cluster_id" {
  description = "Aurora cluster ID"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Aurora writer endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Aurora port"
  value       = aws_rds_cluster.this.port
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.this.name
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.this.id
}

output "instance_ids" {
  description = "Aurora instance IDs"
  value       = { for name, instance in aws_rds_cluster_instance.this : name => instance.id }
}

output "instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = { for name, instance in aws_rds_cluster_instance.this : name => instance.endpoint }
}
