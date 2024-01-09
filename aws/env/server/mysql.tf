locals {
  nginx = [
    {
        ec2_instance_count = 3
        instance_type = "根据实际需求创建类型"
        service_name = "terraform-nginx"
        data_disk_size = 100
        data_iops = 5000
        data_throughput = 1000
    }
  ]
}


########################## nginx 机器创建 #######################
module "nginx" {
  source = "../../module/server/nginx"
 
  ec2_instance_count = tonumber(local.nginx[0].ec2_instance_count)
  instance_type = tostring(local.nginx[0].instance_type)
  service_name = tostring(local.nginx[0].service_name)
  data_disk_size = tonumber(local.nginx[0].data_disk_size)
  data_iops = tonumber(local.nginx[0].data_iops)
  data_throughput = tonumber(local.nginx[0].data_throughput)

  subnet_names = local.subnet_nginx
  security_group = local.common_security_group
  key = local.key
  image_id = local.image_ami
}

############################# 输出服务器信息 #####################
output "nginx" {
  value = module.nginx.ec2_instance_ip_name
}