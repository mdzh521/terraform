locals {
  security_groups = {
    common = data.terraform_remote_state.network.outputs.common_security_group
  }
}

module "compute" {
  source = "../../../../module/server/nginx"

  ec2_instance_count = var.config.machine.instance_count
  instance_type      = var.config.machine.instance_type
  subnet_names       = data.terraform_remote_state.network.outputs.subnet_ids_by_group[var.config.machine.subnet_group]
  security_group     = local.security_groups[var.config.machine.security_group_group]
  key                = var.config.machine.key_name
  image_id           = var.config.machine.image_id
  service_name       = var.config.machine.service_name
  root_disk_size     = var.config.machine.root_disk_size
  root_disk_category = var.config.machine.root_disk_category
  data_disk_size     = var.config.machine.data_disk_size
  data_disk_category = var.config.machine.data_disk_category
  data_throughput    = var.config.machine.data_throughput
  data_iops          = var.config.machine.data_iops
}

locals {
  hostnames = sort(keys(module.compute.ec2_instance_ip_name))
  host_vars = {
    for name, private_ip in module.compute.ec2_instance_ip_name : name => {
      ansible_host      = private_ip
      redis_announce_ip = private_ip
      ansible_user      = var.config.ansible.user
      ansible_initialization = {
        enabled             = try(var.config.ansible.initialization.host_overrides[name].enabled, var.config.ansible.initialization.enabled)
        modules             = merge(var.config.ansible.initialization.modules, try(var.config.ansible.initialization.host_overrides[name].modules, {}))
        security            = merge(var.config.ansible.initialization.security, try(var.config.ansible.initialization.host_overrides[name].security, {}))
        security_parameters = merge(var.config.ansible.initialization.security_parameters, try(var.config.ansible.initialization.host_overrides[name].security_parameters, {}))
        kernel_parameters   = merge(var.config.ansible.initialization.kernel_parameters, try(var.config.ansible.initialization.host_overrides[name].kernel_parameters, {}))
        memory_parameters   = merge(var.config.ansible.initialization.memory_parameters, try(var.config.ansible.initialization.host_overrides[name].memory_parameters, {}))
        disks               = try(var.config.ansible.initialization.host_overrides[name].disks, var.config.ansible.initialization.disks)
      }
      ansible_target_hostname = try(var.config.ansible.initialization.host_overrides[name].hostname, name)
      redis_enabled           = var.config.ansible.enabled && var.config.redis.enabled
      redis_mode              = var.config.redis.mode
      redis_role              = var.config.redis.mode == "replication" ? (name == local.hostnames[0] ? "primary" : "replica") : "none"
      redis_image             = var.config.redis.image
      redis_port              = var.config.redis.port
      redis_data_dir          = var.config.redis.data_dir
      redis_cluster_replicas  = var.config.redis.cluster_replicas
    }
  }
  active_hosts = var.config.ansible.enabled && var.config.redis.enabled ? local.host_vars : {}
}

output "ansible_inventory" {
  description = "Dynamic inventory for the shared Ansible roles"
  value = {
    all = {
      children = {
        common = { hosts = local.active_hosts }
        redis_standalone = {
          hosts = var.config.redis.mode == "standalone" ? local.active_hosts : {}
        }
        redis_primary = {
          hosts = var.config.ansible.enabled && var.config.redis.enabled && var.config.redis.mode == "replication" && length(local.hostnames) > 0 ? { (local.hostnames[0]) = local.host_vars[local.hostnames[0]] } : {}
        }
        redis_replicas = {
          hosts = var.config.ansible.enabled && var.config.redis.enabled && var.config.redis.mode == "replication" ? { for name, host in local.host_vars : name => host if name != try(local.hostnames[0], "") } : {}
        }
        redis_cluster = {
          hosts = var.config.redis.mode == "cluster" ? local.active_hosts : {}
        }
      }
    }
  }
}

output "ec2_instance_ip_name" {
  value = module.compute.ec2_instance_ip_name
}
