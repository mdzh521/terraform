# 子网列表
resource "alicloud_vswitch" "vsw" {
  count             = length(var.subnet_names)
  vpc_id            = var.vpc_id
  cidr_block        = var.subnet_cidr_blocks[count.index]
  vswitch_name      = "${var.subnet_names[count.index]}-${var.vsw_zone[count.index % length(var.vsw_zone)]}"
  zone_id           = element(var.vsw_zone, count.index % length(var.vsw_zone))
}

################################################## 变量 #############################################

variable "vpc_id" {
  type = string
}

variable "subnet_names" {
  description = "子网列表名称"
}

variable "subnet_cidr_blocks" {
  description = "子网的CIDR块列表"
}

variable "vsw_zone" {
  description = "可用区列表"
}

################################################# 输出信息 ###########################################3
output "vsw_id" {
  value = alicloud_vswitch.vsw[*].id
}