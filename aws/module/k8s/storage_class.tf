variable "efs_id" {
  type = string
}

# 创建 efs SC
resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    fileSystemId     = var.efs_id
    provisioningMode = "efs-ap"
    directoryPerms   = "777"
  }
  #   mount_options = [
  #     "iam"
  #   ]

  depends_on = [
    # module.eks_blueprints_addons
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      metadata[0].annotations,
      reclaim_policy
    ]
  }
}

# 取消gp2为默认的sc
resource "kubernetes_annotations" "gp2" {
  annotations = {
    "storageclass.kubernetes.io/is-default-class" : "false"
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }

  force = true

  # depends_on = [module.eks_blueprints_addons]
}

# 新建gp3, 并设置为默认
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "ext4"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [
    kubernetes_annotations.gp2,
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}