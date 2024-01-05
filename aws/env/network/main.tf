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

################################################# subnet ######################################################

############################## security_group ##############################
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

############################## security_group ##############################
