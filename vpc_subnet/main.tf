variable "vpc_cidr_block" {
  description = "VPC的CIDR块"
}

variable "azs" {
  description = "可用区列表"
}

variable "subnet_names" {
  description = "子网名称列表"
}

variable "subnet_cidr_blocks" {
  description = "子网的CIDR块列表"
}

resource "alicloud_vpc" "example_vpc" {
  cidr_block   = var.vpc_cidr_block
  vpc_name     = "example-vpc"
  description  = "Example VPC in Hong Kong"
}

resource "alicloud_vswitch" "example_vswitch" {
  count            = length(var.subnet_names)
  vpc_id           = alicloud_vpc.example_vpc.id
  cidr_block       = var.subnet_cidr_blocks[count.index]
  vswitch_name     = "${var.subnet_names[count.index]}-${var.azs[count.index % length(var.azs)]}"
  availability_zone = element(var.azs, count.index % length(var.azs))
}

output "vpc_id" {
  value = alicloud_vpc.example_vpc.id
}

output "vswitch_ids" {
  value = alicloud_vswitch.example_vswitch[*].id
}
