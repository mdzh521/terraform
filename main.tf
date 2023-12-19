provider "alicloud" {
  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"
  region     = "ap-southeast-1" # 香港区域
}

module "vpc_subnet" {
  source = "./vpc_subnet"

  vpc_cidr_block     = "10.0.0.0/16"
  subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
}

module "security_group" {
  source = "./security_group"

  vpc_id             = module.vpc_subnet.vpc_id
  security_group_ports = [22, 80, 8080, 443]
}

module "ecs_instances" {
  source = "./ecs_instances"

  instance_count_per_subnet = [2, 3] # 在这里定义不同子网的服务器数量
  ssh_keypair_name         = "your_ssh_keypair_name"
  custom_image_id          = "your_custom_image_id"
  vswitch_ids              = module.vpc_subnet.vswitch_ids
  security_group_id        = module.security_group.security_group_id
}
