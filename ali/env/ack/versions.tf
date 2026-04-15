terraform {
  required_version = ">= 1.4.0"

  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.274.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
