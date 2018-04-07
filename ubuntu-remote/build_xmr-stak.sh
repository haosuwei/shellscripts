#!/bin/bash 
#set -x
pkill -f "./xmr-stak"
wallet.address="ssssssssssssssssssss"

ip1=$(ifconfig | grep Bcas | grep -v 127 | grep -v inet6 | sed s/^.*addr://g | sed s/Bcas.*$//g)
ip2=$(echo $ip1)
ipx=$(echo $ip2 |  sed  s/"\."/'-'/g)

# ipx=${ip2:10}
# echo $ipx

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi


if [ -d xmr-stak ]; then
  rm -rf xmr-stak
  git clone https://github.com/fireice-uk/xmr-stak.git
  git -C xmr-stak clean -fd
else
  git clone https://github.com/fireice-uk/xmr-stak.git
fi

########################
# Ubuntu 16.04
########################
#apt update -qq ;
#apt install -y -qq cmake g++ libmicrohttpd-dev libssl-dev libhwloc-dev ;

cd xmr-stak ;
sed -i "s/2/0/g" xmrstak/donate-level.hpp
cmake -DCUDA_ENABLE=OFF -DOpenCL_ENABLE=OFF . ;
make install 
if [ $? -eq 0 ];then
  cd bin/
  ./xmr-stak -i 0 --currency monero7 -o xmr.f2pool.com:13531 -u ${wallet.address}.${ipx} -p example@xx.com  >/dev/null 2>&1 &
else
 echo "start failure"
fi

