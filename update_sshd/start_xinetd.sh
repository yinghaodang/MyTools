yum install telnet* xinetd -y

systemctl start xinetd

systemctl start telnet.socket

sed -i 's/^auth[[:space:]]\+required[[:space:]]\+pam_securetty.so/#&/' /etc/pam.d/remote
