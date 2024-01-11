#!/bin/bash

# 检查网络连接
check_network() {
    if ! curl -sI https://www.baidu.com >/dev/null; then
        echo "网络连接异常，请检查网络设置。"
        exit 1
    fi
}

# 默认系统设置
setup_system() {
    # 关闭防火墙
    systemctl stop firewalld
    systemctl disable firewalld
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    cat /etc/selinux/config
}

# 下载并安装 Docker 二进制包
install_docker() {
    # 输入 Docker 版本
    read -p "请输入要安装的 Docker 版本（默认为 20.10.12）: " DOCKER_VERSION
    DOCKER_VERSION=${DOCKER_VERSION:-"20.10.12"}

    DOCKER_TGZ="docker-$DOCKER_VERSION.tgz"

    # 检查 Docker 版本包是否已存在
    if [ -f "$DOCKER_TGZ" ]; then
        echo "使用当前目录下的 $DOCKER_TGZ 进行安装。"
    else
        echo "正在下载 Docker $DOCKER_VERSION ..."
        wget https://download.docker.com/linux/static/stable/x86_64/$DOCKER_TGZ

        if [ $? -ne 0 ]; then
            echo "下载 Docker 失败，请检查网络或手动下载并将 $DOCKER_TGZ 放到脚本同一目录。"
            exit 1
        fi
    fi

    tar -zxvf $DOCKER_TGZ
    mv docker/* /usr/bin
}

# 创建 Docker systemd 配置文件
create_docker_service() {
    DOCKER_SERVICE_FILE="/usr/lib/systemd/system/docker.service"
    if [ ! -f "$DOCKER_SERVICE_FILE" ]; then
        cat > $DOCKER_SERVICE_FILE << EOF
$(cat docker.service)
EOF
    fi
}

# 创建 Docker Socket systemd 配置文件
create_docker_socket() {
    DOCKER_SOCKET_FILE="/usr/lib/systemd/system/docker.sock"
    if [ ! -f "$DOCKER_SOCKET_FILE" ]; then
        cat > $DOCKER_SOCKET_FILE << EOF
$(cat docker.sock)
EOF
    fi
}

# 用户管理
setup_user() {
    if ! grep -q "^docker:" /etc/group; then
        groupadd docker
    fi

    if ! id -u docker &>/dev/null; then
        useradd -g docker -s /sbin/nologin docker
    fi
}

# 创建 Docker 配置文件目录并写入配置信息
create_docker_config() {
    DOCKER_CONFIG_DIR="/etc/docker"
    if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
        mkdir $DOCKER_CONFIG_DIR
    fi

    DOCKER_DAEMON_JSON="$DOCKER_CONFIG_DIR/daemon.json"
    if [ ! -f "$DOCKER_DAEMON_JSON" ]; then
        cat > $DOCKER_DAEMON_JSON << EOF
$(cat daemon.json)
EOF
    fi
}

# 重新加载 systemd
reload_systemd() {
    systemctl daemon-reload
}

# 启动 Docker 并设置开机自启
start_docker() {
    systemctl start docker
    if ! systemctl is-active --quiet docker; then
        echo "Docker 服务启动失败，请检查配置或手动启动 Docker 服务。"
        exit 1
    fi
}

# 输出 Docker 版本信息
show_docker_version() {
    echo "Docker 版本信息："
    docker --version
    docker-compose --version
}

# 完成安装
complete_installation() {
    echo "Docker 已成功安装！"
}

# 执行安装步骤
main() {
    check_network
    setup_system
    install_docker
    create_docker_service
    create_docker_socket
    setup_user
    create_docker_config
    reload_systemd
    start_docker
    show_docker_version
    complete_installation
}

# 调用主函数
main
