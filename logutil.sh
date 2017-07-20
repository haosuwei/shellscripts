#!/bin/bash

DEBUG="DEBUG"
INFO="INFO"
WARN="WARNING"
ERR="ERROR"

log()
{
    local logServer="$1"
    local logFile="$2"
    local logLevel="$3"
    local logMsg="$4"

    DD=`date +'%Y-%m-%d %H:%M:%S,%N'`
        TIME=${DD:0:23}

    HOSTNAME=`hostname`

    # time hostname rolename loglevel message
    [ -d "$(dirname "$logFile")" ] && echo -e "$TIME $HOSTNAME $logServer $logLevel ${logMsg}" >> "$logFile"

    return 0
}