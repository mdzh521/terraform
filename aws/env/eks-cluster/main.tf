provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = var.network_state_path
  }
}
