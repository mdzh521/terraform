provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.ali_region
}

data "alicloud_ack_service" "this" {
  enable = "On"
  type   = "propayasgo"
}

data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

locals {
  zones = slice(data.alicloud_zones.available.zones[*].id, 0, var.az_count)

  vswitch_cidrs = [
    for index in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, index)
  ]

  tags = merge(
    {
      platform    = "alicloud"
      managed-by  = "terraform"
      environment = "quickstart"
    },
    var.tags,
  )

  bootstrap_kubeconfig_path = "${path.module}/output/bootstrap-kubeconfig"
  bootstrap_kubeconfig      = yamldecode(nonsensitive(data.alicloud_cs_cluster_credential.this.kube_config))
  bootstrap_cluster_name    = local.bootstrap_kubeconfig.clusters[0].name
  bootstrap_cluster_server  = local.bootstrap_kubeconfig.clusters[0].cluster.server
  bootstrap_cluster_ca      = local.bootstrap_kubeconfig.clusters[0].cluster["certificate-authority-data"]
  bootstrap_user_auth       = local.bootstrap_kubeconfig.users[0].user
}

resource "alicloud_ram_role" "ack_service_roles" {
  for_each = var.create_ack_service_roles ? var.ack_service_roles : {}

  role_name = each.key

  assume_role_policy_document = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "cs.aliyuncs.com"
          ]
        }
      }
    ]
    Version = "1"
  })

  description = "Terraform-managed ACK service role ${each.key}"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "ack_service_roles" {
  for_each = var.create_ack_service_roles ? var.ack_service_roles : {}

  policy_name = each.value
  policy_type = "System"
  role_name   = alicloud_ram_role.ack_service_roles[each.key].role_name
}

resource "alicloud_vpc" "this" {
  vpc_name   = var.cluster_name
  cidr_block = var.vpc_cidr

  tags = local.tags
}

resource "alicloud_vswitch" "this" {
  count = var.az_count

  vpc_id       = alicloud_vpc.this.id
  cidr_block   = local.vswitch_cidrs[count.index]
  zone_id      = local.zones[count.index]
  vswitch_name = "${var.cluster_name}-${count.index + 1}"

  tags = local.tags
}

resource "alicloud_cs_managed_kubernetes" "this" {
  name                 = var.cluster_name
  cluster_spec         = var.cluster_spec
  version              = var.kubernetes_version
  vswitch_ids          = alicloud_vswitch.this[*].id
  new_nat_gateway      = true
  pod_cidr             = var.pod_cidr
  service_cidr         = var.service_cidr
  slb_internet_enabled = true
  deletion_protection  = false
  enable_rrsa          = true

  tags = local.tags

  depends_on = [
    data.alicloud_ack_service.this,
    alicloud_ram_role_policy_attachment.ack_service_roles,
  ]
}

resource "alicloud_cs_kubernetes_node_pool" "default" {
  cluster_id            = alicloud_cs_managed_kubernetes.this.id
  node_pool_name        = "${var.cluster_name}-default"
  vswitch_ids           = alicloud_vswitch.this[*].id
  instance_types        = var.node_instance_types
  desired_size          = var.node_desired_size
  password              = var.node_login_password
  install_cloud_monitor = true

  system_disk_category = var.node_system_disk_category
  system_disk_size     = var.node_system_disk_size
  runtime_name         = "containerd"
  image_type           = "AliyunLinux"
}

data "alicloud_cs_cluster_credential" "this" {
  cluster_id                 = alicloud_cs_managed_kubernetes.this.id
  temporary_duration_minutes = var.bootstrap_kubeconfig_ttl_minutes
  output_file                = local.bootstrap_kubeconfig_path

  depends_on = [
    alicloud_cs_kubernetes_node_pool.default,
  ]
}

resource "alicloud_cs_kubernetes_permissions" "admin" {
  count = var.ack_admin_uid == "" ? 0 : 1

  uid = var.ack_admin_uid

  permissions {
    cluster     = alicloud_cs_managed_kubernetes.this.id
    role_type   = "cluster"
    role_name   = "admin"
    namespace   = ""
    is_custom   = false
    is_ram_role = var.ack_admin_is_ram_role
  }
}

provider "kubernetes" {
  alias                  = "cluster"
  host                   = local.bootstrap_cluster_server
  cluster_ca_certificate = base64decode(local.bootstrap_cluster_ca)
  token                  = try(local.bootstrap_user_auth.token, null)
  client_certificate     = try(base64decode(local.bootstrap_user_auth["client-certificate-data"]), null)
  client_key             = try(base64decode(local.bootstrap_user_auth["client-key-data"]), null)
}

module "admin_kubeconfig" {
  source = "../../../modules/kubeconfig-bootstrap"

  providers = {
    kubernetes = kubernetes.cluster
  }

  cluster_name       = local.bootstrap_cluster_name
  cluster_endpoint   = local.bootstrap_cluster_server
  cluster_ca         = local.bootstrap_cluster_ca
  kubeconfig_sa_name = var.kubeconfig_sa_name
  output_path        = "${path.module}/output/kubeconfig"

  depends_on = [
    data.alicloud_cs_cluster_credential.this,
  ]
}
