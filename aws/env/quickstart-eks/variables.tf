variable "aws_access_key" {
  type        = string
  description = "AWS access key for the target account"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key for the target account"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region for the EKS cluster"
  default     = "ap-east-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "quickstart-eks"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes version"
  default     = "1.34"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use"
  default     = 2
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the EKS VPC"
  default     = "10.60.0.0/16"
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to create a single shared NAT gateway"
  default     = true
}

variable "node_instance_types" {
  type        = list(string)
  description = "Managed node group instance types"
  default     = ["m7i.large"]
}

variable "node_capacity_type" {
  type        = string
  description = "Managed node group capacity type"
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  type        = number
  description = "Desired node count"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum node count"
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum node count"
  default     = 4
}

variable "node_disk_size" {
  type        = number
  description = "Managed node group root disk size in GiB"
  default     = 100
}

variable "kubeconfig_sa_name" {
  type        = string
  description = "ServiceAccount name used for exported kubeconfig"
  default     = "kubeconfig-sa"
}

variable "eks_admin_principal_arns" {
  type        = list(string)
  description = "Additional IAM principal ARNs granted cluster-admin access through EKS access entries"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags"
  default     = {}
}
