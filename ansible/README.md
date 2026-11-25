# 公共 Ansible 自动化

`ansible/` 是所有项目共用的自动化层。它不创建云资源；每个项目的 Terraform compute 环境引用现有 EC2/ECS module，并通过 `ansible_inventory` output 把机器和项目配置交给这里的 playbook。

每个 compute 服务目录独立放置一份 HCL 变量文件，例如：

- `aws/env/otc-prod/compute/otc-prod-mysql/otc-prod-mysql.hcl`
- `aws/env/otc-prod/compute/otc-prod-redis/otc-prod-redis.hcl`
- 阿里云对应配置位于 `ali/env/otc-prod/compute/` 下，包括原有 nginx compute root。

`.hcl` 文件集中描述机器数量、规格、镜像、网络分组、密钥、系统盘/数据盘，以及该服务的 Ansible 开关和服务参数。修改服务配置后，只需在对应目录运行 Terraform，不需要编辑公共角色。

## 运行

以 AWS MySQL 为例，从仓库根目录执行：

```sh
terraform -chdir=aws/env/otc-prod/compute/otc-prod-mysql init
terraform -chdir=aws/env/otc-prod/compute/otc-prod-mysql plan -var-file=otc-prod-mysql.hcl
terraform -chdir=aws/env/otc-prod/compute/otc-prod-mysql apply -var-file=otc-prod-mysql.hcl

cd ansible
ansible-galaxy collection install -r requirements.yml
export MYSQL_ROOT_PASSWORD='从安全密钥系统注入'
export ANSIBLE_PRIVATE_KEY_FILE='/path/to/private-key.pem'
TF_ROOT=../aws/env/otc-prod/compute/otc-prod-mysql ansible-playbook playbooks/site.yml
```

Redis 及阿里云服务使用相同流程，替换 Terraform 工作目录、`.hcl` 文件和 `TF_ROOT`。阿里云 API 凭据用 `TF_VAR_ali_access_key`、`TF_VAR_ali_secret_key` 注入；AWS 使用 AWS CLI profile 或运行环境凭据。Ansible 部署是独立步骤，因此只创建机器不会自动安装服务。

Terraform 的 `ansible.enabled` 控制该机器是否进入 Ansible inventory；`ansible.initialization.enabled` 单独控制是否初始化主机，因此可以部署服务但跳过初始化。初始化在每台机器自己的 HCL 中配置，`modules` 下的功能可分别开关；特殊机器将总开关或相应模块设为 `false` 即可跳过。防火墙关闭和 SELinux 关闭是独立模块，不会因运行其他初始化模块而自动执行。SELinux 若需重启，role 会根据模块返回结果重启主机。[Ansible SELinux 模块说明](https://docs.ansible.com/projects/ansible/latest/collections/ansible/posix/selinux_module.html)

## 公共 role

- `host_init`：初始化模块编排器，只负责按每台主机的开关调用子角色。
- `hostname`：设置操作系统主机名。
- `security_hardening`：强化 SSH 登录策略，并应用安全相关 sysctl 默认项。默认禁止密码登录、限制 root 密码登录、限制认证尝试和关闭 X11 转发；保留密钥登录。
- `kernel_tuning`：应用该主机 HCL 的 `kernel_parameters` 到 `/etc/sysctl.d/90-ops-kernel.conf`。
- `memory_tuning`：应用该主机 HCL 的 `memory_parameters` 到 `/etc/sysctl.d/92-ops-memory.conf`。
- `firewall_disable`：检测并停止/禁用主机上已安装的 firewalld、ufw、nftables、iptables 服务。
- `selinux_disable`：在 RedHat 系发行版持久关闭 SELinux；如需重启则自动重启。其他发行版若当前 SELinux 处于启用状态会明确失败，避免静默跳过。
- `disk_mount`：按该机器 HCL 明确指定的数据设备创建文件系统、挂载到服务数据目录并写入 `/etc/fstab`。AWS 示例使用 `/dev/nvme1n1`，阿里云示例使用 `/dev/vdb`；设备不存在、已有不匹配文件系统、目标挂载点被其他设备占用或发现未知磁盘签名时都会停止。只有 `format_if_empty = true` 且检测到空盘时才会格式化；设备名需要按实例类型和镜像实际情况核实。
- `mysql`：单机 MySQL 容器和持久化数据目录。`innodb_buffer_pool_size` 根据 Ansible 收集的主机内存自动计算，项目 HCL 的 `innodb_buffer_pool_percent` 可设为 50–75% 范围内的值，示例为 70%。MySQL 手册建议 buffer pool 通常使用系统内存的 50–75%。[MySQL 8.4 手册](https://dev.mysql.com/doc/refman/8.4/en/innodb-benefits.html)
- `redis`：单机、主从和 Cluster。主从模式用该 compute HCL 中的实例数生成一个 primary 和其余 replicas；Cluster 所有实例加入同一集群，默认一副本需要至少 6 个节点。
- `kafka`：Apache Kafka KRaft 单机或多节点集群。单机必须配置 1 台；集群至少 3 台，节点同时承担 broker/controller。
- `rocketmq`：RocketMQ 单机或多节点集群。集群模式在每台机器运行 NameServer 和一个独立 master Broker，并让 Broker 使用全部 NameServer 地址。
- `etcd`：单机或静态 bootstrap 集群。集群需要奇数个节点，至少 3 台。
- `rabbitmq`：单机或集群。集群建议使用 3/5/7 个节点，所有节点需注入同一个 `RABBITMQ_ERLANG_COOKIE`，并保证节点主机名互相解析。管理员账号、密码由 `RABBITMQ_DEFAULT_USER`、`RABBITMQ_DEFAULT_PASS` 注入。

MySQL/Redis 密码通过环境 secret 或 Ansible Vault 提供，不放入 HCL。目标机通过 Docker Engine 运行服务，主机安全组需限制应用端口来源；Redis Cluster 节点还需互通 6379 和 16379，不能开放到公网。Terraform host module 复用项目 network 输出的 common security group，不会自行新增入站规则。

这些服务的 HCL 分别位于 `aws/env/otc-prod/compute/otc-prod-{kafka,rocketmq,etcd,rabbitmq}/` 和 `ali/env/otc-prod/compute/` 同名目录中。集群只需在单一 HCL 中将 `mode` 改为 `cluster`，并调整 `machine.instance_count`。安全组规则仍需在项目 network 配置中显式放行节点互通及客户端所需端口：Kafka 9092/9093、RocketMQ 9876/10911、etcd 2379/2380、RabbitMQ 5672/15672/4369/25672。当前角色使用明文协议示例配置（Kafka/etcd 未配置 TLS 与认证，RocketMQ broker 默认单副本，RabbitMQ 管理员凭证与集群 cookie 需从外部注入），上线前应结合网络隔离和服务安全策略补全。

每个服务 HCL 的 `ansible.initialization` 示例启用了全部七个初始化模块，并提供主机级 kernel/memory 参数和数据盘声明。`host_overrides` 使用 Terraform 实例名为键，允许逐台设置 hostname、初始化总开关、模块开关、参数和 `disks`，例如：

```hcl
host_overrides = {
  "otc-prod-kafka-02" = {
    enabled = false # 这台机器完全跳过初始化
  }
  "otc-prod-kafka-03" = {
    modules = { memory_tuning = false }
    kernel_parameters = { "net.core.somaxconn" = "8192" }
  }
  "otc-prod-kafka-04" = {
    disks = [{
      device = "/dev/nvme2n1"
      mount_path = "/srv/kafka/data"
      fstype = "xfs"
      format_if_empty = true
    }]
  }
}
```

要跳过整个服务所有机器的初始化，设置 `ansible.initialization.enabled = false`；要统一关闭某项（例如 SELinux 或磁盘初始化），将 `modules.selinux_disable` 或 `modules.disk_mount` 设为 `false`。`security_parameters`、`kernel_parameters`、`memory_parameters` 和 `disks` 都可以在 HCL 层设置或逐台覆盖。

原有阿里云 nginx compute root 现在也输出初始化 inventory，并集中使用 `otc-prod-nginx.hcl`。该配置当前没有 ECS key pair（`key_name = null`），所以 `ansible.enabled` 和初始化总开关保持关闭；填入可用密钥对后再开启，避免创建无法远程管理的主机。
