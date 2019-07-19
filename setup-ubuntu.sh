#!/bin/bash

#
# Aggiorno il sistema
#
apt-get -y update
apt-get -y upgrade

#dpkg-reconfigure tzdata
#dpkg-reconfigure locales

#
# Metto in sicurezza la memoria condivisa
#
if [ -n "$(grep -in tmpfs /etc/fstab)" ]; then
    echo "tmpfs already exists."
else
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
    echo "tmpfs: ok"
fi

#
# Creo la swap
#
if [ -n "$(swapon --show)" ]; then
    echo "Swap already exists."
else
    echo "Setup Swap, please wait..."
    
    fallocate -l 1G /swap
    dd if=/dev/zero of=/swap bs=1024 count=1048576
    chmod 600 /swap
    mkswap /swap
    swapon /swap

    if [ -n "$(swapon --show)" ]; then
        echo "/swap swap swap defaults 0 0" >> /etc/fstab
        echo "OK!"
    else
        echo "FAILED!"
        exit
    fi
fi

#
# Add user
#
useradd -G users,sudo -m --password secret llongo

#
# fail2ban install
#
apt install fail2ban
echo "[sshd]" >> /etc/fail2ban/jail.local
echo "enabled = true" >> /etc/fail2ban/jail.local
echo "port = 22" >> /etc/fail2ban/jail.local
echo "filter = sshd" >> /etc/fail2ban/jail.local
echo "logpath = /var/log/auth.log" >> /etc/fail2ban/jail.local
echo "maxretry = 3" >> /etc/fail2ban/jail.local
systemctl restart fail2ban

#
# Secure SSHD configuration
#
sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/\#UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
sed -i 's/\#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

#
# Allow SSH login using SSH key
#
mv /root/.ssh /home/llongo/
chown -R llongo: /home/llongo

#reboot