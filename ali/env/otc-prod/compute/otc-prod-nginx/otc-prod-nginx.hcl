config = {
  region = "cn-hongkong"

  machine = {
    service_name                  = "ali-hk-nginx"
    instance_count                = 2
    instance_type                 = "ecs.u1-c1m1.large"
    image_id                      = "centos_7_9_uefi_x64_20G_alibase_20230816.vhd"
    key_name                      = null
    subnet_group                  = "nginx"
    security_group_group          = "common"
    system_disk_size              = 200
    system_disk_category          = "cloud_ssd"
    system_disk_performance_level = "PL0"
    data_disk_size                = 100
    data_disk_category            = "cloud_essd"
    data_disk_level               = "PL1"
  }

  ansible = {
    # Enable only after a usable ECS SSH key pair is configured above.
    enabled = false
    user    = "root"
    initialization = {
      enabled = false
      modules = {
        hostname           = true
        security_hardening = true
        kernel_tuning      = true
        memory_tuning      = true
        firewall_disable   = true
        selinux_disable    = true
        disk_mount         = false
      }
      security = {
        permit_root_login       = "prohibit-password"
        password_authentication = false
        max_auth_tries          = 4
        login_grace_time        = 30
      }
      kernel_parameters = {
        "fs.file-max"                  = "2097152"
        "net.core.somaxconn"           = "4096"
        "net.ipv4.tcp_max_syn_backlog" = "4096"
        "net.ipv4.ip_local_port_range" = "10240 65535"
      }
      memory_parameters = {
        "vm.swappiness"             = "10"
        "vm.dirty_background_ratio" = "10"
        "vm.dirty_ratio"            = "20"
      }
      security_parameters = {
        "kernel.randomize_va_space" = "2"
        "kernel.kptr_restrict" = "2"
        "kernel.dmesg_restrict" = "1"
        "net.ipv4.conf.all.accept_redirects" = "0"
        "net.ipv4.conf.default.accept_redirects" = "0"
        "net.ipv4.conf.all.send_redirects" = "0"
        "net.ipv4.conf.default.send_redirects" = "0"
        "net.ipv4.conf.all.accept_source_route" = "0"
        "net.ipv4.conf.default.accept_source_route" = "0"
        "net.ipv4.tcp_syncookies" = "1"
      }
      disks = []
      host_overrides = {}
    }
  }
}
