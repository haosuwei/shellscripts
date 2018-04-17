1  功能:
    1）在集群内所有节点执行命令 
    2）把文件拷贝至所有节点
    3）从各节点获取文件
    
2  配置文件:
    cluster.ini
    必须填写的配置项：
    g_hosts="192.10.37.[10,11,12]"
    
    可选的配置项：
    g_password=""
    g_user_name="root"
    g_port=22
    g_timeout=10
    
    其中g_user_name表示使用那个用户操作，默认root用户
    其中g_password为对应用户的密码文件，如果为空，那么需要在界面手动输入密码，格式如下：
    IP地址1
    IP地址1的密码
    IP地址2
    IP地址2的密码
    注意：
        文件的最后一行不能为空行
        密码中如果包含特殊字符，不需要转义
    例如:
        192.168.1.[3-10]
        123456!654321
        192.168.1.11
        123456!
    g_port为ssh的端口，默认为22
    g_timeout为ssh连接的超时时间，当网络较差时可适当扩大该值，默认为10秒
    
    对于g_password，若没有配置密码文件，需要手动输入密码：
    dc-rack1007-4m:/opt/cluster # ./clustercmd.sh "hostname"
    Please enter cluster SSH password(root): 
    ==>>192.10.37.10
    dc-rack1007-1
    ==>>192.10.37.11
    dc-rack1007-2
    ==>>192.10.37.12
    dc-rack1007-3

3  运行示例:
    1）在各节点运行命令:
        dc-rack1007-4m:/opt/cluster # ./clustercmd.sh "hostname"
        ==>>192.10.37.10
        dc-rack1007-1
        ==>>192.10.37.11
        dc-rack1007-2
        ==>>192.10.37.12
        dc-rack1007-3
        
    2）从各节点获取文件:
        dc-rack1007-4m:/opt/cluster # ./clusterscp.sh get /opt/test/mem.txt /opt/result
        get /opt/result/192.10.37.10_mem.txt from 192.10.37.10:/opt/test/mem.txt successfully.
        get /opt/result/192.10.37.11_mem.txt from 192.10.37.11:/opt/test/mem.txt successfully.
        get /opt/result/192.10.37.12_mem.txt from 192.10.37.12:/opt/test/mem.txt successfully.
        
    3）把已经准备好的hosts文件拷贝至各节点的/etc目录下（注意最终查看文件权限）:
        dc-rack1007-4m:/opt/cluster # ./clusterscp.sh put /opt/test/hosts /etc
        put /opt/test/hosts to 192.10.37.10:/etc successfully.
        put /opt/test/hosts to 192.10.37.11:/etc successfully.
        put /opt/test/hosts to 192.10.37.12:/etc successfully.

        