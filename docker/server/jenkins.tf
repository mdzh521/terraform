resource "docker_image" "jenkins" {
  name         = "jenkins/jenkins:2.332.2-centos7-jdk8"
  keep_locally = true
}

locals {
  container_name    = "jenkins"
  container_network = data.terraform_remote_state.network.outputs.network[0]["name"]
  container_ip      = "10.1.0.10"
  container_user    = "root"

  container_ports = [
    {
      internal = 8080
      external = 8080
    },
    {
      internal = 50000
      external = 50000
    }
  ]

  container_volumes = [
    {
      container_path = "/var/jenkins_home"
      host_path      = "/data/jenkins"
    }
  ]
}

resource "docker_container" "jenkins" {
  name  = local.container_name
  image = docker_image.jenkins.name
  networks_advanced {
    name         = local.container_network
    ipv4_address = local.container_ip
  }
  user = local.container_user


  dynamic "ports" {
    for_each = local.container_ports
    content {
      internal = ports.value.internal
      external = ports.value.external
      ip       = "0.0.0.0"
      protocol = "tcp"
    }

  }

  dynamic "volumes" {
    for_each = local.container_volumes
    content {
      container_path = volumes.value.container_path
      host_path      = volumes.value.host_path
    }

  }

  depends_on = [
    docker_image.jenkins
  ]
}