variable "instance_count_per_subnet" {
  description = "每个子网的实例数量"
  default     = [2, 2] # 默认情况下，每个子网创建两个服务器
}

variable "ssh_keypair_name" {
  description = "SSH密钥对名称"
  default     = "your_ssh_keypair_name"
}

variable "custom_image_id" {
  description = "自定义镜像ID"
  default     = "your_custom_image_id"
}

provider "alicloud" {
  region = "ap-southeast-1" # 香港区域
}

resource "alicloud_instance" "example_instance" {
  count                   = sum(var.instance_count_per_subnet) * length(var.vswitch_ids)
  instance_name           = "ali-hk-saas-prod-mysql-${count.index + 1}"
  vswitch_id              = element(var.vswitch_ids, count.index % length(var.vswitch_ids))
  security_groups         = [var.security_group_id]
  instance_type           = "ecs.t5-xlarge" # 更改为适合你需求的实例类型
  image_id                = var.custom_image_id
  internet_charge_type    = "PayByTraffic"
  internet_max_bandwidth_out = 50
  key_name                = var.ssh_keypair_name

  # 系统盘和数据盘配置
  system_disk {
    category = "cloud_efficiency"
    size     = 100
  }

  data_disks {
    category = "cloud_ssd"
    size     = 500
    encrypted = false
    performance_level = "PL1"
  }
}
