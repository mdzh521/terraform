variable "eks_name" {
  type = string
}

variable "kubeconfig_sa_name" {
  type    = string
  default = "kubeconfig-sa"
}

variable "cluster_certificate_authority_data" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

# 创建 SA
resource "kubernetes_service_account" "kubeconfig_sa" {
  metadata {
    name      = var.kubeconfig_sa_name
    namespace = "kube-system"
  }
}

# 为 SA 创建 secret
resource "kubernetes_secret" "kubeconfig_sa_token" {
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
  metadata {
    name      = "${var.kubeconfig_sa_name}-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = var.kubeconfig_sa_name
    }
  }
}

# 为 SA 绑定角色
resource "kubernetes_cluster_role_binding" "kubeconfig_sa" {
  metadata {
    name = "${kubernetes_service_account.kubeconfig_sa.metadata.0.name}-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubeconfig_sa.metadata.0.name
    namespace = "kube-system"
  }
}

# 基于 SA 导出 kubeconfig
resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name    = var.eks_name,
    service_account = var.kubeconfig_sa_name,
    sa_token        = lookup(kubernetes_secret.kubeconfig_sa_token.data, "token"),
    cluster_ca      = var.cluster_certificate_authority_data,
    endpoint        = var.cluster_endpoint,
  })
  filename = "./output/kubeconfig"
}