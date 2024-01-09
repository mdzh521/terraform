// main.tf
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-east-1"
}

locals {

  ####################################### vpc 变量信息 #####################################
  vpc_cidr_block       = "10.100.0.0/16"
  name                 = "prod-vpc"
  enable_dns_hostnames = true
  ####################################### vpc 变量信息 #####################################

  ####################################### 子网变量信息 #####################################
  azs = ["us-east-1a", "us-east-1b"]

  ## nginx 子网
  nginx_map_public_ip_on_launch = false
  subnet_nginx = [{
    "name" = "prod-nginx",
    "cidr" = "10.100.1.0/24",
    }, {
    "name" = "prod-nginx",
    "cidr" = "10.100.2.0/24",
  }]


  ## public 子网
  public_map_public_ip_on_launch = true
  subnet_public = [{
    "name" = "prod-public",
    "cidr" = "10.100.100.0/24",
    }, {
    "name" = "prod-public",
    "cidr" = "10.100.101.0/24",
  }]

  ####################################### 子网变量信息 #####################################

  ####################################### 互联网网关信息 ###################################
  gateway_name                   = "prod-ec2-gateway"
  gateway_destination_cidr_block = "0.0.0.0/0"
  route_table_name = "prod-vpc-nat"

  ## 自建路由表绑定
  routes = [
    // nat 网关
    {
      destination_cidr_block = "0.0.0.0/0"
      gateway_id             = module.nat.nat_id
    }
  ]

  ### 可以直接绑定公网 IP 的路由表
  route_table_association_subnet_gateway = [
    {
      subnet_id = module.subnet_public.subnet_ids[0]
    },
    {
      subnet_id = module.subnet_public.subnet_ids[1]
    },
    # 添加其他子网 ID...
  ]
  ### 内网通过 NAT 出网
  route_table_association_subnet_nat = [
    {
      subnet_id = module.subnet_nginx.subnet_ids[0]
    },
    {
      subnet_id = module.subnet_nginx.subnet_ids[1]
    },
    # 添加其他子网 ID...
  ]

  ####################################### 绑定外网网关信息 #############################

  ####################################### 安全组变量信息 #####################################

  ## 入网规则
  ingress_ports = [
    {
      description = "TLS from VPC",
      from_port   = 80,
      to_port     = 80,
      protocol    = "tcp",
      cidr_blocks = ["10.10.10.10/32", "10.10.10.1/32"]
    },
    {
      description = "TLS from VPC"
      from_port   = 443,
      to_port     = 443,
      protocol    = "tcp",
      cidr_blocks = ["10.10.10.10/32", "10.10.10.1/32"]
    },
    {
      description = "TLS from VPC"
      from_port   = 8080,
      to_port     = 8080,
      protocol    = "tcp",
      cidr_blocks = ["10.10.10.10/32", "10.10.10.1/32"]
    },
  ]

  ## 出网规则
  egress_ports = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  ####################################### 安全组变量信息 #####################################
}



###################################################### vpc #####################################################
module "vpc" {
  source = "../../module/common/vpc"

  vpc_cidr_block       = local.vpc_cidr_block
  name                 = local.name
  enable_dns_hostnames = local.enable_dns_hostnames
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
###################################################### vpc #####################################################

################################################# subnet ######################################################

module "subnet_nginx" {
  source = "../../module/common/subnet"

  vpc_id                  = module.vpc.vpc_id
  azs                     = local.azs
  subnet_cidr_blocks      = local.subnet_nginx[*].cidr
  subnet_names            = local.subnet_nginx[*].name
  map_public_ip_on_launch = local.nginx_map_public_ip_on_launch
}

module "subnet_public" {
  source = "../../module/common/subnet"

  vpc_id                  = module.vpc.vpc_id
  azs                     = local.azs
  subnet_cidr_blocks      = local.subnet_public[*].cidr
  subnet_names            = local.subnet_public[*].name
  map_public_ip_on_launch = local.public_map_public_ip_on_launch
}

output "subnet_nginx" {
  value = module.subnet_nginx.subnet_ids
}

output "subnet_public" {
  value = module.subnet_public.subnet_ids
}
################################################# subnet ######################################################

################################################# nat ######################################################

module "nat" {
  source        = "../../module/common/nat"
  nat_subnet_id = module.subnet_nginx.subnet_ids[0]
}

################################################# nat ######################################################

################################################# network route ######################################################

data "aws_route_table" "table" {
  vpc_id = module.vpc.vpc_id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

module "prod-gateway" {
  source = "../../module/common/internet_gateway"

  vpc_id                 = module.vpc.vpc_id
  gateway_name           = local.gateway_name
  route_table_id         = data.aws_route_table.table.id
  destination_cidr_block = local.gateway_destination_cidr_block
}



module "nat_gateway_route" {
  source = "../../module/common/route"

  vpc_id           = module.vpc.vpc_id
  route_table_name = local.route_table_name

  routes = [
    for route in local.routes : {
      cidr_block = route.destination_cidr_block
      gateway_id = route.gateway_id
    }
  ]
}
### 可以直接绑定公网 IP 的路由表
resource "aws_route_table_association" "public" {
  count           = length(local.route_table_association_subnet_gateway)
  subnet_id       = local.route_table_association_subnet_gateway[count.index].subnet_id
  route_table_id  = data.aws_route_table.table.id
}
### 内网通过 NAT 出网
resource "aws_route_table_association" "intranet" {
  count           = length(local.route_table_association_subnet_nat)
  subnet_id       = local.route_table_association_subnet_nat[count.index].subnet_id
  route_table_id  = module.nat_gateway_route.route_table_id
}

################################################# network route ######################################################

################################################# security_group ###################################################
module "common_security_group" {
  source = "../../module/common/security_group"

  security_group_name        = "common-prod"
  security_group_description = "common-prod"
  vpc_id                     = module.vpc.vpc_id

  ## 入网安全组
  ingress_rules = [
    for ingress_port in local.ingress_ports : {
      description = ingress_port.description
      from_port   = ingress_port.from_port
      to_port     = ingress_port.to_port
      protocol    = ingress_port.protocol
      cidr_blocks = ingress_port.cidr_blocks
    }
  ]

  ## 出网安全组
  egress_rules = [
    for egress_ports in local.egress_ports : {
      from_port   = egress_ports.from_port
      to_port     = egress_ports.to_port
      protocol    = egress_ports.protocol
      cidr_blocks = egress_ports.cidr_blocks
    }
  ]
}

output "common_security_group" {
  value = module.common_security_group.security_group_id
}
################################################# security_group ###################################################
