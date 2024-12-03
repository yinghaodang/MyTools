# 更新SSHD服务

更新sshd服务，我遇到过sshd版本太低导致无法登录的情况。（和网络配置相关）
本仓库适用于CentOS 7.

# 使用方法

1. 解压
2. ./configure 进行配置，需要安装缺少的依赖项
3. make install
4. 替换systemd相关文件

# xinted

为了保持服务器不断连，使用telnet作为连接服务器的后手，xinted相关的两个脚本分别是启动和关闭。
