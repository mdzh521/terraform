locals {
  availability_zone_suffixes = {
    for az in var.availability_zones : az => replace(az, var.aws_region, "")
  }

  subnet_groups = [
    for group in var.subnet_groups : {
      name                    = lower(trimspace(group.name))
      cidr_by_az              = zipmap(var.availability_zones, group.cidr_blocks)
      tier                    = lower(group.tier)
      role                    = trimspace(coalesce(group.role, "")) != "" ? lower(trimspace(group.role)) : lower(trimspace(group.name))
      map_public_ip_on_launch = coalesce(group.map_public_ip_on_launch, lower(group.tier) == "public")
      tags                    = group.tags
    }
  ]

  kubernetes_subnet_discovery_tags = var.kubernetes_subnet_discovery_tags
  kubernetes_subnet_tags_enabled   = try(local.kubernetes_subnet_discovery_tags.enabled, false)
  kubernetes_cluster_name          = trimspace(try(local.kubernetes_subnet_discovery_tags.cluster_name, ""))
  kubernetes_cluster_tag_subnet_groups = toset([
    for group_name in try(local.kubernetes_subnet_discovery_tags.cluster_tag_subnet_groups, []) :
    lower(trimspace(group_name))
  ])
  public_lb_subnet_groups = toset([
    for group_name in try(local.kubernetes_subnet_discovery_tags.public_lb_subnet_groups, []) :
    lower(trimspace(group_name))
  ])
  private_lb_subnet_groups = toset([
    for group_name in try(local.kubernetes_subnet_discovery_tags.private_lb_subnet_groups, []) :
    lower(trimspace(group_name))
  ])
  extra_subnet_tags_by_group = {
    for group_name, tags in try(local.kubernetes_subnet_discovery_tags.extra_tags_by_group, {}) :
    lower(trimspace(group_name)) => tags
  }

  subnets = flatten([
    for group in local.subnet_groups : [
      for az in var.availability_zones : {
        key                     = format("%s-%s", group.name, local.availability_zone_suffixes[az])
        name                    = format("%s-%s-%s", var.vpc_name, group.name, local.availability_zone_suffixes[az])
        cidr                    = group.cidr_by_az[az]
        availability_zone       = az
        group                   = group.name
        tier                    = group.tier
        role                    = group.role
        map_public_ip_on_launch = group.map_public_ip_on_launch
        tags = merge(
          group.tags,
          {
            Group = group.name
            Role  = group.role
            Tier  = group.tier
          },
          local.kubernetes_subnet_tags_enabled && contains(local.kubernetes_cluster_tag_subnet_groups, group.name) ? {
            (format("kubernetes.io/cluster/%s", local.kubernetes_cluster_name)) = "shared"
          } : {},
          local.kubernetes_subnet_tags_enabled && contains(local.public_lb_subnet_groups, group.name) ? {
            "kubernetes.io/role/elb" = "1"
          } : {},
          local.kubernetes_subnet_tags_enabled && contains(local.private_lb_subnet_groups, group.name) ? {
            "kubernetes.io/role/internal-elb" = "1"
          } : {},
          lookup(local.extra_subnet_tags_by_group, group.name, {}),
        )
      }
    ]
  ])

  public_subnets = [
    for index, subnet in local.subnets : merge(subnet, { index = index })
    if subnet.tier == "public"
  ]

  private_subnets = [
    for index, subnet in local.subnets : merge(subnet, { index = index })
    if subnet.tier == "private"
  ]

  nat_subnets = [
    for index, subnet in local.subnets : merge(subnet, { index = index })
    if subnet.role == "nat"
  ]

  subnet_group_names = distinct([for subnet in local.subnets : subnet.group])

  public_subnet_ids = [
    for subnet in local.public_subnets : module.subnets.subnet_ids[subnet.index]
  ]

  private_subnet_ids = [
    for subnet in local.private_subnets : module.subnets.subnet_ids[subnet.index]
  ]

  nat_subnet_ids = [
    for subnet in local.nat_subnets : module.subnets.subnet_ids[subnet.index]
  ]
}

module "subnets" {
  source = "../../module/common/subnet"

  vpc_id  = module.vpc.vpc_id
  subnets = local.subnets
  tags    = var.tags
}
