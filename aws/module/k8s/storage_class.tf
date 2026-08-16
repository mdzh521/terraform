variable "efs_id" {
  description = "EFS file system ID used by the efs StorageClass"
  type        = string
}

variable "storage_classes" {
  description = "StorageClass settings created or patched by this module"
  type        = any
  default     = {}
}

locals {
  efs_storage_class = merge(
    {
      enabled             = true
      name                = "efs"
      reclaim_policy      = "Delete"
      volume_binding_mode = "WaitForFirstConsumer"
      parameters = {
        provisioningMode = "efs-ap"
        directoryPerms   = "777"
      }
    },
    try(var.storage_classes.efs, {}),
  )

  gp2_storage_class = merge(
    {
      patch_default = true
      name          = "gp2"
      is_default    = false
    },
    try(var.storage_classes.gp2, {}),
  )

  gp3_storage_class = merge(
    {
      enabled                = true
      name                   = "gp3"
      is_default             = true
      reclaim_policy         = "Delete"
      allow_volume_expansion = true
      volume_binding_mode    = "WaitForFirstConsumer"
      parameters = {
        fsType    = "ext4"
        encrypted = "true"
        type      = "gp3"
      }
    },
    try(var.storage_classes.gp3, {}),
  )
}

# 创建 efs SC
resource "kubernetes_storage_class_v1" "efs" {
  count = try(local.efs_storage_class.enabled, true) ? 1 : 0

  metadata {
    name = local.efs_storage_class.name
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = local.efs_storage_class.reclaim_policy
  volume_binding_mode = local.efs_storage_class.volume_binding_mode
  parameters = merge(
    try(local.efs_storage_class.parameters, {}),
    {
      fileSystemId = var.efs_id
    },
  )
}

# 取消gp2为默认的sc
resource "kubernetes_annotations" "gp2" {
  count = try(local.gp2_storage_class.patch_default, true) ? 1 : 0

  annotations = {
    "storageclass.kubernetes.io/is-default-class" : tostring(local.gp2_storage_class.is_default)
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = local.gp2_storage_class.name
  }

  force = true
}

# 新建gp3, 并设置为默认
resource "kubernetes_storage_class_v1" "gp3" {
  count = try(local.gp3_storage_class.enabled, true) ? 1 : 0

  metadata {
    name = local.gp3_storage_class.name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : tostring(local.gp3_storage_class.is_default)
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = local.gp3_storage_class.reclaim_policy
  allow_volume_expansion = local.gp3_storage_class.allow_volume_expansion
  volume_binding_mode    = local.gp3_storage_class.volume_binding_mode
  parameters             = local.gp3_storage_class.parameters

  depends_on = [
    kubernetes_annotations.gp2,
  ]
}
