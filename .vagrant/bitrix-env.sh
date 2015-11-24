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
OS=$(cat /etc/redhat-release | awk '{print $1}')
VER=$(cat /etc/redhat-release | awk '{print $3}')
is_x86_64=$(uname -p | grep -wc 'x86_64')
repo_file=/etc/yum.repos.d/bitrix.repo
PHP54=0
PHP56=1
PHP_MODULES="xdebug curl dom mssql pdo phar posix sqlite3 sybase_ct sysvmsg
 sysvsem sysvshm xmlwriter xsl mysqli pdo_dblib pdo_mysql pdo_sqlite wddx xmlreader xhprof"

[[ -z $TEST_REPOSITORY ]] && TEST_REPOSITORY=0
LOG=$(mktemp /tmp/bitrix-env-XXXXX.log)

print(){
    msg=$1
    notice=${2:-0}
    [[ $notice -eq 1 ]] && echo -e "${msg}"
    [[ $notice -eq 2 ]] && echo -e "\e[1;31m${msg}\e[0m"
    echo "$(date +"%FT%H:%M:%S"): $$ : $msg" >> $LOG
}

print_e(){
    msg_e=$1
    print "$msg_e" 2
    print "Installation logfile - $LOG" 1
    exit 1
}

configure_epel(){

    # epel links
    print "Start configuration EPEL repository. Please wait." 1
    if [[ $is_x86_64 -gt 0 ]]; then
        EPEL_LINK="http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"
        [[ $rel -eq 5 ]] && \
            EPEL_LINK="http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm"
    else
        EPEL_LINK="http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
        [[ $rel -eq 5 ]] && \
            EPEL_LINK="http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm"
    fi
    EPEL_KEY=http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
    
    test_epel=$(rpm -qa | grep -c 'epel-release')
    if [[ $test_epel -eq 0 ]]; then
        rpm --import $EPEL_KEY >>$LOG 2>&1 || print_e "Cannot import gpg key: $EPEL_KEY"
        rpm -Uvh $EPEL_LINK >>$LOG 2>&1 || print_e "Cannot install epel rpm from $EPEL_LINK"
    fi

    yum clean all >/dev/null 2>&1 
    yum install -y yum-fastestmirror >/dev/null 2>&1

    print "epel=$EPEL_LINK configured" 1
}

configure_remi(){
    REMI_LINK=http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
    REMI_KEY=http://rpms.famillecollet.com/RPM-GPG-KEY-remi
    print "Start configuration REMI repository. Please wait." 1
    test_remi=$(rpm -qa | grep -c 'remi-release')

    if [[ $test_remi -eq 0 ]]; then
        rpm --import $REMI_KEY >>$LOG 2>&1 || print_e "Cannot import gpg key: $REMI_KEY"
        rpm -Uvh $REMI_LINK >>$LOG 2>&1 || print_e "Cannot install remi rpm from $REMI_LINK"
    fi
    
    if [[ $PHP54 -eq 1 ]]; then
        sed -i -e '/\[remi\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
        sed -i "0,/php55/s/enabled=0/enabled=1/" /etc/yum.repos.d/remi.repo
    elif [[ $PHP56 -eq 1 ]]; then
        sed -i -e '/\[remi\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
        sed -i -e '/\[remi-php56\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
    fi
        print "remi=$REMI_LINK configured" 1
}

configure_bitrix(){
    print "Start configuration Bitrix repository. Please wait." 1
    # move old repo file
    [[ -f $repo_file ]] && mv -f $repo_file ${repo_file}.bak
    BITRIX_KEY=http://repos.1c-bitrix.ru/yum/RPM-GPG-KEY-BitrixEnv

    REPO=yum
    [[ $TEST_REPOSITORY -gt 0 ]] && REPO=yum-testing

    echo "
[bitrix]
name=\$OS \$releasever - \$basearch
failovermethod=priority
baseurl=http://repos.1c-bitrix.ru/$REPO/el/$rel/\$basearch
enabled=1
gpgcheck=0
" > $repo_file

  if [[ $rel -eq 6 ]]; then
    rpm --import $BITRIX_KEY >>$LOG 2>&1 || print_e "Cannot import gpg key: $BITRIX_KEY"
    echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-BitrixEnv" >> $repo_file
    sed -i 's/gpgcheck=0/gpgcheck=1/' $repo_file
  fi
  print "Bitrix repository is configured" 1
}


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
if [[ "$OS" = "CentOS" ]] && \
     [[ "$VER" == "5."* || "$VER" == "6."* ]] || \
     [[ "$OS" -eq "Fedora" && "$VER" -ge "15" && "$VER" -le "16" ]] ; then
	print "OS=$OS Ver=$VER - is supported."
else
    print "OS=$OS Ver=$VER - is not supported. This may not work!" 2
    read -p "Continue Anyway? (N|y): " answer
    [[ $(echo "$answers" | grep -ic "^\(y\|yes\)$") -eq 0 ]] && print_e "Exiting.." 
fi
print "Update system. Please wait" 1
yum -y update >>$LOG 2>&1 || \
 print_e "Error while update system"

# test yum package
rpm -qi yum 1>/dev/null 2>&1
[[ $? -gt 0 ]] && print_e "yum package required but not installed, exiting"

# create repository config
if [[ "$OS" = "CentOS" ]]; then
  
    # configure Bitrix repository
    configure_bitrix

    # configure EPEL
    configure_epel

    # version number - Centos5 => 4, Centos 6 => 5
    version_c=4
    [[ $rel -eq 6 ]] && version_c=5

    if [[ $version_c -eq 4 ]]; then
        print "Installation bitrix-env4. Please wait."
        yum -y install bitrix-env4 >>$LOG 2>&1
    else
        if [[ ( $PHP54 -gt 0 ) || ( $PHP56 -gt 0 ) ]]; then
            configure_remi 
            
            # update    
            print "Update system. Please wait" 1
            yum clean all >/dev/null 2>&1
            yum -y update >>$LOG 2>&1 || \
                print_e "Error while update system"

            # install additional php packages
            print "Installation php packages. Please wait." 1 
            yum -y install php php-mysql \
                php-pecl-apcu php-pecl-zendopcache >>$LOG 2>&1 || \
                print_e "Error while php installed"

        fi
           
        # install additional packages (in other way installed samba4..)
        print "Installation additional samba packages. Please wait." 1
        yum -y install samba samba-winbind samba-common \
            samba-client samba-winbind-clients >>$LOG 2>&1 || \
            print_e "Error while samba installed"

        print "Installation bitrix-env package and dependencies" 1
        yum -y install bitrix-env >>$LOG 2>&1 || \
            print_e "Error while bitrix-env installed"
    fi

    print "Bitrix Environment for Linux installation complete" 1

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


fi

sed -i 's/~\/menu.sh/#~\/menu.sh/' /root/.bash_profile
exit 0