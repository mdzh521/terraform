config = {
  region = "us-east-1"

  machine = {
    service_name       = "otc-prod-redis"
    instance_count     = 1
    instance_type      = "r7i.large"
    image_id           = "replace-with-amazon-linux-2023-ami-id"
    key_name           = "replace-with-ec2-key-pair"
    subnet_group       = "redis"
    security_group_group = "common"
    root_disk_size     = 40
    root_disk_category = "gp3"
    data_disk_size     = 100
    data_disk_category = "gp3"
    data_throughput    = 125
    data_iops          = 5000
  }

  ansible = {
    enabled = true
    user    = "ec2-user"
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
          device         = "/dev/nvme1n1"
          mount_path     = "/srv/redis/data"
          fstype          = "xfs"
          format_if_empty = true
          mode            = "0750"
          mount_options   = "defaults,noatime"
        }
      ]
      host_overrides = {}
    }
  }

  redis = {
    enabled         = true
    mode            = "standalone" # standalone | replication | cluster
    image           = "redis:7.4"
    port            = 6379
    data_dir        = "/srv/redis/data"
    cluster_replicas = 1
  }
}
