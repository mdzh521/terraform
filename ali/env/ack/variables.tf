variable "ali_access_key" {
  type        = string
  description = "Alibaba Cloud access key for the target account"
  sensitive   = true
}

variable "ali_secret_key" {
  type        = string
  description = "Alibaba Cloud secret key for the target account"
  sensitive   = true
}

variable "ali_region" {
  type        = string
  description = "Alibaba Cloud region for the ACK cluster"
  default     = "cn-hongkong"
}

variable "cluster_name" {
  type        = string
  description = "ACK cluster name"
  default     = "quickstart-ack"
}

variable "cluster_spec" {
  type        = string
  description = "ACK managed cluster spec"
  default     = "ack.pro.small"
}

variable "kubernetes_version" {
  type        = string
  description = "ACK Kubernetes version"
  default     = "1.30.1-aliyun.1"
}

variable "az_count" {
  type        = number
  description = "Number of zones used to create VSwitches"
  default     = 2
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the ACK VPC"
  default     = "10.70.0.0/16"
}

variable "pod_cidr" {
  type        = string
  description = "Pod network CIDR"
  default     = "172.20.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "Service network CIDR"
  default     = "172.21.0.0/20"
}

variable "node_instance_types" {
  type        = list(string)
  description = "ACK node pool instance types"
  default     = ["ecs.c6.large"]
}

variable "node_desired_size" {
  type        = number
  description = "ACK node pool desired size"
  default     = 2
}

variable "node_system_disk_category" {
  type        = string
  description = "ACK node system disk category"
  default     = "cloud_essd"
}

variable "node_system_disk_size" {
  type        = number
  description = "ACK node system disk size in GiB"
  default     = 120
}

variable "node_login_password" {
  type        = string
  description = "ACK worker node login password"
  sensitive   = true
}

variable "kubeconfig_sa_name" {
  type        = string
  description = "ServiceAccount name used for exported kubeconfig"
  default     = "kubeconfig-sa"
}

variable "bootstrap_kubeconfig_ttl_minutes" {
  type        = number
  description = "Temporary validity period for the bootstrap ACK kubeconfig"
  default     = 60
}

variable "create_ack_service_roles" {
  type        = bool
  description = "Whether to create the default ACK service RAM roles and attach system policies"
  default     = true
}

variable "ack_service_roles" {
  type        = map(string)
  description = "ACK service role to system policy mapping"
  default = {
    AliyunCSDefaultRole               = "AliyunCSDefaultRolePolicy"
    AliyunCSManagedKubernetesRole     = "AliyunCSManagedKubernetesRolePolicy"
    AliyunCSManagedCmsRole            = "AliyunCSManagedCmsRolePolicy"
    AliyunCSManagedLogRole            = "AliyunCSManagedLogRolePolicy"
    AliyunCSManagedArmsRole           = "AliyunCSManagedArmsRolePolicy"
    AliyunCSManagedCsiProvisionerRole = "AliyunCSManagedCsiProvisionerRolePolicy"
    AliyunCSManagedCsiPluginRole      = "AliyunCSManagedCsiPluginRolePolicy"
  }
}

variable "ack_admin_uid" {
  type        = string
  description = "Optional RAM user or RAM role ID that should receive ACK cluster admin RBAC automatically"
  default     = ""
}

variable "ack_admin_is_ram_role" {
  type        = bool
  description = "Whether ack_admin_uid refers to a RAM role"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags"
  default     = {}
}
