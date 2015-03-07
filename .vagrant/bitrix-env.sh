#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[1;31mThis script must be run as root or it will fail\e[0m" 1>&2
   exit 1
fi

echo -e "\e[1;32mBitrix Environment for Linux installation script\e[0m" 1>&2
echo ""
echo -e "\e[1;32mYes will be assumed to answers, and will be defaulted. 'n' or 'no' will result in a No answer, anything else will be a yes.\e[0m"
echo ""
echo -e "\e[1;31mThis script MUST be run as root or it will fail\e[0m"
echo "---"

# Check if the OS matches Fedora 14-16 or CentOS/RHEL 5.* or CentOS/RHEL 6.*
OS=$(cat /etc/redhat-release | awk {'print $1}')
VER=$(cat /etc/redhat-release | awk {'print $3}')
is_x86_64=$(uname -p | grep -wc 'x86_64')
repo_file=/etc/yum.repos.d/bitrix.repo
PHP54=1


# test OS name and version
## Red-Hat tests
if [[ "$OS" = "Red" ]]; then
	OS="CentOS"
	VER=$(cat /etc/redhat-release | awk {'print $7}')

## Centos and others
else

  # CentOS release 5.7 (Final); some old case?
	if [[ ( "$OS" = "CentOS" ) && ( "$VER" = "release" )  ]]; then 
    VER=`cat /etc/redhat-release | awk {'print $4}'` 
  fi

fi
# create variable with major release number 
rel=$(echo "$VER" | awk -F'.' '{print $1}')


# test OS and version
if [ "$OS" = "CentOS" ] && [[ "$VER" == "5."* || "$VER" == "6."* ]] || [[ "$OS" -eq "Fedora" && "$VER" -ge "15" && "$VER" -le "16" ]] ; then
	echo -e "\e[1;32m$OS $VER - OS and version are correct.\e[0m" 1>&2
else
	echo -e "\e[1;31mSystem runs on something other than Fedora 15-16 or CentOS 5.* or CentOS 6.*. This may not work!\e[0m";
	echo -e "\e[1;31mContinue Anyway? (y/n)\e[0m"
	read cont
  if [ "$cont" = "n" ] || [ "$cont" = "no" ]; then
    echo "Exiting..."
    exit 1
  fi
fi

# test yum package
rpm -qi yum 1>/dev/null 2>&1
if [[ $? -gt 0 ]]; then
  echo "yum package required but not installed, exiting"
  exit 1
fi

# epel links
if [[ $is_x86_64 -gt 0 ]]; then
  EPEL_LINK="http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"
  [[ $rel -eq 5 ]] && \
   EPEL_LINK="http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm"
else
  EPEL_LINK="http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
  [[ $rel -eq 5 ]] && \
   EPEL_LINK="http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm"
fi

# move old repo file
if [[ -f $repo_file ]]; then
  mv -f $repo_file ${repo_file}.bak
fi

# create repository config
if [[ "$OS" = "CentOS" ]]; then
  
  # configure Bitrix repository

  echo "
[bitrix]
name=\$OS \$releasever - \$basearch
failovermethod=priority
baseurl=http://repos.1c-bitrix.ru/yum/el/$rel/\$basearch
enabled=1
gpgcheck=0
" > $repo_file

  if [[ $rel -eq 6 ]]; then
    rpm --import http://repos.1c-bitrix.ru/yum/RPM-GPG-KEY-BitrixEnv ;

    echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-BitrixEnv" >> $repo_file
    sed -i 's/gpgcheck=0/gpgcheck=1/' $repo_file
  fi


  # configure Epel repository
  rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
  rpm -Uvh $EPEL_LINK

  yum clean all
  yum install -y yum-fastestmirror
	echo -e "\e[1;31mWhich version you want to install? (4|5)\e[0m"
	version_c=5
  if [[ ( $version_c != 4 ) && ( $version_c != 5 ) ]]; then
    echo "Incorrect version number=$version_c"
    exit 1
  fi

  [[ $version_c == 4 ]] && yum -y install bitrix-env4
  if [[ $version_c == 5 ]]; then 
    yum clean all
    if [[ $PHP54 -gt 0 ]]; then
    	# enable remi repository
    	rpm --import http://rpms.famillecollet.com/RPM-GPG-KEY-remi
    	rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
    	sed -i "0,/php55/s/enabled=0/enabled=1/" /etc/yum.repos.d/remi.repo;
	
	    # install additional packages (in other way installed samba4..)
	    yum -y install samba samba-winbind samba-common samba-client samba-winbind-clients

      # install php 5.4
      yum -y install php php-mysql php-pecl-apcu php-pecl-zendopcache

      # install bitrix-env
      yum -y install bitrix-env

    else
	    yum -y install samba samba-winbind samba-common samba-client samba-winbind-clients
	    yum -y install bitrix-env
    fi

    # create opcache package
    if [[ $PHP54 -gt 0 ]]; then
      if [[ $is_x86_64 -eq 1 ]]; then
        echo 'zend_extension=/usr/lib64/php/modules/opcache.so
opcache.enable=1
opcache.memory_consumption=124M
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.max_wasted_percentage=5
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.fast_shutdown=1
opcache.blacklist_filename=/etc/php.d/opcache*.blacklist' > /etc/php.d/opcache.ini
      else
        echo 'zend_extension=/usr/lib/php/modules/opcache.so
opcache.enable=1
opcache.memory_consumption=124M
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.max_wasted_percentage=5
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.fast_shutdown=1
opcache.blacklist_filename=/etc/php.d/opcache*.blacklist' > /etc/php.d/opcache.ini
      fi
    fi
  fi

  echo -e "\e[1;32mBitrix Environment for Linux installation complete\e[0m"

  sed -i 's/~\/menu.sh/#~\/menu.sh/' /root/.bash_profile

  exit 0

else

  echo "
[bitrix]
name=\$OS \$releasever - \$basearch
failovermethod=priority
baseurl=http://repos.1c-bitrix.ru/yum/fedora/base/\$releasever/\$basearch
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-BitrixEnv
" > /etc/yum.repos.d/bitrix.repo

  rpm --import http://repos.1c-bitrix.ru/yum/RPM-GPG-KEY-BitrixEnv

  yum clean all
  yum install -y yum-fastestmirror
  yum -y install bitrix-env4.noarch

  echo -e "\e[1;32mBitrix Environment for Linux installation complete\e[0m"

  sed -i 's/~\/menu.sh/#~\/menu.sh/' /root/.bash_profile

  exit 0
fi

