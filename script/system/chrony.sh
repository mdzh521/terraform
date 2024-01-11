#!/bin/bash

# 检测系统类型
if [ -f /etc/redhat-release ]; then
    # CentOS/Rocky 等 Red Hat 系统
    echo "Detected Red Hat based system"
    sudo yum install -y chrony
    sudo systemctl enable chronyd
    sudo systemctl start chronyd
    TIME_SYNC_COMMAND="sudo ntpdate -u cn.pool.ntp.org"
    TIMEZONE="/usr/share/zoneinfo/Asia/Hong_Kong"
elif [ -f /etc/lsb-release ]; then
    # Ubuntu 等 Debian 系统
    echo "Detected Debian based system"
    sudo apt-get update
    sudo apt-get install -y chrony
    sudo systemctl enable chrony
    sudo systemctl start chrony
    TIME_SYNC_COMMAND="sudo ntpdate -u cn.pool.ntp.org"
    TIMEZONE="/usr/share/zoneinfo/Asia/Hong_Kong"
else
    echo "Unsupported system or release"
    exit 1
fi

# 检查是否存在 ntpdate 命令
if ! command -v ntpdate &> /dev/null; then
    echo "ntpdate command not found. Installing ntpdate..."
    if [ -f /etc/redhat-release ]; then
        sudo yum install -y ntpdate
    elif [ -f /etc/lsb-release ]; then
        sudo apt-get install -y ntpdate
    fi
fi

# 设置时区为香港时区
sudo ln -sf "${TIMEZONE}" /etc/localtime

# 手动强制同步时间
echo "Performing manual time synchronization..."
${TIME_SYNC_COMMAND}

echo "Time synchronized manually."

# 重启 Chrony 服务以应用新的时区设置
sudo systemctl restart chronyd

echo "Chrony 已安装并配置完成，时钟源已设置为 cn.pool.ntp.org，时区已设置为 Asia/Hong_Kong,请检查安全组，是否允许放行"
