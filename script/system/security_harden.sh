#!/bin/bash

# 设置密码策略
set_password_policy() {
    read -p "设置密码最多可多少天不修改：" A
    read -p "设置密码修改之间最小的天数：" B
    read -p "设置密码最短的长度：" C
    read -p "设置密码失效前多少天通知用户：" D

    sed -i '/^PASS_MAX_DAYS/c\PASS_MAX_DAYS   '$A'' /etc/login.defs
    sed -i '/^PASS_MIN_DAYS/c\PASS_MIN_DAYS   '$B'' /etc/login.defs
    sed -i '/^PASS_MIN_LEN/c\PASS_MIN_LEN     '$C'' /etc/login.defs
    sed -i '/^PASS_WARN_AGE/c\PASS_WARN_AGE   '$D'' /etc/login.defs

    echo "已设置好密码策略......"
}

# 设置密码强度
set_password_strength() {
    sed -i '/pam_pwquality.so/c\password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=  difok=1 minlen=8 ucredit=-1 lcredit=-1 dcredit=-1' /etc/pam.d/system-auth
    echo "已对密码进行加固，新密码不得与旧密码相同，必须包含数字、小写字母、大写字母等要素！！"
}

# 设置密码登录次数限制
set_password_login_limit() {
    n=$(grep -c "auth required pam_tally2.so " /etc/pam.d/sshd)

    if [ $n -eq 0 ]; then
        sed -i '/%PAM-1.0/a\auth required pam_tally2.so deny=3 unlock_time=150 even_deny_root root_unlock_time=300' /etc/pam.d/sshd
    fi

    echo "已设置密码登录次数限制，如果输入错误密码超过3次，则锁定账户！！"
}

# 设置历史命令保存条数和账户自动注销时间
set_history_and_timeout() {
    read -p "设置历史命令保存条数：" E
    read -p "设置账户自动注销时间：" F

    sed -i '/^HISTSIZE/c\HISTSIZE='$E'' /etc/profile
    sed -i '/^HISTSIZE/a\TMOUT='$F'' /etc/profile

    echo "已设置历史命令保存条数和账户自动注销时间。"
}

# 禁止直接使用 root，只有 wheel 组的用户可以使用 su 权限
disable_root_login() {
    sed -i '/PermitRootLogin/c\PermitRootLogin no'  /etc/ssh/sshd_config
    sed -i '/pam_wheel.so use_uid/c\auth required pam_wheel.so use_uid ' /etc/pam.d/su

    n=$(grep -c "SU_WHEEL_ONLY" /etc/login.defs)

    if [ $n -eq 0 ]; then
        echo SU_WHEEL_ONLY yes >> /etc/login.defs
    fi

    echo "已禁止 root 用户远程登录，只允许 wheel 组的用户使用 su 命令切换到 root 用户！"
}

# Linux 账号管理
account_management() {
    echo "即将对系统中的账户进行检查...."
    echo "系统中有登录权限的用户有："
    awk -F: '($7=="/bin/bash" && $1!="root"){print $1}' /etc/passwd
    echo "********************************************"
    echo "系统中 UID=0 的用户有："
    awk -F: '($3=="0"){print $1}' /etc/passwd
    echo "********************************************"

    N=$(awk -F: '($2==""){print $1}' /etc/shadow | wc -l)
    echo "系统中空密码用户有：$N"

    if [ $N -eq 0 ]; then
        echo "恭喜你，系统中无空密码用户！！"
        echo "********************************************"
    else
        i=1
        while [ $N -gt 0 ]; do
            None=$(awk -F: '($2==""){print $1}' /etc/shadow | awk
            'NR=='$i'{print}')
            echo "------------------------"
            echo $None
            echo "必须为空用户设置密码！！"
            passwd $None
            let N--
        done

        M=$(awk -F: '($2==""){print $1}' /etc/shadow | wc -l)
    
        if [ $M -eq 0 ]; then
            echo "恭喜，系统中已经没有空密码用户了！"
        else
            echo "系统中还存在空密码用户：$M"
        fi
    fi
}

# 对重要文件进行锁定
lock_critical_files() {
    read -p "警告：此脚本运行后将无法添加删除用户和组！！确定输入Y，取消输入N；Y/N：" i

    case $i in
        [Y,y])
            chattr +i /etc/passwd
            chattr +i /etc/shadow
            chattr +i /etc/group
            chattr +i /etc/gshadow
            echo "锁定成功！"
            ;;
        [N,n])
            chattr -i /etc/passwd
            chattr -i /etc/shadow
            chattr -i /etc/group
            chattr -i /etc/gshadow
            echo "取消锁定成功！！"
            ;;
        *)
            echo "请输入Y/y or N/n"
            ;;
    esac
}

# 主菜单
main_menu() {
    echo "1. 设置密码策略"
    echo "2. 设置密码强度"
    echo "3. 设置密码登录次数限制"
    echo "4. 设置历史命令保存条数和账户自动注销时间"
    echo "5. 禁止直接使用 root，只有 wheel 组的用户可以使用 su 权限"
    echo "6. Linux 账号管理"
    echo "7. 对重要文件进行锁定"
    echo "8. 退出"
}

# 主程序
while true; do
    main_menu
    read -p "请输入选项（1-8）：" choice

    case $choice in
        1)
            set_password_policy
            ;;
        2)
            set_password_strength
            ;;
        3)
            set_password_login_limit
            ;;
        4)
            set_history_and_timeout
            ;;
        5)
            disable_root_login
            ;;
        6)
            account_management
            ;;
        7)
            lock_critical_files
            ;;
        8)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入"
            ;;
    esac
done
