#!/bin/bash

###################################################
# 功能: 记录日志
#
# 接口:
#   函数: error <log>
#   函数: warn <log>
#   函数: info <log>
#   函数: debug <log>
#
# 输入: 日志信息
#
# 示例:
#   error "run failed"
###################################################

###################################################
# 记录错误日志
###################################################
function error()
{
    # error日志在界面上输出(红色)
    echo -e "\033[31mError: $*\033[0m"
}

###################################################
# 记录警告日志
###################################################
function warn()
{
    # error日志在界面上输出(黄色)
    echo -e "\033[33mWarn: $*\033[0m"
}

###################################################
# 记录一般日志
###################################################
function info()
{
    #输出info日志
    echo "$@"
}

###################################################
# 记录调试日志
###################################################
function debug()
{
    return 0
}

###################################################
# 功能: 设置密码
###################################################

###################################################
#
# 设置用户输入的集群服务器密码
#
###################################################
function set_passwd()
{
    local empty=""   #密码是否为空
    local i=0        #循环控制变量
    local max=3      #最大的循环次数
    local show="Please enter cluster SSH password(${g_user_name}): "

    debug "Enter [${FUNCNAME}:${LINENO}]"

    #如果输入了无效字符,可以使用Ctrl+Backspace键删除这些字符
    #说明:执行 stty erase '^H' 后,可以使用Backspace键删除字符
    #     但这改变了默认的行为,有可能会对其他程序产生影响
    while true
    do
        ((i++))
        #输入超时时间设置为60秒
        #说明:使用系统内置REPLY来保存输入信息,
        #     可以完全保留输入信息中的空格
        #如果使用自定义变量,输入信息的最前端和最后端的空格将会被丢弃
        #每次read都会重新初始化REPLY内置变量
        read -t 60 -s -r -p "$show"
        echo ""
        if [ -n "$REPLY" ]; then
            for ((i=0;i<${#G_HOSTS_ARRAY[@]};i++))
            do
                G_PASSWDS_ARRAY[${i}]="$REPLY"
            done
            break
        else
            #如果密码为空,需要进行确认
            read -t 60 -p "The password is empty(yes/no)? : " empty
            if [ "$empty" == "yes" -o "$empty" == "y" -o\
                 "$empty" == "YES" -o "$empty" == "Y" ]; then
                info "The password is empty."
                for ((i=0;i<${#G_HOSTS_ARRAY[@]};i++))
                do
                    G_PASSWDS_ARRAY[${i}]=""
                done
                break
            else
                #超过最大次数后,退出
                if [ ${i} -ge ${max} ]; then
                    error "Entered password is wrong"
                    return 1
                fi
                show="Please enter cluster SSH password again[${i}/$((${max}-1))]: "
                debug "Again[${i}/$((${max}-1))] [${FUNCNAME}:${LINENO}]"
                continue
            fi
        fi
    done

    debug "Leave [${FUNCNAME}:${LINENO}]"

    return 0
}

###################################################
# 功能: 解析主机名
#
# 接口: (函数) parse_host <a list of hostname>
#
# 输入: 主机名(或IP地址)列表字符串
# 输出: 以逗号为分割符的主机名(或IP地址)列表
#
# 示例:
#   parse_host "10.85.23.[11,14-15]"
###################################################

###################################################
#  主机名格式化说明：
#  1:不同的主机名或IP地址以逗号(英文逗号)为分割符
#   例如: 10.85.23.11,host11
#  2:使用方括号扩展IP地址或主机名
#   例如: 10.85.23.[11-13] 表示 10.85.23.11,10.85.23.12,10.85.23.13
#         host[1-4] 表示 host1,host2,host3,host4
#         10.85.23.[11,14-15] 表示 10.85.23.11,10.85.23.14,10.85.23.15
#         host[a,b,c] 表示 hosta,hostb,hostc
#  3:一个IP地址或主机名表达式可以包含多个方括号
#   例如: 10.[85-86].[10-15,80].[12,50-54]
#  4:扩展后的主机名以逗号为分割符
###################################################

###################################################
#
# 检查host字符串
# 1:判断HOST是否为空字符串
# 2:判断是否有其他非法字符
# 3:判断方括号是否成对出现
# 4:判断是否包含空格,重复的逗号和中横线,空白方括号
#
###################################################
function _check_host()
{
    local host="$1"    #主机名或IP地址

    debug "[${host}] Enter [${FUNCNAME}:${LINENO}]"

    #判断HOST是否为空字符串
    if [ -z "$host" ]; then
        error "Host is Null, Please check g_hosts in ${G_CONF_FILE}"
        return 1
    fi

    #判断是否有其他非法字符
    if [ -n "$(echo "$host" | tr -d [:alnum:][].,-)" ]; then
        error "Host($host) contains forbidden character"
        return 1
    fi

    #判断方括号是否成对出现
    if [ -n "$(echo "$host" | tr -cd [] | sed 's/\[\]//g')" ]; then
        error "Host($host) contains non-matching brackets"
        return 1
    fi

    #判断是否包含空格,重复的逗号和中横线,空白方括号
    if [ -n "$(echo "$host" | grep -E ',,|--|\[\]|[[:space:]]')" ]; then
        error "Host($host) contains invalid combination character"
        return 1
    fi

    debug "[${host}] Leave [${FUNCNAME}:${LINENO}]"

    return 0
}

###################################################
#
# 扩展横线(-)为逗号(,) 例如:把 [1,3-5] 转换 [1,3,4,5]
#
###################################################
function _extend_horizontal()
{
    local host="$1"    #主机名或IP地址
    local result="$1"  #转换后的主机名或IP地址
    local b_num=0      #方括号(brackets)个数
    local i=0          #循环变量
    local j=0          #循环变量
    local start=0      #中横线左侧的数字
    local end=0        #中横线右侧的数字
    local tmp=""       #扩展过程的中间变量

    debug "[${host}] Enter [${FUNCNAME}:${LINENO}]"

    if [ -z "$host" ]; then
        error "Host is Null"
        return 1
    fi

    b_num=$(echo "$host" | tr -cd [ | wc -c)
    if [ $b_num -eq 0 ]; then
        #没有方括号 不需要扩展
        echo "$host"
        return 0
    fi

    for((i=2;i<2+$b_num;i++))
    do
        while read line
        do
            start=$(echo "$line" | awk -F'-' '{print $1}')
            end=$(echo "$line" | awk -F'-' '{print $2}')
            if [ -n "$(echo "${start}" | tr -d [:digit:])" ] || \
               [ -n "$(echo "${end}" | tr -d [:digit:])" ] || [ $start -ge $end ]; then
                error "horizontal format invalid[$line]"
                return 1
            fi
            tmp="$start"
            for ((j=$start + 1; j<=$end; j++))
            do
                tmp="${tmp},$j"
            done
            result=$(echo "$result" | sed 's/\['$line'/\['$tmp'/g' | sed 's/,'$line'/,'$tmp'/g')
        done < <(echo "$host" | awk -F'[' '{print $'$i'}' | awk -F']' '{print $1}' \
                              | tr ',' '\n' | awk '{if ($1~/-/) print $1}')
    done

    debug "[${result}] Leave [${FUNCNAME}:${LINENO}]"

    echo "$result"
    return 0
}

###################################################
#
# 扩展方括号,即消除host中的方括号
#
###################################################
function _extend_brackets()
{
    local host="$1"               #主机名或IP地址
    local result=""               #转换后的主机名
    local b_num=0                 #方括号(brackets)个数
    local all_num=0               #扩展后总的主机名个数
    local element=""              #保存数组元素
    local e_num=""                #数组元素中的子项个数
    local e_index=0               #数组元素中的子项的索引值
    local e_value=""              #数组元素中的子项的内容
    local h_tmp=""                #主机名临时变量
    local i=0                     #循环变量
    local j=0                     #循环变量
    local k=0                     #循环变量
    declare -a name_arr=()        #方括号内的名字数组
    declare -a num_arr=()         #方括号内的名字的个数

    debug "[${host}] Enter [${FUNCNAME}:${LINENO}]"

    #入参检查
    if [ -z "$host" ]; then
        error "Host is Null"
        return 1
    fi

    #获取方括号的个数
    b_num=$(echo "$host" | tr -cd [ | wc -c)
    if [ $b_num -eq 0 ]; then
        #没有方括号不需要扩展
        echo "$host"
        return 0
    fi

    #解析方括号的内容
    all_num=1
    for ((i=2;i<2+$b_num;i++))
    do
        element=$(echo "$host" | awk -F'[' '{print $'$i'}' | awk -F']' '{print $1}')
        name_arr=(${name_arr[@]} $element)
        e_num=$(($(echo "$element" | tr -cd ',' | wc -c) + 1))
        num_arr=(${num_arr[@]} $e_num)
        all_num=$(($all_num * $e_num))
    done

    #扩展方括号的内容
    for ((i=0;i<$all_num;i++))
    do
        k=1
        h_tmp="$host"
        for ((j=0;j<${#name_arr[@]};j++))
        do
            e_index=$((($i % ($k * ${num_arr[$j]})) / $k + 1))
            e_value=$(echo "${name_arr[$j]}" | awk -F',' '{print $'$e_index'}')
            k=$(($k * ${num_arr[$j]}))
            h_tmp=$(echo "$h_tmp" | sed 's/\['${name_arr[$j]}'\]/'$e_value'/')
        done
        result="${result},${h_tmp}"
    done

    #判断目标主机名是否为空
    if [ -z "$result" ]; then
        error "result is Null"
        return 1
    fi

    #删除字符串最前面的逗号
    result="$(echo "$result" | sed "s/^,//g")"

    debug "[${result}] Leave [${FUNCNAME}:${LINENO}]"

    echo "$result"
    return 0

}

###################################################
#
# 解析HOST: 共分为6个步骤
#  1:检查host字符串
#  2:如果没有方括号 不需要扩展 直接返回
#  3:把中括号([])以外的逗号(,)转换为分号(;)
#  4:扩展中横线(-)为逗号(,) 例如:把 [1,3-5] 转换 [1,3,4,5]
#  5:以分号为分隔符,对每个host单独处理
#  6:扩展队列中的每个元素的中括号([])
#  7:生成一个以逗号为分割符的字符串
#  8:去除重复的host
#
###################################################
function parse_host()
{
    local host="$1"     #主机名或IP地址
    local result=""     #解析后的主机名
    local h_tmp=""      #保存临时主机名

    debug "[${host}] Enter [${FUNCNAME}:${LINENO}]"

    #1:检查host字符串
    _check_host "$host"
    if [ $? -ne 0 ]; then
        return 1
    fi

    #2:如果没有方括号 不需要扩展
    if [ -z "$(echo "$host" | grep '\[')" ]; then
        host="$(echo "$host" | tr ',' '\n' | sort | uniq | tr '\n' ',' | sed "s/^,//g" | sed "s/,$//g")"
        echo $host
        return 0
    fi

    #3:把中括号([])以外的逗号(,)转换为分号(;)
    host=$(echo "$host" | awk 'BEGIN{FS=""} {j=1;
        for(i=1;i<=NF;i++){
            if ($i=="[")j=0;
            if ($i=="]")j=1;
            if (($i==",")&&(j == 1))printf ";";
            else printf $i;
        }}')

    #4:扩展中横线(-)为逗号(,) 例如:把 [1,3-5] 转换 [1,3,4,5]
    host=$(_extend_horizontal "$host")
    if [ $? -ne 0 ]; then
        echo "$host"
        error "_extend_horizontal failed"
        return 1
    fi

    #5:以分号为分隔符,对每个host单独处理
    while read line
    do
        if [ -z "$line" ]; then
            continue
        fi
        if [ -z "$(echo "$line" | grep '\[.*\]')" ]; then
            result="${result},${line}"
            continue
        fi

        #6:扩展队列中的每个元素的中括号([])
        h_tmp=$(_extend_brackets "$line")
        if [ $? -ne 0 ] || [ -z "$h_tmp" ]; then
            echo "$h_tmp"
            error "_extend_brackets(${host}:${line}) failed"
            return 1
        fi
        #7:生成一个以逗号为分割符的字符串
        result="${result},${h_tmp}"
    done < <(echo "$host" | tr ';' '\n' | awk '{print $1}')

    #8:去除重复的host
    host="$(echo "$result" | tr ',' '\n' | sort | uniq | tr '\n' ',' | sed "s/^,//g" | sed "s/,$//g")"
    debug "[${host}] Leave [${FUNCNAME}:${LINENO}]"

    echo "$host"

    return 0
}


###################################################
#
# 解析passwd: 共分为6个步骤
#  1:检查host字符串
#  2:如果没有方括号 不需要扩展 直接返回
#  3:把中括号([])以外的逗号(,)转换为分号(;)
#  4:扩展中横线(-)为逗号(,) 例如:把 [1,3-5] 转换 [1,3,4,5]
#  5:以分号为分隔符,对每个host单独处理
#  6:扩展队列中的每个元素的中括号([])
#  7:生成一个以逗号为分割符的字符串
#  8:去除重复的host
#
###################################################
function parse_passwd()
{
    local passwd_file="$1"     #主机名或IP地址
    local hosts_array=()
    local hosts_line=0
    local passwd_line=0
    local hosts=""
    local passwd=""
    local count=0;
    local -a find_flag

    debug "[${host}] Enter [${FUNCNAME}:${LINENO}]"
    
    if [ -z "${passwd_file}" ]; then
        error "${passwd_file} is null"
        return 0
    fi
    
    #判断文件是否存在
    if [ ! -f "${passwd_file}" ]; then
        error "${passwd_file} not exist"
        return 1
    fi
    
    #密码文件的行数
    row_line=$(cat "${passwd_file}" | wc -l)
    if [ $row_line -eq 0 ]; then
        error "password file is empty"
        return 1
    fi
    
    #判断是否成对出现
    ((is_double=row_line%2))
    if [ "${is_double}" == 1 ]; then
        error "password file is invalid"
        return 1
    fi
    
    hosts_line=0
    passwd_line=0
    while read -r LINE
    do
        #该行是hosts
        if [ $hosts_line -eq 0 -a $passwd_line -eq 0 ]; then
            hosts="$(parse_host "${LINE}")"
            if [ $? -ne 0 ]; then  
                return 1
            fi
            
            #获取集群节点地址数组
            hosts_array=($(echo "$hosts" | tr ',' ' '))
            if [ ${#hosts_array[@]} -eq 0 ]; then
                error "hosts is invalid"
                return 1
            fi
            
            hosts_line=1
            #再继续读一行
            read -r LINE
            if [ $? -ne 0 ]; then
                error "${hosts}: read password failed, password file is invalid"
                return 1
            fi
        fi
        
        #该行是passwd
        if [ $hosts_line -eq 1 -a $passwd_line -eq 0 ]; then
            passwd="${LINE}"
            if [ -z "${passwd}" ]; then
                debug "${hosts}: password is empty"
            fi
            
            passwd_line=1
        fi
        
        if [ $hosts_line -eq 1 -a $passwd_line -eq 1 ]; then
            #因为返回是节点IP地址都是排序的，所以时间复杂度应该也不算高
            for ((i=0;i<${#hosts_array[@]};i++))
            do
                for ((j=0;j<${#G_HOSTS_ARRAY[@]};j++))
                do
                    if [ "${hosts_array[${i}]}" == "${G_HOSTS_ARRAY[${j}]}" ]; then
                        if [ "${find_flag[${j}]}" == 1 ]; then
                            error "${G_HOSTS_ARRAY[${j}]}: password has been parsed already. Please check whether the password file is configured incorrectly."
                            return 1
                        fi
                        G_PASSWDS_ARRAY[${j}]="${passwd}"
                        find_flag[${j}]=1
                        ((count++))
                        break
                    fi
                done
                
                if [ ${j} -ge ${#G_HOSTS_ARRAY[@]} ]; then
                    debug "can not find hosts"
                fi
            done
            
            unset hosts_array
            hosts_line=0
            passwd_line=0
        else
            #哪里出了什么问题了，导致没有成对地读出，应该返回失败
            error "read passwd file failed, unknown error"
            return 1
        fi
    done < <(cat "${passwd_file}")
    
    #如果获取的节点的密码数和总节点数不一致，那么肯定是遗漏了那个节点的密码了，返回失败
    if [ "${count}" != ${#G_HOSTS_ARRAY[@]} ]; then
        for ((i=0;i<${#G_HOSTS_ARRAY[@]};i++))
        do
            if [ -z "${find_flag[${i}]}" -o "${find_flag[${i}]}" != "1" ]; then
                error "${G_HOSTS_ARRAY[${i}]}: password is not configured"
            fi
        done
        error "parse password file failed."
        return 1
    fi

    return 0
}

###################################################
# 功能: 在远端服务器运行命令 或 拷贝文件
###################################################

###################################################
#
# 在远端服务器运行命令
#
###################################################
function exec_cmd_r()
{
    local host="$1"       #远端主机名
    local passwd="$2"     #主机密码
    local command="$3"    #运行的命令
    local ret=0           #返回值
    local cmd_file="/tmp/exec_cmd_r.$$.$(date +%s%N)"

    #入参判断
    if [ -z "$host" ]; then
        error "host is null"
        return 1
    fi

    if [ -z "$command" ]; then
        error "command is null"
        return 1
    fi
    
    
    bash $G_REMOTE_SCRIPT -i "$host" -P "$g_port" -u "$g_user_name" -p "$passwd" \
              -t "$g_timeout" -m "ssh-cmd" -c "$command" > ${cmd_file}
    ret=$?
    cat "${cmd_file}" | grep -v "^spawn ssh" | grep -v "^Warning" | grep -v "^Password:" | \
              grep -v "^Authorized" | grep -v "password:" | grep -v "^Permission denied"
    rm "${cmd_file}" -f         
    if [ $ret -ne 0 ]; then
        error "Run ${command} in ${host} failed, ret code:${ret}"
    fi

    return $ret
}

###################################################
#
# 把文件拷贝至远端服务器
#
###################################################
function cp_file_to_r()
{
    local host="$1"       #远端主机名
    local passwd="$2"     #主机密码
    local src="$3"        #源文件
    local dst="$4"        #目标文件
    local ret=0           #返回值

    #入参判断
    if [ -z "$host" ]; then
        error "host is null"
        return 1
    fi

    if [ -z "$src" ]; then
        error "src is null"
        return 1
    fi

    if [ -z "$dst" ]; then
        error "dst is null"
        return 1
    fi

    bash $G_REMOTE_SCRIPT -i "$host" -P "$g_port" -u "$g_user_name" -p "$passwd" \
              -t "$g_timeout" -m "scp-out" -s "$src" -d "$dst" > /dev/null 2>&1
    ret=$?
    if [ $ret -ne 0 ]; then
        error "put ${src} to ${host}:${dst} failed , ret code:${ret}"
    else
        info "put ${src} to ${host}:${dst} successfully."
    fi

    return $ret
}

##################################################
#
# 把远端服务器文件拷贝至本地
#
###################################################
function cp_file_from_r()
{
    local host="$1"       #远端主机名
    local passwd="$2"     #主机密码
    local src="$3"        #源文件
    local dst="$4"        #目标文件
    local name=""
    local ret=0           #返回值

    #入参判断
    if [ -z "$host" ]; then
        error "host is null"
        return 1
    fi

    if [ -z "$src" ]; then
        error "src is null"
        return 1
    fi

    if [ -z "$dst" ]; then
        error "dst is null"
        return 1
    fi

    #获取 源文件的文件名称
    name="${host}_$(basename "${src}")"
    
    bash $G_REMOTE_SCRIPT -i "$host" -P "$g_port" -u "$g_user_name" -p "$passwd" \
              -t "$g_timeout" -m "scp-in" -s "$src" -d "${dst}/${name}" > /dev/null 2>&1
    ret=$?
    if [ $ret -ne 0 ]; then
        error "get ${dst}/${name} from ${host}:${src} failed , ret code:${ret}"
    else
        info "get ${dst}/${name} from ${host}:${src} successfully."
    fi

    return $ret
}

