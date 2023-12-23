resource "alicloud_nat_gateway" "nat_gateway" {
  nat_gateway_name  = var.nat_gateway_name
  vpc_id            = var.vpc_id
  nat_type          = var.nat_gateway_spec
  payment_type      = var.payment_type
  vswitch_id        = var.vsw_id
}

resource "alicloud_eip" "eip" {
  count                     = var.eip_count
  bandwidth                 = var.eip_bandwitdth
  internet_charge_type      = var.eip_charge_type
}

resource "alicloud_eip_association" "eip_attaachment" {
  count         = var.eip_count
  allocation_id = alicloud_eip.eip[count.index].id
  instance_id   = alicloud_nat_gateway.nat_gateway.id
}

resource "alicloud_snat_entry" "snat_entry" {
  count = var.eip_count
  snat_table_id     = alicloud_nat_gateway.nat_gateway.snat_table_ids
  source_vswitch_id     = var.vsw_id
  snat_ip       = alicloud_eip.eip[count.index].ip_address
}

################################################ 变量 ###################################

variable "vpc_id" {
  description = "VPC ID"
}

variable "eip_count" {
  description = "弹性 IP 数量"
  default = 2
}

variable "payment_type" {
  description = "默认付费模式"
  default = "PayAsYouGo"
}

variable "eip_bandwitdth" {
  description = "弹性IP带宽，默认10M"
  default = 10
}

variable "eip_charge_type" {
  description = "弹性IP付费模式，默认按量付费"
  default = "PayByTraffic"
}

variable "nat_gateway_spec" {
  description = "Nat 网关类型"
  default = "Enhanced"
}

variable "vsw_id" {
  description = "VSWitch ID"
}

variable "nat_gateway_name" {
  description = "NAT 网关名称"
}

variable "vpc_cidr_block" {
  description = "VPC CIDR"
}