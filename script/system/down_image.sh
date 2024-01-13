#!/bin/bash
######################################################
#                                                    #
#       下载公网镜像传输到本地，根据实际需求更改地址     #
#                                                    #
######################################################
# 公网Harbor仓库地址
PUBLIC_HARBOR_REGISTRY="public-harbor.com"
# 本地Harbor仓库地址
LOCAL_HARBOR_REGISTRY="local-harbor.com"  # 修正为实际的本地Harbor仓库地址
# 保存镜像名称和标签的文件
IMAGE_LIST_FILE="image_list.txt"
# 仓库登录用户
DOCKER_USER = "admin"
# admin用户登录密码
DOCKER_PASSWD = "admin"

# 登录到本地Harbor仓库
docker login $LOCAL_HARBOR_REGISTRY -u $DOCKER_USER -p $DOCKER_PASSWD || { echo "Failed to login to local Harbor registry"; exit 1; }

# 读取镜像列表文件并拉取镜像
while IFS=: read -r image_name image_tag; do
  # 拉取镜像
  docker pull $PUBLIC_HARBOR_REGISTRY/$image_name:$image_tag || { echo "Failed to pull image: $image_name:$image_tag"; exit 1; }

  # 重新标记镜像以适应本地Harbor仓库地址
  docker tag $PUBLIC_HARBOR_REGISTRY/$image_name:$image_tag $LOCAL_HARBOR_REGISTRY/$image_name:$image_tag || { echo "Failed to tag image: $image_name:$image_tag"; exit 1; }

  # 推送镜像到本地Harbor仓库
  docker push $LOCAL_HARBOR_REGISTRY/$image_name:$image_tag || { echo "Failed to push image: $LOCAL_HARBOR_REGISTRY/$image_name:$image_tag"; exit 1; }

  # 清理：可选步骤，删除本地的镜像副本
  docker rmi $PUBLIC_HARBOR_REGISTRY/$image_name:$image_tag
  docker rmi $LOCAL_HARBOR_REGISTRY/$image_name:$image_tag
done < "$IMAGE_LIST_FILE"

# 退出登录
docker logout $LOCAL_HARBOR_REGISTRY
