locals {
  subnet_groups = {
    nginx = data.terraform_remote_state.network.outputs.vsw_subnet_nginx
  }
  security_groups = {
    common = data.terraform_remote_state.network.outputs.security_id
  }
}

module "compute" {
  source = "../../../../module/ecs"

  service_name                  = var.config.machine.service_name
  instance_count                = var.config.machine.instance_count
  instance_type                 = var.config.machine.instance_type
  image_id                      = var.config.machine.image_id
  subnet_names                  = local.subnet_groups[var.config.machine.subnet_group]
  security_group                = local.security_groups[var.config.machine.security_group_group]
  vpc_id                        = data.terraform_remote_state.network.outputs.vpc_id
  key_name                      = var.config.machine.key_name
  system_disk_size              = var.config.machine.system_disk_size
  system_disk_category          = var.config.machine.system_disk_category
  system_disk_performance_level = var.config.machine.system_disk_performance_level
  data_disk_size                = var.config.machine.data_disk_size
  data_disk_category            = var.config.machine.data_disk_category
  data_disk_level               = var.config.machine.data_disk_level
}

locals {
  service_hosts = sort(keys(module.compute.instance_ip_name))
  host_vars = {
    for name, private_ip in module.compute.instance_ip_name : name => {
      ansible_host = private_ip
      ansible_user = var.config.ansible.user
      ansible_initialization = {
        enabled             = try(var.config.ansible.initialization.host_overrides[name].enabled, var.config.ansible.initialization.enabled)
        modules             = merge(var.config.ansible.initialization.modules, try(var.config.ansible.initialization.host_overrides[name].modules, {}))
        security            = merge(var.config.ansible.initialization.security, try(var.config.ansible.initialization.host_overrides[name].security, {}))
        security_parameters = merge(var.config.ansible.initialization.security_parameters, try(var.config.ansible.initialization.host_overrides[name].security_parameters, {}))
        kernel_parameters   = merge(var.config.ansible.initialization.kernel_parameters, try(var.config.ansible.initialization.host_overrides[name].kernel_parameters, {}))
        memory_parameters   = merge(var.config.ansible.initialization.memory_parameters, try(var.config.ansible.initialization.host_overrides[name].memory_parameters, {}))
        disks               = try(var.config.ansible.initialization.host_overrides[name].disks, var.config.ansible.initialization.disks)
      }
      ansible_target_hostname  = try(var.config.ansible.initialization.host_overrides[name].hostname, name)
      rabbitmq_enabled         = var.config.ansible.enabled && var.config.rabbitmq.enabled
      rabbitmq_mode            = var.config.rabbitmq.mode
      rabbitmq_image           = var.config.rabbitmq.image
      rabbitmq_data_dir        = var.config.rabbitmq.data_dir
      rabbitmq_port            = var.config.rabbitmq.port
      rabbitmq_nodes           = local.service_hosts
      rabbitmq_management_port = var.config.rabbitmq.management_port
    }
  }
  active_hosts = var.config.ansible.enabled && var.config.rabbitmq.enabled ? local.host_vars : {}
}

output "ansible_inventory" {
  description = "Dynamic inventory for the shared Ansible roles"
  value = {
    all = {
      children = {
        common   = { hosts = var.config.ansible.enabled ? local.host_vars : {} }
        rabbitmq = { hosts = local.active_hosts }
      }
    }
  }
}

output "instance_ip_name" {
  value = module.compute.instance_ip_name
}
