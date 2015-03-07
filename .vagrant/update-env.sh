#!/bin/bash

echo '
xdebug.remote_enable = On
xdebug.remote_connect_back = On' >> /etc/php.d/xdebug.ini.disabled

mv -f /etc/php.d/xdebug.ini.disabled /etc/php.d/xdebug.ini

echo -e "\e[1;32mRestarting apache service\e[0m"
service httpd restart