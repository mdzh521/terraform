#!/bin/bash

#获取磁盘列表
disk=$(lsblk | grep disk | grep -v "^fd" | aws '{print $1}')

#检查是否存在挂在卷
if [ -d "/data" ]; then
	echo "数据目录已存在"
else 
	mkdir /data
fi

# 处理磁盘并添加到挂在卷
for disk in $disks; do
	parts=$(lsblk -d /dev/$disk | wc -l)
  if [ $parts -eq 1 ]; then
    pvcreate /dev/$disk
    vgextend datavg /dev/$disk
  fi 
done

# 创建逻辑卷
lvcreate -n datalv -l 100%FREE datavg

# 格式化逻辑卷
mkfs.ext4 /dev/datavg/datalv

# 添加/etc/fstab
echo "/dev/datavg/datalv /data ext4 defaults 0 0" >> /etc/fstab

mount -a
