# 开始docker的自动化

Docker Provider用于与 Docker 容器和镜像进行交互。它使用 Docker API 来管理 Docker 容器的生命周期。

## 准备工作
安装docker，并开启远程API
``````
关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
cat /etc/selinux/config
SELINUX=disabled


先下载docker二进制包
wget https://download.docker.com/linux/static/stable/x86_64/docker-20.10.12.tgz
tar -zxvf docker-20.10.12.tgz
mv docker/*  /usr/bin

systemd 管理docker

cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
#Requires=docker.socket 
[Service]
Type=notify
## 这里是开启docker API 调用
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock -H tcp://0.0.0.0:2375 -H unix://var/run/docker.sock  -H fd://
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500
[Install]
WantedBy=multi-user.target
EOF

cat > /usr/lib/systemd/system/docker.sock << EOF
[Unit]
Description=Docker Socket for the API
[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker
[Install]
WantedBy=sockets.target
EOF

用户管理
groupadd  docker 
#添加docker组，二进制不会自动添加的，yum会
useradd -g docker -s /sbin/nologin docker
#把要管理的用户添加到组里面就行

mkdir /etc/docker
mkdir /data/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://saq9vra1.mirror.aliyuncs.com","https://registry.docker-cn.com","http://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"],
  "insecure-registries":["hub.cai","hub.cai.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "bip":"10.100.10.1/24",
  "log-opts": {
    "max-size": "100m",
    "max-file": "1"
  },
  "data-root": "/data/docker",
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl start docker
systemctl enable docker
``````

## 测试API : curl http://127.0.0.1:2375/version;
``````
curl http://127.0.0.1:2375/version

{"Platform":{"Name":"Docker Engine - Community"},"Components":[{"Name":"Engine","Version":"19.03.5","Details":{"ApiVersion":"1.40","Arch":"amd64","BuildTime":"2019-11-13T07:24:18.000000000+00:00","Experimental":"false","GitCommit":"633a0ea","GoVersion":"go1.12.12","KernelVersion":"4.18.0-373.el8.x86_64","MinAPIVersion":"1.12","Os":"linux"}},{"Name":"containerd","Version":"1.2.6","Details":{"GitCommit":"894b81a4b802e4eb2a91d1ce216b8817763c29fb"}},{"Name":"runc","Version":"1.0.0-rc8","Details":{"GitCommit":"425e105d5a03fabd737a126ad93d62a9eeede87f"}},{"Name":"docker-init","Version":"0.18.0","Details":{"GitCommit":"fec3683"}}],"Version":"19.03.5","ApiVersion":"1.40","MinAPIVersion":"1.12","GitCommit":"633a0ea","GoVersion":"go1.12.12","Os":"linux","Arch":"amd64","KernelVersion":"4.18.0-373.el8.x86_64","BuildTime":"2019-11-13T07:24:18.000000000+00:00"}
``````