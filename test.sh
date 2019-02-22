#!/bin/bash

#echo $2
#exit
logpath=''
if [[ $1 == '' || $1 == 'nil' ]];then
echo "日志文件路径为空，默认使用/var/log/messages"
logpath='/var/log/messages'
else
logpath=$1
fi;

if [[ $2 == '' ]];then
delay_time=0.1
else
delay_time=$(($2+0))
fi;
echo $delay_time
while true
do
echo `date +%F-%T-%N` >> $logpath
sleep $delay_time;
done
