provider "docker" {
  host = var.docker_host
}

variable "docker_host" {
  type        = string
  description = "Docker daemon API endpoint"
  default     = "tcp://172.22.192.1:2375"
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../network/terraform.tfstate"
  }
}
