provider "alicloud" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
  region     = "ap-southeast-1" # 香港区域
}

variable "vpc_cidr_block" {
  description = "VPC的CIDR块"
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "可用区列表"
  default     = ["a", "b"]
}

variable "subnet_names" {
  description = "子网名称列表"
  default     = [
    "prod-redis",
    "prod-redis",
    "prod-mysql",
    "prod-mysql",
    "prod-tidb",
    "prod-tidb",
    "prod-mid",
    "prod-mid",
    "prod-skywalking",
    "prod-skywalking",
    "nlb",
    "nlb",
    "prod-mongo",
    "prod-mongo"
  ]
}

variable "subnet_cidr_blocks" {
  description = "子网的CIDR块列表"
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24",
    "10.0.7.0/24",
    "10.0.8.0/24",
    "10.0.9.0/24",
    "10.0.10.0/24",
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24",
    "10.0.14.0/24"
  ]
}

module "vpc_subnet" {
  source = "./vpc_subnet"

  vpc_cidr_block     = var.vpc_cidr_block
  azs                = var.azs
  subnet_names       = var.subnet_names
  subnet_cidr_blocks = var.subnet_cidr_blocks
}

module "security_group" {
  source = "./security_group"

  name = "prod-saas-common"
  rules = [
    {
      name        = "SSH"
      description = "SSH Access"
      ip_protocol = "tcp"
      port_range  = "22/22"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      name        = "HTTP"
      description = "HTTP Access"
      ip_protocol = "tcp"
      port_range  = "80/80"
      cidr_blocks = ["0.0.0.0/0"]
    }
    #根据实际需求来修改添加
  ]
}


data "alicloud_vswitches" "example_vswitches" {
  vpc_id = alicloud_vpc.example_vpc.id
}

module "redis_instances" {
  source = "./service_instances"

  instance_count = 3
  service_type   = "redis"
  subnet_ids     = [
    data.alicloud_vswitches.example_vswitches.vswitches[0].id,
    data.alicloud_vswitches.example_vswitches.vswitches[1].id,
  ]
  image_id       = "image_id" #镜像ID
  instance_type  = "机器类型" #实例类型
}

module "mysql_instances" {
  source = "./service_instances"

  instance_count = 3
  service_type   = "mysql"
  subnet_ids     = [
    data.alicloud_vswitches.example_vswitches.vswitches[0].id,
    data.alicloud_vswitches.example_vswitches.vswitches[1].id,
  ]
  image_id       = "image_id" #镜像ID
  instance_type  = "机器类型" #实例类型
}