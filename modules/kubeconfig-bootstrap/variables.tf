variable "cluster_name" {
  type        = string
  description = "Kubernetes cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "Kubernetes API server endpoint"
}

variable "cluster_ca" {
  type        = string
  description = "Base64-encoded cluster CA certificate"
  sensitive   = true
}

variable "kubeconfig_sa_name" {
  type        = string
  description = "ServiceAccount name used to mint the exported kubeconfig"
  default     = "kubeconfig-sa"
}

variable "namespace" {
  type        = string
  description = "Namespace where the bootstrap ServiceAccount is created"
  default     = "kube-system"
}

variable "output_path" {
  type        = string
  description = "Absolute or module-relative path for the generated kubeconfig file"
}
