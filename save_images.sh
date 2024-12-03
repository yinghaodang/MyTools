#!/bin/bash

# 检查是否已存在名为 images 的文件夹
if [ ! -d "images" ]; then
  # 如果不存在，则创建它
  mkdir images
  echo "Directory 'images' created."
else
  # 如果已经存在，输出提示信息
  echo "Directory 'images' already exists, skipping creation."
fi

# 获取包含rancher的镜像列表并转化为数组
images=( $(docker images | grep ^rancher | awk '{print $1":"$2}') )

# 遍历镜像列表并保存为tar包
for image in "${images[@]}"; do
    filename=$(echo "$image" | tr '/:' '_')  # 将镜像名称中的 / 和 : 替换为 _
    docker save "$image" -o "images/${filename}.tar"
    echo "Saved $image as ${filename}.tar"
done
