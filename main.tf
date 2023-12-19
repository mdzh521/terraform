provider "alicloud" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
  region     = "ap-southeast-1" # 香港区域
}

# 定义变量
variable "vpc_cidr_block" {
  description = "VPC的CIDR块"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_blocks" {
  description = "子网的CIDR块列表"
  default     = ["10.0.1.0/24", "10.0.2.0/24"] # a区和b区的CIDR块
}

variable "instance_count_per_subnet" {
  description = "每个子网的实例数量"
  default     = 2
}

variable "ssh_keypair_name" {
  description = "SSH密钥对名称"
  default     = "your_ssh_keypair_name"
}

variable "custom_image_id" {
  description = "自定义镜像ID"
  default     = "your_custom_image_id"
}

variable "security_group_ports" {
  description = "安全组规则端口列表"
  default     = [22, 80, 8080, 443]
}

# 创建VPC
resource "alicloud_vpc" "example_vpc" {
  cidr_block   = var.vpc_cidr_block
  vpc_name     = "example-vpc"
  description  = "Example VPC in Hong Kong"
}

# 创建子网
resource "alicloud_vswitch" "example_vswitch" {
  count            = length(var.subnet_cidr_blocks)
  vpc_id           = alicloud_vpc.example_vpc.id
  cidr_block       = var.subnet_cidr_blocks[count.index]
  vswitch_name     = "example-vswitch-${count.index}"
  availability_zone = element(["a", "b"], count.index)
}

# 创建NAT网关
resource "alicloud_nat_gateway" "example_nat_gateway" {
  depends_on      = [alicloud_vswitch.example_vswitch]
  vpc_id          = alicloud_vpc.example_vpc.id
  specification   = "Small"
  bandwidth       = 5
}

# 创建安全组
resource "alicloud_security_group" "example_security_group" {
  vpc_id       = alicloud_vpc.example_vpc.id
  name         = "example-security-group"
  description  = "Example Security Group"

  # 创建安全组规则
  dynamic "rule" {
    for_each = var.security_group_ports
    content {
      type              = "ingress"
      ip_protocol       = "tcp"
      port_range        = "${rule.value}/${rule.value}"
      priority          = rule.key + 1
      policy            = "accept"
      security_group_id = alicloud_security_group.example_security_group.id
      description       = "Allow port ${rule.value}"
    }
  }
}

# 创建服务器
resource "alicloud_instance" "example_instance" {
  count                   = length(var.subnet_cidr_blocks) * var.instance_count_per_subnet
  instance_name           = "example-instance-${count.index}"
  vswitch_id              = element(alicloud_vswitch.example_vswitch[*].id, count.index % length(alicloud_vswitch.example_vswitch))
  security_groups         = [alicloud_security_group.example_security_group.id]
  instance_type           = "ecs.t5-xlarge" # 更改为适合你需求的实例类型
  image_id                = var.custom_image_id
  internet_charge_type    = "PayByTraffic"
  internet_max_bandwidth_out = 50
  key_name                = var.ssh_keypair_name

  # 系统盘和数据盘配置
  system_disk {
    category = "cloud_efficiency"
    size     = 100
  }

  data_disks {
    category = "cloud_ssd"
    size     = 500
    encrypted = false
    performance_level = "PL1"
  }
}

