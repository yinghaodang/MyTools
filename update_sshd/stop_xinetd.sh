sed -i 's/^#auth[[:space:]]\+required[[:space:]]\+pam_securetty.so/auth       required     pam_securetty.so/' /etc/pam.d/remote

systemctl stop telnet.socket

systemctl stop xinetd
