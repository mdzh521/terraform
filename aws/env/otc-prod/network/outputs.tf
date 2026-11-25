output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_ids" {
  value = module.subnets.subnet_ids
}

output "subnet_ids_by_group" {
  value = {
    for group in local.subnet_group_names : group => [
      for subnet in local.subnets : module.subnets.subnet_id_map[subnet.key]
      if subnet.group == group
    ]
  }
}

output "subnet_cidrs_by_group" {
  value = {
    for group in local.subnet_group_names : group => [
      for subnet in local.subnets : subnet.cidr
      if subnet.group == group
    ]
  }
}

output "subnet_plan" {
  value = {
    active = local.subnets
  }
}

output "subnet_public" {
  value = local.public_subnet_ids
}

output "subnet_private" {
  value = local.private_subnet_ids
}

output "subnet_nat" {
  value = local.nat_subnet_ids
}

output "subnet_k8s" {
  value = lookup({
    for group in local.subnet_group_names : group => [
      for subnet in local.subnets : module.subnets.subnet_id_map[subnet.key]
      if subnet.group == group
    ]
  }, "k8s", [])
}

output "subnet_lb" {
  value = lookup({
    for group in local.subnet_group_names : group => [
      for subnet in local.subnets : module.subnets.subnet_id_map[subnet.key]
      if subnet.group == group
    ]
  }, "lb", [])
}

output "common_security_group" {
  value = module.common_security_group.security_group_id
}
