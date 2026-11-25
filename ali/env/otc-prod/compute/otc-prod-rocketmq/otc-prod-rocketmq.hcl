config = {
  region = "cn-hongkong"

  machine = {
    service_name                  = "otc-prod-rocketmq"
    instance_count                = 1
    instance_type                 = "ecs.u1-c1m1.large"
    image_id                      = "replace-with-alicloud-linux-3-image-id"
    key_name                      = "replace-with-alicloud-key-pair"
    subnet_group                  = "nginx"
    security_group_group          = "common"
    system_disk_size              = 40
    system_disk_category          = "cloud_essd"
    system_disk_performance_level = "PL0"
    data_disk_size                = 100
    data_disk_category            = "cloud_essd"
    data_disk_level               = "PL1"
  }

  ansible = {
    enabled = true
    user    = "root"
    initialization = {
      enabled = true
      modules = {
        hostname            = true
        security_hardening  = true
        kernel_tuning       = true
        memory_tuning       = true
        firewall_disable    = true
        selinux_disable     = true
        disk_mount         = true
      }
      security = {
        permit_root_login       = "prohibit-password"
        password_authentication = false
        max_auth_tries          = 4
        login_grace_time        = 30
      }
      kernel_parameters = {
        "fs.file-max"                   = "2097152"
        "net.core.somaxconn"            = "4096"
        "net.ipv4.tcp_max_syn_backlog"  = "4096"
        "net.ipv4.ip_local_port_range"  = "10240 65535"
      }
      memory_parameters = {
        "vm.swappiness"            = "10"
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
      disks = [
        {
          device         = "/dev/vdb"
          mount_path     = "/srv/rocketmq/data"
          fstype          = "xfs"
          format_if_empty = true
          mode            = "0750"
          mount_options   = "defaults,noatime"
        }
      ]
      host_overrides = {}
    }
  }

  rocketmq = {
    enabled = true
    mode = "standalone" # standalone | cluster
    image = "apache/rocketmq:5.3.2"
    port = 9876
    data_dir = "/srv/rocketmq/data"
    broker_port = 10911
    home = "/home/rocketmq/rocketmq-5.3.2"
  }
}
