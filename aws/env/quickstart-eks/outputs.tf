output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
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
