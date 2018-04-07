#!/bin/bash

scriptname=build_xmr-stak.sh
cat ip.txt | while read line
do
 scp /opt/$scriptname huawei@$line:/home/huawei
 ssh huawei@$line "echo Huawei@123 | sudo -S /home/huawei/$scriptname" &
 echo "-----$line -------"
done
