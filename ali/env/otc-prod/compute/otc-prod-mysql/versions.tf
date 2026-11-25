terraform {
  required_version = ">= 1.4.0"
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.214.0"
    }
  }
}

variable "ali_access_key" {
  type      = string
  sensitive = true
}

variable "ali_secret_key" {
  type      = string
  sensitive = true
}

variable "config" {
  description = "Machine, Ansible, and MySQL settings loaded from otc-prod-mysql.hcl"
  type        = any
  validation {
    condition = try(
      !var.config.mysql.enabled || var.config.machine.instance_count == 1,
      false
      ) && try(
      var.config.mysql.innodb_buffer_pool_percent >= 50 && var.config.mysql.innodb_buffer_pool_percent <= 75,
      false
    )
    error_message = "MySQL compute is single-node only; innodb_buffer_pool_percent must be between 50 and 75."
  }
}

provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.config.region
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../../network/terraform.tfstate"
  }
}
