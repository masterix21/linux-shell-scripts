#!/bin/bash

apt update -y
apt upgrade -y

read -p "Hostname: " hostname
hostnamectl set-hostname $hostname

apt install -y tasksel
tasksel install lamp-server

#
# Setup MySQL
#
read -sp "MySQL Root Password: " mysql_root_pwd
read -sp "MySQL Froxlor Password: " mysql_froxlor_pwd
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_root_pwd';" > /tmp/setup_froxlor.sql
echo "CREATE DATABASE froxlor;" >> /tmp/setup_froxlor.sql
echo "CREATE USER 'froxlor'@'localhost' IDENTIFIED BY '$mysql_froxlor_pwd';" >> /tmp/setup_froxlor.sql
echo "GRANT ALL PRIVILEGES ON froxlor.* TO 'froxlor'@'localhost' IDENTIFIED BY '$mysql_froxlor_pwd' WITH GRANT OPTION;" >> /tmp/setup_froxlor.sql
echo "FLUSH PRIVILEGES;" >> /tmp/setup_froxlor.sql
mysql -u root < /tmp/setup_froxlor.sql
rm -f /tmp/setup_froxlor.sql

#
# Install PHP
#
apt install -y php7.2-fpm php7.2-xml php7.2-posix php7.2-mbstring php7.2-curl php7.2-bcmath php7.2-zip php7.2-json php7.2-cli php7.2-gd php7.2-zip php7.2-mysql php7.2-opcache php7.2-bz2
systemctl restart apache2

#
# Download Froxlor
#
cd /var/www/html
wget https://files.froxlor.org/releases/froxlor-latest.tar.gz
tar -zxvf froxlor-latest.tar.gz
mv froxlor/* /var/www/html
rm -rf froxlor froxlor-latest.tar.gz index.html
mkdir -p /etc/apache2/sites-enabled/
mkdir -p /var/customers/webs/
mkdir -p /var/customers/logs/
mkdir -p /var/lib/apache2/fastcgi/
mkdir -p /var/customers/tmp/
chown -R www-data:www-data /var/www/html
chown root:0 /etc/apache2/sites-enabled/
chmod 0600 /etc/apache2/sites-enabled/
chmod 1777 /var/customers/tmp
addgroup --gid 9999 froxlorlocal
adduser --no-create-home --uid 9999 --ingroup froxlorlocal --shell /bin/false --disabled-password --gecos '' froxlorlocal

#
# Setup libnss-extrausers
#
apt install -y nscd libnss-extrausers
mkdir -p /var/lib/extrausers
touch /var/lib/extrausers/passwd
touch /var/lib/extrausers/group
touch /var/lib/extrausers/shadow
mv "/etc/nsswitch.conf" "/etc/nsswitch.conf.frx.bak"
echo "passwd:         compat extrausers" > /etc/nsswitch.conf
echo "group:          compat extrausers" >> /etc/nsswitch.conf
echo "shadow:         compat extrausers" >> /etc/nsswitch.conf
echo "hosts:       files dns" >> /etc/nsswitch.conf
echo "networks:    files dns" >> /etc/nsswitch.conf
echo "services:    db files" >> /etc/nsswitch.conf
echo "protocols:   db files" >> /etc/nsswitch.conf
echo "rpc:         db files" >> /etc/nsswitch.conf
echo "ethers:      db files" >> /etc/nsswitch.conf
echo "netmasks:    files" >> /etc/nsswitch.conf
echo "netgroup:    files" >> /etc/nsswitch.conf
echo "bootparams:  files" >> /etc/nsswitch.conf
echo "automount:   files" >> /etc/nsswitch.conf
echo "aliases:     files" >> /etc/nsswitch.conf
/etc/init.d/nscd restart
nscd --invalidate=group

#
# Setup PureFTPd
#
apt install -y pure-ftpd-common pure-ftpd-mysql
echo "1000" > /etc/pure-ftpd/conf/MinUID
echo "/etc/pure-ftpd/db/mysql.conf" > /etc/pure-ftpd/conf/MySQLConfigFile
echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
echo "15" > /etc/pure-ftpd/conf/MaxIdleTime
echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
echo "no" > /etc/pure-ftpd/conf/PAMAuthentication
chmod 0644 /etc/pure-ftpd/conf/MinUID /etc/pure-ftpd/conf/MySQLConfigFile /etc/pure-ftpd/conf/NoAnonymous /etc/pure-ftpd/conf/MaxIdleTime /etc/pure-ftpd/conf/ChrootEveryone /etc/pure-ftpd/conf/PAMAuthentication
chown root:0 /etc/pure-ftpd/conf/MinUID /etc/pure-ftpd/conf/MySQLConfigFile /etc/pure-ftpd/conf/NoAnonymous /etc/pure-ftpd/conf/MaxIdleTime /etc/pure-ftpd/conf/ChrootEveryone /etc/pure-ftpd/conf/PAMAuthentication
mv "/etc/pure-ftpd/db/mysql.conf" "/etc/pure-ftpd/db/mysql.conf.frx.bak"
echo "MYSQLServer       127.0.0.1" > /etc/pure-ftpd/db/mysql.conf
echo "MYSQLPort         3306" >> /etc/pure-ftpd/db/mysql.conf
echo "MYSQLSocket       /var/run/mysqld/mysqld.sock" >> /etc/pure-ftpd/db/mysql.conf
echo "MYSQLUser         froxlor" >> /etc/pure-ftpd/db/mysql.conf
echo "MYSQLPassword     $mysql_froxlor_pwd" >> /etc/pure-ftpd/db/mysql.conf
echo "MYSQLDatabase     froxlor" >> /etc/pure-ftpd/db/mysql.conf
echo "MYSQLCrypt        any" >> /etc/pure-ftpd/db/mysql.conf
echo 'MYSQLGetPW        SELECT password FROM ftp_users WHERE username="\L" AND login_enabled="y"' >> /etc/pure-ftpd/db/mysql.conf
echo 'MYSQLGetUID       SELECT uid FROM ftp_users WHERE username="\L" AND login_enabled="y"' >> /etc/pure-ftpd/db/mysql.conf
echo 'MYSQLGetGID       SELECT gid FROM ftp_users WHERE username="\L" AND login_enabled="y"' >> /etc/pure-ftpd/db/mysql.conf
echo 'MYSQLGetDir       SELECT homedir FROM ftp_users WHERE username="\L" AND login_enabled="y"' >> /etc/pure-ftpd/db/mysql.conf
echo 'MySQLGetQTASZ     SELECT panel_customers.diskspace/1024 AS QuotaSize FROM panel_customers, ftp_users WHERE username = "\L" AND panel_customers.loginname = SUBSTRING_INDEX('\L', 'ftp', 1)' >> /etc/pure-ftpd/db/mysql.conf
chmod 0644 "/etc/pure-ftpd/db/mysql.conf"
chown root:0 "/etc/pure-ftpd/db/mysql.conf"

echo "1" > /etc/pure-ftpd/conf/CustomerProof
echo "21" > /etc/pure-ftpd/conf/Bind
mv "/etc/default/pure-ftpd-common" "/etc/default/pure-ftpd-common.frx.bak"
echo "STANDALONE_OR_INETD=standalone" > /etc/default/pure-ftpd-common
echo "VIRTUALCHROOT=false" >> /etc/default/pure-ftpd-common
echo "UPLOADSCRIPT=" >> /etc/default/pure-ftpd-common
echo "UPLOADUID=" >> /etc/default/pure-ftpd-common
echo "UPLOADGID=" >> /etc/default/pure-ftpd-common
chmod 0644 "/etc/default/pure-ftpd-common"
chown root:0 "/etc/default/pure-ftpd-common"
/etc/init.d/pure-ftpd-mysql restart

#
# Setup Logrotation
#
apt install -y logrotate
echo "/var/customers/logs/*.log {" > /etc/logrotate.d/froxlor
echo "  missingok" >> /etc/logrotate.d/froxlor
echo "  weekly" >> /etc/logrotate.d/froxlor
echo "  rotate 4" >> /etc/logrotate.d/froxlor
echo "  compress" >> /etc/logrotate.d/froxlor
echo "  delaycompress" >> /etc/logrotate.d/froxlor
echo "  notifempty" >> /etc/logrotate.d/froxlor
echo "  create" >> /etc/logrotate.d/froxlor
echo "  sharedscripts" >> /etc/logrotate.d/froxlor
echo "  ostrotate" >> /etc/logrotate.d/froxlor
echo "  /etc/init.d/apache2 reload > /dev/null 2>&1 || true" >> /etc/logrotate.d/froxlor
echo "  endscript" >> /etc/logrotate.d/froxlor
echo "}" >> /etc/logrotate.d/froxlor

#
# Setup PHP-FPM
#
apt install -y apache2-suexec-pristine libapache2-mod-fastcgi
a2dismod userdir php7.2 mpm_prefork
a2enmod access_compat actions alias auth_basic authn_core authn_file authz_core authz_host authz_user autoindex deflate dir env fastcgi fcgid filter headers http2 mime mpm_event negotiation proxy proxy_fcgi proxy_http reqtimeout rewrite setenvif socache_shmcb ssl status suexec
/etc/init.d/apache2 restart

echo "" >> /etc/php/7.2/fpm/php-fpm.conf
echo "[$hostname]" >> /etc/php/7.2/fpm/php-fpm.conf
echo "listen = /var/lib/apache2/fastcgi/1-froxlor.panel-$hostname-php-fpm.socket" >> /etc/php/7.2/fpm/php-fpm.conf
echo "listen.owner = www-data" >> /etc/php/7.2/fpm/php-fpm.conf
echo "listen.group = www-data" >> /etc/php/7.2/fpm/php-fpm.conf
echo "listen.mode = 0660" >> /etc/php/7.2/fpm/php-fpm.conf
echo "user = www-data" >> /etc/php/7.2/fpm/php-fpm.conf
echo "group = www-data" >> /etc/php/7.2/fpm/php-fpm.conf
echo "pm = static" >> /etc/php/7.2/fpm/php-fpm.conf
echo "pm.max_children = 1" >> /etc/php/7.2/fpm/php-fpm.conf
echo "pm.max_requests = 0" >> /etc/php/7.2/fpm/php-fpm.conf
echo "security.limit_extensions = .php" >> /etc/php/7.2/fpm/php-fpm.conf

#
# Setup Froxlor Cronjob
# 
echo "*/5 * * * *	root	/usr/bin/nice -n 5 /usr/bin/php -q /var/www/html/scripts/froxlor_master_cronjob.php" > /etc/cron.d/froxlor
chmod 0640 "/etc/cron.d/froxlor"
chown root:0 "/etc/cron.d/froxlor"
/etc/init.d/cron reload

#
# Setup Postfix to send through Sendgrid
#
debconf-set-selections <<< "postfix postfix/mailname string $hostname"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
apt install -y postfix
echo "$hostname" > /etc/mailname
echo "smtpd_banner = \$myhostname ESMTP \$mail_name" > /etc/postfix/main.cf
echo "biff = no" >> /etc/postfix/main.cf
echo "append_dot_mydomain = no" >> /etc/postfix/main.cf
echo "readme_directory = no" >> /etc/postfix/main.cf
echo "compatibility_level = 2" >> /etc/postfix/main.cf
echo "smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem" >> /etc/postfix/main.cf
echo "smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key" >> /etc/postfix/main.cf
echo "smtpd_use_tls=yes" >> /etc/postfix/main.cf
echo "smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache" >> /etc/postfix/main.cf
echo "smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache" >> /etc/postfix/main.cf
echo "smtp_sasl_auth_enable = yes" >> /etc/postfix/main.cf
echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" >> /etc/postfix/main.cf
echo "smtp_sasl_security_options = noanonymous" >> /etc/postfix/main.cf
echo "smtp_sasl_tls_security_options = noanonymous" >> /etc/postfix/main.cf
echo "smtp_tls_security_level = encrypt" >> /etc/postfix/main.cf
echo "smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination" >> /etc/postfix/main.cf
echo "myhostname = $hostname" >> /etc/postfix/main.cf
echo "alias_maps = hash:/etc/aliases" >> /etc/postfix/main.cf
echo "alias_database = hash:/etc/aliases" >> /etc/postfix/main.cf
echo "myorigin = /etc/mailname" >> /etc/postfix/main.cf
echo "mydestination = \$myhostname, $hostname, localhost" >> /etc/postfix/main.cf
echo "relayhost = [smtp.sendgrid.net]:587" >> /etc/postfix/main.cf
echo "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128" >> /etc/postfix/main.cf
echo "mailbox_size_limit = 0" >> /etc/postfix/main.cf
echo "recipient_delimiter = +" >> /etc/postfix/main.cf
echo "inet_interfaces = loopback-only" >> /etc/postfix/main.cf
echo "inet_protocols = all" >> /etc/postfix/main.cf
echo "message_size_limit = 0" >> /etc/postfix/main.cf
read -p "SendGrid API Key: " sendgrid_api_key
echo "[smtp.sendgrid.net]:587 apikey:$sendgrid_api_key" > /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
/etc/init.d/postfix restart

#
# Setup Apache SSL
#
mkdir -p /etc/apache2/ssl
cd /etc/apache2/ssl
openssl rand --writerand ~/.rnd &&
openssl genrsa -out /etc/apache2/ssl/apache.key 4096 &&
openssl req -nodes -new -key /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.csr &&
openssl x509 -req -days 365 -in /etc/apache2/ssl/apache.csr -signkey /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.pem
echo "Alias \"/.well-known/acme-challenge\" \"/var/www/.well-known/acme-challenge\"" > /etc/apache2/conf-enabled/acme.conf
echo "<Directory \"/var/www/.well-known/acme-challenge\">" >> /etc/apache2/conf-enabled/acme.conf
echo "Require all granted" >> /etc/apache2/conf-enabled/acme.conf
echo "</Directory>" >> /etc/apache2/conf-enabled/acme.conf
/etc/init.d/apache2 restart

#
# Setup PhpMyAdmin
#
apt install -y phpmyadmin

#
# Change configurations
#
# SQL @TODO: Update FPM from 7.0 to 7.2 (or right version used)
# SQL: update froxlor.panel_settings set value = 1 where varname = 'nssextrausers';