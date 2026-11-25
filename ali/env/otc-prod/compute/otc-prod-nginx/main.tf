provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.config.region
}

data "terraform_remote_state" "common" {
  backend = "local"
  config = {
    path = "../../network/terraform.tfstate"
  }
}

locals {
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id
  subnet_groups = {
    nginx = data.terraform_remote_state.common.outputs.vsw_subnet_nginx
  }
  security_groups = {
    common = data.terraform_remote_state.common.outputs.security_id
  }
  host_vars = {
    for name, private_ip in module.nginx_instances.instance_ip_name : name => {
      ansible_host            = private_ip
      ansible_user            = var.config.ansible.user
      ansible_target_hostname = try(var.config.ansible.initialization.host_overrides[name].hostname, name)
      ansible_initialization = {
        enabled             = try(var.config.ansible.initialization.host_overrides[name].enabled, var.config.ansible.initialization.enabled)
        modules             = merge(var.config.ansible.initialization.modules, try(var.config.ansible.initialization.host_overrides[name].modules, {}))
        security            = merge(var.config.ansible.initialization.security, try(var.config.ansible.initialization.host_overrides[name].security, {}))
        security_parameters = merge(var.config.ansible.initialization.security_parameters, try(var.config.ansible.initialization.host_overrides[name].security_parameters, {}))
        kernel_parameters   = merge(var.config.ansible.initialization.kernel_parameters, try(var.config.ansible.initialization.host_overrides[name].kernel_parameters, {}))
        memory_parameters   = merge(var.config.ansible.initialization.memory_parameters, try(var.config.ansible.initialization.host_overrides[name].memory_parameters, {}))
        disks               = try(var.config.ansible.initialization.host_overrides[name].disks, var.config.ansible.initialization.disks)
      }
    }
  }
}

output "instance_ip_name" {
  value = module.nginx_instances.instance_ip_name
}

output "ansible_inventory" {
  description = "Initialization inventory for the existing ECS module"
  value = {
    all = {
      children = {
        common = { hosts = var.config.ansible.enabled ? local.host_vars : {} }
      }
    }
  }
}
