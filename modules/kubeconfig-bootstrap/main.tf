terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

resource "kubernetes_service_account" "kubeconfig_sa" {
  metadata {
    name      = var.kubeconfig_sa_name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "kubeconfig_sa_token" {
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  metadata {
    name      = "${var.kubeconfig_sa_name}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.kubeconfig_sa_name
    }
  }
}

resource "kubernetes_cluster_role_binding" "kubeconfig_sa" {
  metadata {
    name = "${var.kubeconfig_sa_name}-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubeconfig_sa.metadata[0].name
    namespace = var.namespace
  }
}

resource "local_sensitive_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name    = var.cluster_name
    service_account = var.kubeconfig_sa_name
    sa_token        = lookup(kubernetes_secret.kubeconfig_sa_token.data, "token")
    cluster_ca      = var.cluster_ca
    endpoint        = var.cluster_endpoint
  })

  filename = var.output_path
}
