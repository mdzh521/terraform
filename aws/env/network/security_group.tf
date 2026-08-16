module "common_security_group" {
  source = "../../module/common/security_group"

  security_group_name        = var.security_group_name
  security_group_description = var.security_group_description
  security_group_tag         = var.security_group_tag
  vpc_id                     = module.vpc.vpc_id
  ingress_rules              = var.ingress_rules
  egress_rules               = var.egress_rules
}
