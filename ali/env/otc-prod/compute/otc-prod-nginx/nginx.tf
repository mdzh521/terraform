locals {
  service_name = var.config.machine.service_name
}

########################### ECS 创建 #######################

module "nginx_instances" {
  source = "../../../../module/ecs"

  instance_count                = var.config.machine.instance_count
  service_name                  = local.service_name
  instance_type                 = var.config.machine.instance_type
  image_id                      = var.config.machine.image_id
  subnet_names                  = local.subnet_groups[var.config.machine.subnet_group]
  security_group                = local.security_groups[var.config.machine.security_group_group]
  vpc_id                        = local.vpc_id
  key_name                      = var.config.machine.key_name
  system_disk_size              = var.config.machine.system_disk_size
  system_disk_category          = var.config.machine.system_disk_category
  system_disk_performance_level = var.config.machine.system_disk_performance_level
  data_disk_category            = var.config.machine.data_disk_category
  data_disk_size                = var.config.machine.data_disk_size
  data_disk_level               = var.config.machine.data_disk_level
}
########################### ECS 创建 #######################

########################### 安全组 创建 #####################
# module "security_group" {
#   source = "../../../../module/secgroup"

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
