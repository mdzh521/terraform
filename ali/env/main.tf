provider "alicloud" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
  region     = "ap-southeast-1" # 香港区域
}

############################ vpc 创建 #######################

variable "vpc_cidr_block" {
  description = "VPC的CIDR块"
  default     = "10.0.0.0/16"
}

module "vpc" {
  source         = "../module/vpc"
  vpc_cidr_block = var.vpc_cidr_block
}

########################### vpc 创建 ########################

########################### NGINX 子网创建 ########################

## 可根据自身需求修改子网和名称信息 也可在复制一套用于创建其他子网
variable "vsw_zone" {
  description = "可用区列表"
  #具体可用区信息可查看 https://help.aliyun.com/document_detail/40654.html
  default     = ["cn-hongkong-c", "cn-hongkong-b"]
}

variable "subnet_names_nginx" {
  description = "子网名称列表"
  default     = [
    "prod-nginx",
    "prod-nginx",
  ]
}

variable "subnet_cidr_blocks_nginx" {
  description = "子网的CIDR块列表"
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

module "vpc_subnet_nginx" {
  source = "../module/vswitch"

  vpc_id             = module.vpc.vpc_id
  vsw_zone           = var.vsw_zone
  subnet_names       = var.subnet_names_nginx
  subnet_cidr_blocks = var.subnet_cidr_blocks_nginx
}

variable "subnet_names_nat" {
  description = "子网名称列表"
  default     = [
    "prod-nat",
  ]
}

variable "subnet_cidr_blocks_nat" {
  description = "子网的CIDR块列表"
  default     = [
    "10.0.0.0/24",
  ]
}

module "vpc_subnet_nat" {
  source = "../module/vswitch"

  vpc_id             = module.vpc.vpc_id
  vsw_zone           = var.vsw_zone
  subnet_names       = var.subnet_names_nat
  subnet_cidr_blocks = var.subnet_cidr_blocks_nat
}

########################### 子网创建 ########################


########################### 安全组 创建 #####################
module "security_group" {
  source = "../module/secgroup"

  vpc_id = module.vpc.vpc_id
  name = "prod-saas-common"

  rules = [
    {
      name        = "SSH"
      # ingress (入站) 或egress（出站）
      tyep        = "ingress"
      description = "SSH Access"
      # ForceNew 或 Internet 网络类型
      nic_type    = "intranet"
      ip_protocol = "tcp"
      port_range  = "22/22"
      priority    = 1
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      name        = "http"
      # ingress (入站) 或egress（出站）
      tyep        = "ingress"
      description = "SSH Access"
      # ForceNew 或 Internet 网络类型
      nic_type    = "intranet"
      ip_protocol = "tcp"
      port_range  = "80/80"
      priority    = 1
      cidr_blocks = ["0.0.0.0/0"]
    }
    #根据实际需求来修改添加
  ]
}

########################### 安全组 创建 #####################

########################### ECS 创建 #######################

module "redis_instances" {
  source = "../module/ecs"

  instance_count        = 3
  service_name          = "ali-hk-nginx"
  
  image_id              = "<实际使用的镜像ID>"
  instance_type         = "<实际使用规格>"
  key_name              = "<实际使用的key>"
  data_disk_category    = "cloud_essd"
  data_disk_size        = 100
  data_disk_level       = "PL1"
  subnet_names          = module.vpc_subnet_nginx.vsw_id
  security_group        = module.security_group.security_id
  vpc_id                = module.vpc.vpc_id
}
########################### ECS 创建 #######################

########################### NAT 创建 #######################
module "nat_gateway" {
  source = "../module/nat"

  vpc_id              = module.vpc.vpc_id
  eip_count           = 1 
  eip_bandwitdth      = 10
  nat_gateway_name    = "prod-nat"
  eip_charge_type     = "PayByTraffic"
  nat_gateway_spec    = "Enhanced"

  vsw_id              = tostring(module.vpc_subnet_nginx.vsw_id[0])
  vpc_cidr_block      = var.vpc_cidr_block
}