provider "docker" {
  host = "tcp://172.22.192.1:2375"
}

locals {
  network_settings = [
    {
      name   = "devops-01"
      driver = "bridge"
      subnet = "10.1.0.0/24"
    },
    {
      name   = "devops-02"
      driver = "bridge"
      subnet = "10.2.0.0/24"
    }
  ]
}

resource "docker_network" "network" {
  count  = length(local.network_settings)
  name   = local.network_settings[count.index]["name"]
  driver = local.network_settings[count.index]["driver"]
  ipam_config {
    subnet = local.network_settings[count.index]["subnet"]
  }
}

output "network" {
  value = [for net in docker_network.network : tomap({ "name" = net.name, "subnet" : tolist(net.ipam_config)[0].subnet })]
}