output "cluster_id" {
  description = "ACK cluster ID"
  value       = alicloud_cs_managed_kubernetes.this.id
}

output "cluster_name" {
  description = "ACK cluster name"
  value       = alicloud_cs_managed_kubernetes.this.name
}

output "cluster_endpoint" {
  description = "ACK cluster API endpoint"
  value       = local.bootstrap_cluster_server
}

output "bootstrap_kubeconfig_path" {
  description = "Temporary bootstrap kubeconfig path generated from ACK credentials"
  value       = data.alicloud_cs_cluster_credential.this.output_file
}

output "kubeconfig_path" {
  description = "Generated kubeconfig path"
  value       = module.admin_kubeconfig.kubeconfig_path
}

output "kubeconfig" {
  description = "Generated kubeconfig content"
  value       = module.admin_kubeconfig.kubeconfig
  sensitive   = true
}
