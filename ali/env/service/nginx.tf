locals {
  service_name = "ali-hk-nginx"
  instance_count = 2
  instance_type = "ecs.u1-c1m1.large"

  ###### 磁盘信息 #######
  data_disk_category = "cloud_essd"
  data_disk_size = 100
  data_disk_level = "PL1"
}

########################### ECS 创建 #######################

module "nginx_instances" {
  source = "../../module/ecs"

  instance_count = local.instance_count
  service_name   = local.service_name

  instance_type = local.instance_type
  data_disk_category = local.data_disk_category
  data_disk_size     = local.data_disk_size
  data_disk_level    = local.data_disk_level

  ## 公共信息
  #key_name              = "<实际使用的key>"
  image_id      = local.centos_image
  subnet_names       = local.vsw_subnet_nginx
  security_group     = local.security_id
  vpc_id             = local.vpc_id
}
########################### ECS 创建 #######################

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
