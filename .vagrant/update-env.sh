#!/bin/bash

yum install -y php-opcache
yum install -y php-apc

yum remove -y php-pdo
yum install -y php-pdo

echo '
xdebug.remote_enable = On
xdebug.remote_connect_back = On' >> /etc/php.d/xdebug.ini.disabled

mv -f /etc/php.d/xdebug.ini.disabled /etc/php.d/xdebug.ini

echo -e "\e[1;32mRestarting apache service\e[0m"
service httpd restart

mkdir -p /tmp/php_sessions/www
mkdir -p /tmp/php_upload/www

chown -R bitrix:bitrix /tmp/php_sessions
chown -R bitrix:bitrix /tmp/php_upload

echo '
EnableSendfile Off
' >> /etc/httpd/bx/custom/z_bx_custom.conf 

echo '
sendfile off;
' >> /etc/nginx/bx/conf/bitrix_general.conf
