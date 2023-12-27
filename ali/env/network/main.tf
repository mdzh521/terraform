provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.ali_region # 香港区域
}

provider "alicloud" {
  alias      = "hk"
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.ali_region # 香港区域
}

########################### 环境信息 ########################

locals {
  ## vpc 变量内容
  vpc_name       = "prod"
  vpc_cidr_block = "10.0.0.0/16"
  vsw_zone       = ["cn-hongkong-c", "cn-hongkong-b"]

  ## nginx 子网规划
  subnet_names_nginx = [
    "prod-nginx",
    "prod-nginx",
  ]
  subnet_cidr_blocks_nginx = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]

  ## nat 的子网规划
  subnet_names_nat = [
    "prod-nat",
  ]
  subnet_cidr_blocks_nat = [
    "10.0.0.0/24",
  ]

  ## 默认安全组绑定
  security_group_name = "prod-common-security"

}

############################ vpc 创建 #######################

module "vpc" {
  source         = "../../module/vpc"
  vpc_cidr_block = local.vpc_cidr_block
  vpc_name       = local.vpc_name
}

########################### vpc 创建 ########################


########################### NGINX 子网创建 ########################

module "vpc_subnet_nginx" {
  source = "../../module/vswitch"

  vpc_id             = module.vpc.vpc_id
  vsw_zone           = local.vsw_zone
  subnet_names       = local.subnet_names_nginx
  subnet_cidr_blocks = local.subnet_cidr_blocks_nginx
}

module "vpc_subnet_nat" {
  source = "../../module/vswitch"

  vpc_id             = module.vpc.vpc_id
  vsw_zone           = local.vsw_zone
  subnet_names       = local.subnet_names_nat
  subnet_cidr_blocks = local.subnet_cidr_blocks_nat
}
########################### NGINX 子网创建 ########################

########################### NAT 创建 #######################
module "nat_gateway" {
  source = "../../module/nat"

  vpc_id           = module.vpc.vpc_id
  eip_count        = 1
  eip_bandwitdth   = 10
  nat_gateway_name = "prod-nat"
  eip_charge_type  = "PayByTraffic"
  nat_gateway_spec = "Enhanced"

  vsw_id         = tostring(module.vpc_subnet_nat.vsw_id[0])
  vpc_cidr_block = local.vpc_cidr_block
}

########################### NAT 创建 #######################

########################### 安全组 创建 #####################
module "security_group" {
  source = "../../module/secgroup"

  vpc_id = module.vpc.vpc_id
  name   = local.security_group_name

  rules = [
    {
      name = "SSH"
      # ingress (入站) 或egress（出站）
      type        = "ingress"
      description = "SSH Access"
      # ForceNew 或 Internet 网络类型
      nic_type    = "intranet"
      ip_protocol = "tcp"
      port_range  = "22/22"
      priority    = 1
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      name = "http"
      # ingress (入站) 或egress（出站）
      type        = "ingress"
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

########################## 输出信息 ##########################
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vsw_subnet_nginx" {
  value = module.vpc_subnet_nginx.vsw_id
}

output "security_id" {
  value = module.security_group.security_id
}