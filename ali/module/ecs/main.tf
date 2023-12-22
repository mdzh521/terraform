################### 服务器创建 ##################
resource "alicloud_instance" "ecs" {
  count = var.instance_count

  host_name                     = "${var.service_name}-${format("%02d", count.index + 1)}"
  instance_name                 = "${var.service_name}-${format("%02d", count.index + 1)}"
  image_id                      = var.image_id
  instance_type                 = var.instance_type
  vswitch_id                    = element(var.subnet_names, count.index % length(var.subnet_names))
  security_groups               = [var.security_group]
  key_name                      = var.key_name
  system_disk_category          = "cloud_efficiency"
  system_disk_size              = 100

  data_disk {
    category              = var.data_disk_category
    size                  = var.data_disk_size
    performance_level     = var.data_disk_level
    delete_with_instance  = true
  }
}

################### 变量 ########################
variable "service_name" {
  description = "主机名"
  type        = string
}

variable "subnet_names" {
  description = "子网列表"
  type = list(string)
}

variable "vpc_id" {
  description = "VPC-ID"
  type        = string
}

variable "instance_count" {
  description = "机器数量"
  type        = number
}

variable "image_id" {
  description = "镜像ID"
  type        = string
}

variable "instance_type" {
  description = "机器类型/规格"
  type        = string
}

variable "key_name" {
  description = "密钥-KEY"
  type = string
}

variable "security_group" {
  description = "安全组"
  type = string
}

variable "data_disk_category" {
  description = "磁盘规格类型"
  type = string
}

variable "data_disk_size" {
  description = "磁盘大小"
  type = number
}

variable "data_disk_level" {
  description = "数据盘规格"
  type = string
}

########################################## 主机信息 #######################################
output "instance_ids" {
  value = alicloud_instance.ecs.*.id
}