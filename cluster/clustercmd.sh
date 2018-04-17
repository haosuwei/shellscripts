#!/bin/bash

R_CMD="$1"
G_CURRENT_PATH=""
G_LIB_SCRIPT="cluster_lib.sh"
G_REMOTE_SCRIPT="remote.sh"
G_CONF_FILE="cluster.ini"
G_CONF_FILE_TMP="cluster.ini.tmp.$$"
G_RESULT=0
G_HOSTS_ARRAY=()
G_PASSWDS_ARRAY=()

#脚本解释器 强制设置为 /bin/bash
if [ "$BASH" != "/bin/bash" ]; then
   bash $0 "$@"
   exit $?
fi

###################################################
#
# 记录审计日志
# 
###################################################
function syslog()
{
    local component=$1
    local filename=$2
    local status=$3
    local message=$4

    which logger >/dev/null 2>&1
    [ "$?" -ne "0" ] && return 0;

    login_user_ip="$(who -m | sed 's/.*(//g;s/)*$//g')"
    execute_user_name="$(whoami)"
    logger -p local0.notice -i "FusionInsight;${component};[${filename}];${status};${login_user_ip};${execute_user_name};${message}"
    return 0
}

###################################################
#
# 捕获信号后删除中间文件
# 
###################################################
function sig_handle()
{
    #删除中间文件
    rm "${G_CONF_FILE_TMP}" -f
    stty sane
    echo ""
    syslog "clustercmd" "clustercmd.sh" "exit=1" "clustercmd.sh, catch signal and exit."
    exit 1
}
trap "sig_handle" INT TERM QUIT

###################################################
#
# 显示帮助
#
###################################################
function show_help()
{
    echo "Usage:  $0 command"
}

###################################################
#
# 获取绝对路径
#
###################################################
function get_path()
{
    local path=""

    pushd $(dirname "$0") > /dev/null
    path="$(readlink -e "$(pwd)")"
    popd >/dev/null
    if [ -z "${path}" ]; then
        echo "current path is null."
        return 1
    fi

    G_CURRENT_PATH="${path}"
    G_LIB_SCRIPT="${path}/lib/${G_LIB_SCRIPT}"
    G_REMOTE_SCRIPT="${path}/lib/${G_REMOTE_SCRIPT}"
    G_CONF_FILE="${path}/${G_CONF_FILE}"
    G_CONF_FILE_TMP="${path}/lib/${G_CONF_FILE_TMP}"

    return 0
}

###################################################
#
# 引入配置文件 及 脚本
# 
###################################################
function source_file()
{
    export G_PASSWD_RAND_KEY="${G_PASSWD_RAND_KEY}"
    
    #去除配置文件中的\r字符
    cat "${G_CONF_FILE}" | grep -v "^[[:space:]]*$" | \
        grep -v "^#" | tr -d '\r' > "${G_CONF_FILE_TMP}"
    
    #引入配置文件
    source "${G_CONF_FILE_TMP}"
    if [ $? -ne 0 ]; then
        echo "source ${G_CONF_FILE} failed"
        return 1
    fi
    
    #引入 库函数
    source "${G_LIB_SCRIPT}"
    if [ $? -ne 0 ]; then
        echo "source ${G_LIB_SCRIPT} failed"
        return 1
    fi
    
    return 0
} 

###################################################
#
# 参数检查
#
###################################################
function check_params()
{
    #参数1不能为空
    if [ -z "${R_CMD}" ]; then
        show_help
        return 1
    fi
    
    #判断配置中 用户名
    if [ -z "${g_user_name}" ]; then
        error "g_user_name is null, Please check g_user_name in ${G_CONF_FILE}"
        return 1
    fi
    
    #检查 expect 工具
    which expect > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        error "Please install expect command."
        return 1
    fi

    return 0
}


###################################################
#
# 入口函数
#
###################################################
function main()
{
    local ip=""
    local hosts=""
    local host=""
    local passwd=""
    
    get_path
    if [ $? -ne 0 ]; then        
        return 1
    fi
    
    source_file
    if [ $? -ne 0 ]; then        
        return 1
    fi
    
    check_params
    if [ $? -ne 0 ]; then        
        return 1
    fi
    
    hosts="$(parse_host "${g_hosts}")"
    if [ $? -ne 0 ]; then  
        echo "${hosts}"
        return 1
    fi
    
    #获取集群节点地址数组
    G_HOSTS_ARRAY=($(echo "$hosts" | tr ',' ' '))
    if [ ${#G_HOSTS_ARRAY[@]} -eq 0 ]; then
        error "G_HOSTS_ARRAY is null"
        return 1
    fi
    
    #设置密码
    if [ -z "${g_password}" ]; then
        set_passwd
        if [ $? -ne 0 ]; then        
            return 1
        fi
    else
        if [ "${g_password:0:1}" != "/" ]; then
            g_password="${G_CURRENT_PATH}/${g_password}"
        fi
        parse_passwd "${g_password}"
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi

    
    #在集群中执行命令
    for ((i=0;i<${#G_HOSTS_ARRAY[@]};i++))
    do
        host=${G_HOSTS_ARRAY[${i}]}
        passwd="${G_PASSWDS_ARRAY[${i}]}"
        
        if [ -z "${host}" ]; then
            continue
        fi

        echo "==>>${host}"
        
        #ping目标端 检测是否可以ping通
        ping -c 1 "${host}" -i 0.2 -W 1 > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            error "ping failed."
            continue
        fi
        
        exec_cmd_r "${host}" "${passwd}" "${R_CMD}"
        if [ $? -ne 0 ]; then
            continue
        fi

    done 
    
    return 0
}

syslog "clustercmd" "clustercmd.sh" "begin" "clustercmd.sh $* begin."
main "$@"
G_RESULT=$?
rm "${G_CONF_FILE_TMP}" -f

syslog "clustercmd" "clustercmd.sh" "exit=${G_RESULT}" "clustercmd.sh $* end."
exit ${G_RESULT}
