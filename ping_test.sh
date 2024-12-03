#!/bin/bash

# 目标 IP 列表
servers=(
    "1.2.3.4"
    "5.6.7.8"
)

# 测试本地服务器连接
echo "Testing connections from $(hostname) to target servers..."
for server in "${servers[@]}"; do
    ping -c 4 -W 5 "$server" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "$server is reachable."
    else
        echo "$server is not reachable."
    fi
done

