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
  description = "Machine, Ansible, and Rocketmq settings loaded from otc-prod-rocketmq.hcl"
  type        = any
  validation {
    condition = try(
      contains(["standalone", "cluster"], var.config.rocketmq.mode) &&
      (var.config.rocketmq.mode != "standalone" || var.config.machine.instance_count == 1) &&
      (var.config.rocketmq.mode != "cluster" || var.config.machine.instance_count >= 2),
      false
    )
    error_message = "Standalone requires one machine; cluster mode requires at least 2 machines."
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../../network/terraform.tfstate"
  }
}
