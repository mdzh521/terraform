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
  description = "Machine, Ansible, and Redis settings loaded from otc-prod-redis.hcl"
  type        = any
  validation {
    condition = try(
      contains(["standalone", "replication", "cluster"], var.config.redis.mode) &&
      var.config.redis.cluster_replicas >= 0 &&
      (var.config.redis.mode != "standalone" || var.config.machine.instance_count == 1) &&
      (var.config.redis.mode != "replication" || var.config.machine.instance_count >= 2) &&
      (var.config.redis.mode != "cluster" || var.config.machine.instance_count >= 3 * (var.config.redis.cluster_replicas + 1)),
      false
    )
    error_message = "Use one node for standalone, at least two for replication, and at least 3 * (replicas + 1) nodes for Redis Cluster."
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
