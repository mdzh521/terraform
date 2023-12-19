variable "instance_count" {
  description = "需要创建的实例数量"
}

variable "service_type" {
  description = "服务类型"
}

variable "subnet_ids" {
  description = "子网ID列表"
  type        = list(string)
}

variable "image_id" {
  description = "镜像ID"
}

variable "instance_type" {
  description = "实例类型"
}

variable "system_disk" {
  description = "系统盘配置"
  default = {
    size = 100
    type = "cloud_ssd"
  }
}

variable "data_disk" {
  description = "数据盘配置"
  default = {
    size   = 500
    type   = "cloud_ssd"
    device = "/dev/vdb" # 你的设备名称
  }
}

resource "alicloud_instance" "example_instance" {
  count         = var.instance_count
  instance_name = "${var.service_type}-${count.index + 1}"
  vswitch_id    = var.subnet_ids[count.index % length(var.subnet_ids)]
  image_id      = var.image_id
  instance_type = var.instance_type

  system_disk {
    size = var.system_disk["size"]
    type = var.system_disk["type"]
  }

  data_disk {
    size    = var.data_disk["size"]
    type    = var.data_disk["type"]
    device  = var.data_disk["device"]
  }
}
