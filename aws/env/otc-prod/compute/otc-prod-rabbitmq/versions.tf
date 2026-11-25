terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.config.region
}

variable "config" {
  description = "Machine, Ansible, and Rabbitmq settings loaded from otc-prod-rabbitmq.hcl"
  type        = any
  validation {
    condition = try(
      contains(["standalone", "cluster"], var.config.rabbitmq.mode) &&
      (var.config.rabbitmq.mode != "standalone" || var.config.machine.instance_count == 1) &&
      (var.config.rabbitmq.mode != "cluster" || var.config.machine.instance_count >= 3) &&
      (var.config.rabbitmq.mode != "cluster" || var.config.machine.instance_count % 2 == 1),
      false
    )
    error_message = "Standalone requires one machine; cluster mode requires at least 3 machines."
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../../network/terraform.tfstate"
  }
}
