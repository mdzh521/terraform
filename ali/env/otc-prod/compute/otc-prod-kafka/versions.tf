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
  description = "Machine, Ansible, and Kafka settings loaded from otc-prod-kafka.hcl"
  type        = any
  validation {
    condition = try(
      contains(["standalone", "cluster"], var.config.kafka.mode) &&
      (var.config.kafka.mode != "standalone" || var.config.machine.instance_count == 1) &&
      (var.config.kafka.mode != "cluster" || var.config.machine.instance_count >= 3),
      false
    )
    error_message = "Standalone requires one machine; cluster mode requires at least 3 machines."
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
