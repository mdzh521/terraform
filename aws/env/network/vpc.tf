module "vpc" {
  source = "../../module/common/vpc"

  vpc_cidr_block       = var.vpc_cidr_block
  name                 = var.vpc_name
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = var.tags
}
