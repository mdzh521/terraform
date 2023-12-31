provider "docker" {
  host = "tcp://172.22.192.1:2375"
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "../network/terraform.tfstate"
  }
}
