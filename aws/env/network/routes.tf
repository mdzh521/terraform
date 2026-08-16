data "aws_route_table" "main" {
  vpc_id = module.vpc.vpc_id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

module "prod-gateway" {
  source = "../../module/common/internet_gateway"

  vpc_id                 = module.vpc.vpc_id
  gateway_name           = var.gateway_name
  route_table_id         = data.aws_route_table.main.id
  destination_cidr_block = var.gateway_destination_cidr_block
  tags                   = var.tags
}

module "nat_gateway_route" {
  source = "../../module/common/route"

  vpc_id           = module.vpc.vpc_id
  route_table_name = var.nat_route_table_name

  routes = [
    {
      cidr_block     = var.nat_route_destination_cidr_block
      nat_gateway_id = module.nat.nat_id
    }
  ]
}

resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = module.subnets.subnet_ids[local.public_subnets[count.index].index]
  route_table_id = data.aws_route_table.main.id
}

resource "aws_route_table_association" "intranet" {
  count = length(local.private_subnets)

  subnet_id      = module.subnets.subnet_ids[local.private_subnets[count.index].index]
  route_table_id = module.nat_gateway_route.route_table_id
}
