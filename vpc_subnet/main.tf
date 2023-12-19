variable "vpc_cidr_block" {
  description = "VPC的CIDR块"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_blocks" {
  description = "子网的CIDR块列表"
  default     = ["10.0.1.0/24", "10.0.2.0/24"] # a区和b区的CIDR块
}

provider "alicloud" {
  region = "ap-southeast-1" # 香港区域
}

resource "alicloud_vpc" "example_vpc" {
  cidr_block   = var.vpc_cidr_block
  vpc_name     = "example-vpc"
  description  = "Example VPC in Hong Kong"
}

resource "alicloud_vswitch" "example_vswitch" {
  count            = length(var.subnet_cidr_blocks)
  vpc_id           = alicloud_vpc.example_vpc.id
  cidr_block       = var.subnet_cidr_blocks[count.index]
  vswitch_name     = "example-vswitch-${count.index}"
  availability_zone = element(["a", "b"], count.index)
}

output "vpc_id" {
  value = alicloud_vpc.example_vpc.id
}

output "vswitch_ids" {
  value = alicloud_vswitch.example_vswitch[*].id
}

