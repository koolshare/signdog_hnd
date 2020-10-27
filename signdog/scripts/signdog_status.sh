#! /bin/sh

source $KSROOT/scripts/base.sh
signdog_pid=$(pidof signdog)
LOGTIME=$(TZ=UTC-8 date -R "+%Y-%m-%d %H:%M:%S")
if [ -n "$signdog_pid" ];then
	http_response "【$LOGTIME】签到狗3.0进程运行正常！（PID：$signdog_pid）"
else
	http_response "【$LOGTIME】签到狗3.0进程未运行！"
fi
