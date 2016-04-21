#!/bin/bash

# Public header
# =============================================================================================================================
# resolve links - $0 may be a symbolic link
PRG="$0"

while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done

# Get standard environment variables
PRGDIR=`dirname "$PRG"`


# echo color function
function cecho {
    # Usage:
    # cecho -red sometext     #Error, Failed
    # cecho -green sometext   # Success
    # cecho -yellow sometext  # Warning
    # cecho -blue sometext    # Debug
    # cecho -white sometext   # info
    # cecho -n                # new line
    # end

    while [ "$1" ]; do
        case "$1" in
            -normal)        color="\033[00m" ;;
# -black)         color="\033[30;01m" ;;
-red)           color="\033[31;01m" ;;
-green)         color="\033[32;01m" ;;
-yellow)        color="\033[33;01m" ;;
-blue)          color="\033[34;01m" ;;
# -magenta)       color="\033[35;01m" ;;
# -cyan)          color="\033[36;01m" ;;
-white)         color="\033[37;01m" ;;
-n)             one_line=1;   shift ; continue ;;
*)              echo -n "$1"; shift ; continue ;;
esac

shift
echo -en "$color"
echo -en "$1"
echo -en "\033[00m"
shift

done
if [ ! $one_line ]; then
        echo
fi
}
# end echo color function

# echo color function, smarter
function echo_r () {
    #Error, Failed
    [ $# -ne 1 ] && return 0
    echo -e "\033[31m$1\033[0m"
}
function echo_g () {
    # Success
    [ $# -ne 1 ] && return 0
    echo -e "\033[32m$1\033[0m"
}
function echo_y () {
    # Warning
    [ $# -ne 1 ] && return 0
    echo -e "\033[33m$1\033[0m"
}
function echo_b () {\
    # Debug
    [ $# -ne 1 ] && return 0
    echo -e "\033[34m$1\033[0m"
}
# end echo color function, smarter

WORKDIR=$PRGDIR
# end public header
# =============================================================================================================================

USER="`id -un`"
LOGNAME=$USER
if [ $UID -ne 0 ]; then
    echo "WARNING: Running as a non-root user, \"$LOGNAME\". Functionality may be unavailable. Only root can use some commands or options"
fi

# Name: replaceLocalHostsFileAgainstGfw.sh
# Refer to: https://github.com/racaljk/hosts
# Backups: https://coding.net/u/scaffrey/p/hosts/git

# define user friendly messages
header="
Function: Execute this shell script to access Google, etc easily.

Open source software Written by Guodong Ding <dgdenterprise@gmail.com>.
Blog: http://dgd2010.blog.51cto.com/
Github: https://github.com/DingGuodong
Last updated: 2016-4-19
"

check_network_connectivity(){
    echo_b "checking network connectivity ... "
    network_address_to_check=8.8.4.4
    stable_network_address_to_check=114.114.114.114
    ping_count=2
    ping -c $ping_count $network_address_to_check >/dev/null
    retval=$?
    if [ $retval -ne 0 ] ; then
        if ping -c $ping_count $stable_network_address_to_check >/dev/null;then
            echo_g "Network to $stable_network_address_to_check succeed! "
            echo_y "Note: network to $network_address_to_check failed! "
        elif ! ip route | grep default >/dev/null; then
            echo_r "Network is unreachable, gateway is not set."
            exit 1
        elif ! ping -c2 $(ip route | awk '/default/ {print $3}') >/dev/null; then
            echo_r "Network is unreachable, gateway is unreachable."
            exit 1
        else
            echo_r "Network is blocked! "
            exit 1
        fi
    elif [ $retval -eq 0 ]; then
        echo_g "Check network connectivity passed! "
    fi
}

check_name_resolve(){
    echo_b "checking name resolve ... "
    target_name_to_resolve="github.com"
    stable_target_name_to_resolve="www.aliyun.com"
    ping_count=1
    if ! ping  -c$ping_count $target_name_to_resolve >/dev/null; then
        echo_y "Name lookup failed for $target_name_to_resolve with $ping_count times "
        if ping  -c$ping_count $stable_target_name_to_resolve >/dev/null; then
            echo_g "Name lookup success for $stable_target_name_to_resolve with $ping_count times "
        fi
        [ -f /etc/resolv.conf ] && cp /etc/resolv.conf /etc/resolv.conf$(date +%Y%m%d%H%M%S)~
        cat >/etc/resolv.conf<<eof
nameserver 8.8.4.4
nameserver 114.114.114.114
eof
    check_name_resolve
    else
        echo_g "Check name resolve passed! "
        return
    fi

}

command_exists() {
    # which "$@" >/dev/null 2>&1
    command -v "$@" >/dev/null 2>&1
}

check_command_can_be_execute(){
    command_exists
}

yum_install_packages(){
    echo_b "yum install $@ ..."
    yum -q -yy install $@
    retval=$?
    if [ $retval -ne 0 ] ; then
        echo_r "yum install $@ failed! "
        exit 1
    else
        echo_g "yum install $@ successfully! "
    fi
}

apt_get_install_packages(){
    echo_b "apt-get install $@ ..."
    apt-get -qq -y install $@
    retval=$?
    if [ $retval -ne 0 ] ; then
        echo_r "apt-get install $@ failed! "
        exit 1
    else
        echo_g "apt-get install $@ successfully! "
    fi
}

# Refer: https://get.docker.com/
#   'curl -sSL https://get.docker.com/ | sh'
# or:
#   'wget -qO- https://get.docker.com/ | sh'
#
# Check if this is a forked Linux distro
check_linux_distribution_forked() {

    # Check for lsb_release command existence, it usually exists in forked distros
    if command_exists lsb_release; then
        # Check if the `-u` option is supported
        set +e
        lsb_release -a -u > /dev/null 2>&1
        lsb_release_exit_code=$?
        set -e

        # Check if the command has exited successfully, it means we're in a forked distro
        if [ "$lsb_release_exit_code" = "0" ]; then
            # Print info about current distro
            cat <<-EOF
            You're using '$lsb_dist' version '$dist_version'.
EOF

            # Get the upstream release info
            lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[[:space:]]')
            dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[[:space:]]')

            # Print info about upstream distro
            cat <<-EOF
            Upstream release is '$lsb_dist' version '$dist_version'.
EOF
        else
            if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ]; then
                # We're Debian and don't even know it!
                lsb_dist=debian
                dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
                case "$dist_version" in
                    8|'Kali Linux 2')
                        dist_version="jessie"
                    ;;
                    7)
                        dist_version="wheezy"
                    ;;
                esac
            fi
        fi
    fi
}

check_linux_distribution(){
    # refer to /etc/issue and /etc/*-release maybe more better choice
    # perform some very rudimentary platform detection
    lsb_dist=''
    dist_version=''
    if command_exists lsb_release; then
        lsb_dist="$(lsb_release -si)"
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
            lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
        lsb_dist='debian'
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
        lsb_dist='fedora'
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/oracle-release ]; then
        lsb_dist='oracleserver'
        fi
    if [ -z "$lsb_dist" ]; then
        if [ -r /etc/centos-release ] || [ -r /etc/redhat-release ]; then
            lsb_dist='centos'
        fi
    fi
    if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi

    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

    case "$lsb_dist" in
        ubuntu)
            if command_exists lsb_release; then
                dist_version="$(lsb_release --codename | cut -f2)"
            fi
            if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
                dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
            fi
            ;;

        debian)
            dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
            case "$dist_version" in
                8)
                    dist_version="jessie"
                    ;;
                7)
                    dist_version="wheezy"
                    ;;
            esac
            ;;

        oracleserver)
            # need to switch lsb_dist to match yum repo URL
            lsb_dist="oraclelinux"
            dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
            ;;

        fedora|centos)
            dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
            ;;

        *)
            if command_exists lsb_release; then
                dist_version="$(lsb_release --codename | cut -f2)"
            fi
            if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
                dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
            fi
            ;;


    esac

    # Check if this is a forked Linux distro
    check_linux_distribution_forked

}
# end Refer above

# refer to LNMP, http://lnmp.org/download.html
function Get_OS_Bit(){
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
    else
        Is_64bit='n'
    fi
}

function Get_Dist_Name(){
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        PM='apt'
    else
        DISTRO='unknow'
    fi
    Get_OS_Bit
}

function Get_RHEL_Version(){
    Get_Dist_Name
    if [ "${DISTRO}" = "RHEL" ]; then
        if grep -Eqi "release 5." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 5"
            RHEL_Ver='5'
        elif grep -Eqi "release 6." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 6"
            RHEL_Ver='6'
        elif grep -Eqi "release 7." /etc/redhat-release; then
            echo "Current Version: RHEL Ver 7"
            RHEL_Ver='7'
        fi
    fi
}

function Get_ARM(){
    if uname -m | grep -Eqi "arm"; then
        Is_ARM='y'
    fi
}

Install_LSB()
{
    if [ "$PM" = "yum" ]; then
        yum -y install redhat-lsb
    elif [ "$PM" = "apt" ]; then
        apt-get update
        apt-get install -y lsb-release
    fi
}

Get_Dist_Version()
{
    Install_LSB
    eval ${DISTRO}_Version=`lsb_release -rs`
    eval echo "${DISTRO} \${${DISTRO}_Version}"
}
# end refer to http://lnmp.org/download.html

function get_hosts_file_from_backup_site(){
    echo_b "getting hosts file backup site ... "
    if ! grep github /etc/hosts >/dev/null; then
        cp /etc/hosts /etc/hosts$(date +%Y%m%d%H%M%S)~
    else
        # TODO
        # rm: cannot remove ‘/etc/hosts’: Device or resource busy
        # it occurs in docker when mount /etc/hosts to container as a volume
        rm -f /etc/hosts
        \cp -f hosts/hosts /etc/hosts
    fi
    wget -q https://coding.net/u/scaffrey/p/hosts/git/raw/master/hosts -O /etc/hosts
    if test $? -eq 0 -a -f /etc/hosts; then
        echo_g "set hosts file from backup site successfully! "
    else
        echo_r "set hosts file from backup site failed! "
    fi
}

function get_hosts_file_from_github(){
    echo_b "getting hosts file from GitHub ... "
    if [ ! -d hosts ]; then
        command_exists git && git clone https://github.com/racaljk/hosts.git >/dev/null 2>&1
        retval=$?
        if [ $retval -ne 0 ] ; then
            echo_r "git clone failed! "
            get_hosts_file_from_backup_site
            return
        else
            [ -s hosts/hosts ] && echo_g "git clone successfully! " || exit 1
        fi
    elif [ -d hosts/.git ]; then
        echo_y "Note: a existed git repo is found! Attempt to update it! "
        cd hosts
        command_exists git && git pull >/dev/null 2>&1
        retval=$?
        if [ $retval -ne 0 ] ; then
            echo_r "git pull failed! "
            get_hosts_file_from_backup_site
            return
        else
            echo_g "git pull successfully! "
        fi
        cd ..
    else
        echo_r "there was a directory named \"hosts\", please remove it or change a work directory and try again, failed! "
        exit 1
    fi

    if ! grep github /etc/hosts >/dev/null && test hosts/hosts -nt /etc/hosts; then
        cp /etc/hosts /etc/hosts$(date +%Y%m%d%H%M%S)~
        [ -f hosts/hosts ] && \cp -f hosts/hosts /etc/hosts || ( echo_r "can NOT find file \"hosts/hosts\"" && exit 1 )
    else
        # TODO
        # rm: cannot remove ‘/etc/hosts’: Device or resource busy
        # it occurs in docker when mount /etc/hosts to container as a volume
        rm -f /etc/hosts
        [ -f hosts/hosts ] && \cp -f hosts/hosts /etc/hosts || ( echo_r "can NOT find file \"hosts/hosts\"" && exit 1 )
    fi
}

function validate_network_to_outside(){
    echo_b "validating hosts file ... "
    for (( i=1 ; i<=3 ; i++ )) do
        http_code=$(curl -o /dev/null -m 10 --connect-timeout 10 -s -w "%{http_code}" https://www.google.com.hk/)
        RETVAL=$?
        if test "$http_code" = "200" -o $http_code -eq 200 ; then
            echo_g "Replace hosts file succeeded! "
            echo
            echo_g "Now you can access Google, etc easily! "
            break
        else
            echo "Process returned with HTTP code is: $http_code"
            echo_y "replace hosts file failed! Try again, times $i"
        fi
    done
    if [[ $RETVAL -ne 0 ]]; then
        echo "Process returned with exit RETURN code: $RETVAL"
        echo_r "Google can NOT be reached! Please let we know via email to \"dgdenterprise@gmail.com"\"
        exit 1
    fi

}

function validate_etc_host_conf(){
    echo_b "validating /etc/host.conf file ... "
    if [ -f /etc/host.conf ]; then
        command_exists md5sum || ( echo_r "system is broken, md5sum comes from coreutils usually! " && exit 1 )
        md5="`md5sum /etc/host.conf`"
        content="`cat /etc/host.conf`"
        if $md5 == "ea2ffefe1a1afb7042be04cd52f611a6" || $content == "order hosts,bind"; then
            echo_g "/etc/host.conf file's content is \"`cat /etc/host.conf`\""

        elif $md5 == "4eb63731c9f5e30903ac4fc07a7fe3d6" || $content == "multi on"; then
            echo_g "/etc/host.conf file's content is \"`cat /etc/host.conf`\""
        else
            echo_y "/etc/host.conf file's content is \"`cat /etc/host.conf`\""
        fi
        echo_g "validating /etc/host.conf file passed! "
        return
    else
        echo_y "system maybe broken, can NOT find file \"/etc/host.conf\", make a new one"
        cat >/etc/host.conf<<eof
order hosts,bind
eof
    fi
    validate_etc_host_conf
}

# main function
# Run setup for each distro accordingly, install git here.
cat -<<eof
$header
eof
check_network_connectivity
check_name_resolve
check_linux_distribution
case "$lsb_dist" in
    amzn)
        ;;
    'opensuse project'|opensuse)
        ;;
    'suse linux'|sle[sd])

        ;;
    ubuntu)
        command_exists git || apt_get_install_packages git
        ;;
    centos)
        command_exists git || yum_install_packages git
        ;;
    *)
        echo_r "unsupported system type"
        exit 1
esac

get_hosts_file_from_github
validate_network_to_outside
