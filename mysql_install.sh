#! /bin/bash

COLOR_RESET="\033[0m"
COLOR_R="\033[0;31m"
COLOR_G="\033[0;32m"
COLOR_Y="\033[0;33m"
COLOR_B="\033[0;34m"
COLOR_P="\033[0;35m"

function help_usage() {
    printf "${COLOR_Y}Usage:${COLOR_RESET} bash mysql_install.sh [version]\n"
    printf "${COLOR_Y}   Ex:${COLOR_RESET} bash mysql_install.sh 8.3.0\n"
    printf "u check mysql vers in url https://downloads.mysql.com/archives/community\n"
    exit 0
}

function get_version() {
    MYSQL_VERSION=$1
    MAJOR_VERSION=$(rpm -q centos-release |awk -F. '{print $1}' |cut -d'-' -f3)
    MINOR_VERSION=$(rpm -q centos-release |awk -F. '{print $1}' |cut -d'-' -f4)
    GLIBIC_VERSION=$(ldd --version |grep '^ldd' |awk '{print $NF}')
    ARCH_VERSION=$(uname -m)
    DOWNLOAD_URL="https://downloads.mysql.com/archives/get/p/23/file/mysql-${MYSQL_VERSION}-linux-glibc${GLIBIC_VERSION}-${ARCH_VERSION}.tar.xz"
    
}

main() {
    pre_chk_pkg="libaio"
    [ $# -eq 1 ] && get_version $1 || help_usage
    ### 작업 과정 순서 
    ### 1.mysql 디렉토리 작업
    ### 2.mysql 계정 작업
    ### 3.mysql binary 다운로드 및 설치
    ### 4.변수작업 (~/.bash_profile)
    ### 5.Mysql 기동 및 기본 설정

    printf "#1. MySQL Directory\n"
    MYSQL_PATH="/DATA/mysql.d"
    if [ ! -d ${MYSQL_PATH} ]; then
        printf "Create dir: ${MYSQL_PATH}/{data,log}\n"
        mkdir -p ${MYSQL_PATH}/{data,log,tmp}
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi
    
    printf "#2. MySQL User\n"
    if ! grep -q mysql /etc/group; then
        printf "Create group: mysql\n" 
        groupadd mysql
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi

    if ! getent passwd mysql >/dev/null 2>&1; then
        printf "Create group: mysql\n" 
        useradd -g mysql -M -s /bin/false mysql
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi    
    
    printf "#3. MySQL install for binary\n"
    if ! command -v wget >/dev/null 2>&1; then
        printf "${COLOR_R}wget command not found.${COLOR_RESET}\n"
        exit 1
    fi
    
    if wget --spider -q ${DOWNLOAD_URL} >/dev/null 2>&1; then
        if [ ! -f $(dirname $0)/mysql-${MYSQL_VERSION}-linux-glibc${GLIBIC_VERSION}-${ARCH_VERSION}.tar.xz ]; then
            printf "Download: mysql-${MYSQL_VERSION}-linux-glibc${GLIBIC_VERSION}-${ARCH_VERSION}.tar.xz\n"
            wget -q ${DOWNLOAD_URL} -P$(dirname $0)/.
            if [ $? -eq 0 ]; then
                printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
            else
                printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
                exit 1
            fi
        else
            printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
        fi

        if [ ! -f ${MYSQL_PATH}/bin/mysqld_safe ]; then
            printf "Unzip: mysql-${MYSQL_VERSION}-linux-glibc${GLIBIC_VERSION}-${ARCH_VERSION}.tar.xz -> ${MYSQL_PATH}/."
            tar -xf mysql-${MYSQL_VERSION}-linux-glibc${GLIBIC_VERSION}-${ARCH_VERSION}.tar.xz -C ${MYSQL_PATH}/. --strip-components=1
            if [ $? -eq 0 ]; then
                printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
            else
                printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
                exit 1
            fi
        else
            printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
        fi

        if [ ! -f ${MYSQL_PATH}/my.cnf ]; then
            printf "Create config: ${MYSQL_PATH}/my.cnf"
            cat <<EOF >${MYSQL_PATH}/my.cnf
[client]
default-character-set       = utf8mb4
port                        = 3306
socket                      = ${MYSQL_PATH}/tmp/mysqld.sock

[mysql]
no-auto-rehash

[mysqldump]
quick
max_allowed_packet = 16M

[mysqld_safe]
socket                      = ${MYSQL_PATH}/tmp/mysqld.sock

[mysqld]
user                        = mysql
pid-file                    = ${MYSQL_PATH}/tmp/mysqld.pid
socket                      = ${MYSQL_PATH}/tmp/mysqld.sock
character-set-server        = utf8mb4
lc_messages                 = ko_KR

port                        = 3306
basedir                     = ${MYSQL_PATH}
datadir                     = ${MYSQL_PATH}/data
tmpdir                      = ${MYSQL_PATH}/tmp
log-error                   = ${MYSQL_PATH}/log/mysql.err

skip-external-locking
explicit_defaults_for_timestamp = TRUE

key_buffer_size         = 256M
thread_cache_size       = 8
table_open_cache        = 4096
sort_buffer_size        = 1M
read_buffer_size        = 1M
read_rnd_buffer_size    = 4M
tmp_table_size          = 2048M
max_allowed_packet      = 16M
max_heap_table_size     = 2048M
max_connections         = 500
max_user_connections    = 40

slow_query_log       = 1
long_query_time      = 8
wait_timeout         = 100
join_buffer_size     = 8M

mysqlx               = OFF
ft_min_word_len      = 2

innodb_file_per_table           = 1
innodb_buffer_pool_size         = 2G
innodb_data_home_dir            = ${MYSQL_PATH}/data
innodb_data_file_path           = ibdata1:10M:autoextend

innodb_log_group_home_dir       = ${MYSQL_PATH}/data
innodb_log_file_size            = 64M
innodb_log_buffer_size          = 8M

innodb_flush_method             = O_DIRECT
innodb_flush_log_at_trx_commit  = 1
innodb_lock_wait_timeout        = 120
EOF
           if [ $? -eq 0 ]; then
                printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
            else
                printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
                exit 1
            fi
        else
            printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
        fi
    fi

    printf "Mysql config link /etc/my.cnf"
    ln -Tfs ${MYSQL_PATH}/my.cnf /etc/my.cnf
    if [ $? -eq 0 ]; then
        printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
    else
        printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
        exit 1
    fi
    
    if [ ! -f ${MYSQL_PATH}/log/mysql.err ]; then
        touch /DATA/mysql.d/log/mysql.err
    fi
    chown -R mysql.mysql ${MYSQL_PATH}/.

    printf "#4. MySQL enviroment setup\n"
    if ! echo ${PATH} |grep -q "${MYSQL_PATH}/bin" >/dev/null 2>&1; then  
        sed -i '/^export PATH/i\PATH=$PATH:'${MYSQL_PATH}'/bin' ~/.bash_profile
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi
    
    ### 5.Mysql 기동 및 기본 설정
    source ~/.bash_profile
    printf "#5. MySQL init setup or start\n"
    printf "Mysql setup: initialize\n"
    if [ ! -d ${MYSQL_PATH}/data/mysql ]; then
        ${MYSQL_PATH}/bin/mysqld --user=mysql --basedir=${MYSQL_PATH} --datadir=${MYSQL_PATH}/data --initialize-insecure
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi

    if [ ! -f ${MYSQL_PATH}/data/public_key.pem ]; then
        printf "Mysql setup: ssl\n"
        mysql_ssl_rsa_setup --datadir=${MYSQL_PATH}/data
        if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi

    if [ ! -f /usr/lib/systemd/system/mysqld.service ]; then
        printf "Create systemd: mysqld.service\n"
        cat <<EOF >/usr/lib/systemd/system/mysqld.service
[Unit]
Description=MySQL Server
After=syslog.target
After=network.target

[Service]
Type=simple
PermissionsStartOnly=true
TimeoutSec=300
PrivateTmp=true
User=mysql
Group=mysql
ExecStart=${MYSQL_PATH}/bin/mysqld_safe --defaults-file=${MYSQL_PATH}/my.cnf

[Install]
WantedBy=multi-user.target
EOF
       if [ $? -eq 0 ]; then
            printf "=> ${COLOR_G}OK${COLOR_RESET}\n"
            systemctl daemon-reload
        else
            printf "=> ${COLOR_R}FAIL${COLOR_RESET}\n"
            exit 1
        fi
    else
        printf "=> ${COLOR_P}SKIP${COLOR_RESET}\n"
    fi
}
main $*