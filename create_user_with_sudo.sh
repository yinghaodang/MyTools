#!/bin/bash

# 询问用户名
read -p "请输入用户名: " username

# 询问密码
read -sp "请输入密码: " password
echo

# 添加用户，并创建家目录
useradd -m -s /bin/bash $username

# 非交互式设置用户密码
echo "${username}:${password}" | chpasswd

# 将用户添加到sudo组
usermod -aG sudo $username
