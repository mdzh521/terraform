module "nat" {
  source = "../../module/common/nat"

  nat_subnet_id    = local.nat_subnet_ids[var.nat_subnet_index]
  nat_gateway_name = var.nat_gateway_name
  nat_eip_name     = var.nat_eip_name
  tags             = var.tags

  depends_on = [
    module.prod-gateway,
  ]
}
