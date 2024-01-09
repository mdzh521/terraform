resource "aws_instance" "ec2_instance" {
  count = var.ec2_instance_count
  instance_type = var.instance_type
  subnet_id = element(var.subnet_names, count.index % length(var.subnet_names))

  vpc_security_group_ids = [var.security_group]
  
  key_name = var.key
  ami = var.image_id
  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    delete_on_termination = true
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = "gp3"
    volume_size = var.data_disk_size
    delete_on_termination = true
    throughput = var.data_throughput
    iops = var.data_iops
  }

  tags = {
    Name = "${var.service_name}-${format("%02d", count.index + 1)}"
  }
}

############################## 变量 ###############################
variable "ec2_instance_count" {
  description = "服务器数量"
}

variable "instance_type" {
  description = "服务器类型"
}

variable "subnet_names" {
  description = "子网信息"
}

variable "security_group" {
  description = "安全组信息"
}

variable "key" {
  description = "key名称"
}

variable "image_id" {
  description = "镜像信息"
}

variable "service_name" {
  description = "服务器名称"
}

variable "data_disk_size" {
  description = "数据盘大小"
}

variable "data_throughput" {
  description = "磁盘网络吞吐"
  default = 125
}

variable "data_iops" {
  description = "磁盘吞吐量"
  default = 5000
}

################################### 输出 ####################################
output "ec2_instance_ip_name" {
  value = {
    for instance in aws_instance.ec2_instance :
    instance.tags.Name => instance.private_ip
  }
}