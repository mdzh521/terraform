output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID used by the EKS cluster"
  value       = local.vpc_id
}

output "node_subnet_ids" {
  description = "Subnet IDs used by EKS control plane and managed node groups"
  value       = local.node_subnet_ids
}

output "node_subnet_cidrs" {
  description = "Subnet CIDRs used by EKS managed node groups"
  value       = local.node_subnet_cidrs
}

output "lb_subnet_ids" {
  description = "Subnet IDs tagged for AWS Load Balancer Controller public ELB discovery"
  value       = local.lb_subnet_ids
}

output "lb_subnet_cidrs" {
  description = "Subnet CIDRs tagged for AWS Load Balancer Controller public ELB discovery"
  value       = local.lb_subnet_cidrs
}

output "managed_node_group_names" {
  description = "EKS managed node group names configured by this environment"
  value       = keys(local.eks_managed_node_groups)
}

output "kubeconfig_path" {
  description = "Path of the generated kubeconfig file"
  value       = module.k8s.kubeconfig_path
}

output "efs_id" {
  description = "EFS file system ID"
  value       = module.efs.id
}
