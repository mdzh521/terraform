provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.ali_region # 香港区域
}


data "terraform_remote_state" "common" {
  backend  = "local"
  config = {
    path = "../network/terraform.tfstate"
  }
}

locals {
  # vpc ID 
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id
  # nginx 子网ID
  vsw_subnet_nginx = data.terraform_remote_state.common.outputs.vsw_subnet_nginx
  # 公共安全组 ID
  security_id = data.terraform_remote_state.common.outputs.security_id
}


########################### 安全组 创建 #####################
# module "security_group" {
#   source = "../../module/secgroup"

#   vpc_id = local.vpc_id
#   name = "prod-saas-common"

#   rules = [
#     {
#       name        = "SSH"
#       # ingress (入站) 或egress（出站）
#       type        = "ingress"
#       description = "SSH Access"
#       # ForceNew 或 Internet 网络类型
#       nic_type    = "intranet"
#       ip_protocol = "tcp"
#       port_range  = "22/22"
#       priority    = 1
#       cidr_blocks = ["0.0.0.0/0"]
#     },
#     {
#       name        = "http"
#       # ingress (入站) 或egress（出站）
#       type        = "ingress"
#       description = "SSH Access"
#       # ForceNew 或 Internet 网络类型
#       nic_type    = "intranet"
#       ip_protocol = "tcp"
#       port_range  = "80/80"
#       priority    = 1
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#     #根据实际需求来修改添加
#   ]
# }

########################### 安全组 创建 #####################

########################### ECS 创建 #######################

module "nginx_instances" {
  source = "../../module/ecs"

  instance_count = 2
  service_name   = "ali-hk-nginx"

  image_id      = "centos_7_9_uefi_x64_20G_alibase_20230816.vhd"
  instance_type = "ecs.u1-c1m1.large"
  #key_name              = "<实际使用的key>"
  data_disk_category = "cloud_essd"
  data_disk_size     = 100
  data_disk_level    = "PL1"
  subnet_names       = local.vsw_subnet_nginx
  security_group     = local.security_id
  vpc_id             = local.vpc_id
}
########################### ECS 创建 #######################
