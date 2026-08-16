variable "eks_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubeconfig_sa_name" {
  description = "ServiceAccount name used to mint the exported kubeconfig"
  type        = string
  default     = "kubeconfig-sa"
}

variable "kubeconfig_namespace" {
  description = "Namespace where the kubeconfig ServiceAccount and token Secret are created"
  type        = string
  default     = "kube-system"
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  type        = string
}

variable "kubeconfig_output_path" {
  description = "Path for the generated kubeconfig file. Defaults to output/kubeconfig under the root module."
  type        = string
  default     = null
}

locals {
  kubeconfig_output_path = coalesce(var.kubeconfig_output_path, "${path.root}/output/kubeconfig")
}

# 创建 SA
resource "kubernetes_service_account_v1" "kubeconfig_sa" {
  metadata {
    name      = var.kubeconfig_sa_name
    namespace = var.kubeconfig_namespace
  }
}

# 为 SA 创建 secret
resource "kubernetes_secret_v1" "kubeconfig_sa_token" {
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
  metadata {
    name      = "${var.kubeconfig_sa_name}-token"
    namespace = var.kubeconfig_namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.kubeconfig_sa_name
    }
  }
}

# 为 SA 绑定角色
resource "kubernetes_cluster_role_binding_v1" "kubeconfig_sa" {
  metadata {
    name = "${kubernetes_service_account_v1.kubeconfig_sa.metadata.0.name}-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kubeconfig_sa.metadata.0.name
    namespace = var.kubeconfig_namespace
  }
}

# 基于 SA 导出 kubeconfig
resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name    = var.eks_name,
    service_account = var.kubeconfig_sa_name,
    sa_token        = lookup(kubernetes_secret_v1.kubeconfig_sa_token.data, "token"),
    cluster_ca      = var.cluster_certificate_authority_data,
    endpoint        = var.cluster_endpoint,
  })
  filename = local.kubeconfig_output_path
}

output "kubeconfig_path" {
  description = "Path of the generated kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "kubeconfig" {
  description = "Generated kubeconfig content"
  value       = local_sensitive_file.kubeconfig.content
  sensitive   = true
}
