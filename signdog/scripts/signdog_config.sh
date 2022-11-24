#!/bin/sh

source /koolshare/scripts/base.sh
eval $(dbus export signdog_)
INI_FILE=/koolshare/configs/signdog.ini
LOG_FILE=/tmp/upload/signdog_log.txt
LOCK_FILE=/var/lock/signdog.lock
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

set_lock() {
	exec 1000>"$LOCK_FILE"
	flock -x 1000
}
unset_lock() {
	flock -u 1000
	rm -rf "$LOCK_FILE"
}
sync_ntp(){
	# START_TIME=$(date +%Y/%m/%d-%X)
	echo_date "尝试从ntp服务器：ntp1.aliyun.com 同步时间..."
	ntpclient -h ntp1.aliyun.com -i3 -l -s >/tmp/ali_ntp.txt 2>&1
	SYNC_TIME=$(cat /tmp/ali_ntp.txt|grep -E "\[ntpclient\]"|grep -Eo "[0-9]+"|head -n1)
	if [ -n "${SYNC_TIME}" ];then
		SYNC_TIME=$(date +%Y/%m/%d-%X @${SYNC_TIME})
		echo_date "完成！时间同步为：${SYNC_TIME}"
	else
		echo_date "时间同步失败，跳过！"
	fi
}
start_signdog() {
	# 插件开启的时候同步一次时间
	if [ "${signdog_enable}" == "1" -a -n "$(which ntpclient)" ];then
		sync_ntp
	fi

	# 关闭signdog进程
	if [ -n "$(pidof signdog)" ];then
		echo_date "关闭当前签到狗3.0进程..."
		killall signdog >/dev/null 2>&1
	fi

	# 开启signdog
	echo_date "启动签到狗3.0主程序..."
	export GOGC=40
	mkdir -p /koolshare/configs/signdog
	cd /koolshare/configs/signdog
	/koolshare/bin/signdog >/dev/null 2>&1 &

	local SDPID
	local i=10
	until [ -n "$SDPID" ]; do
		i=$(($i - 1))
		SDPID=$(pidof signdog)
		if [ "$i" -lt 1 ]; then
			echo_date "签到狗3.0进程启动失败！"
			echo_date "可能是内存不足造成的，建议使用虚拟内存后重试！"
			close_in_five
		fi
		usleep 450000
	done
	echo_date "主进程启动成功，pid：${SDPID}..."

	start_dnat
	
	echo_date "签到狗3.0启动成功，本窗口将在5s内自动关闭！"
}
start_dnat() {
	# DNAT
	if [ "${signdog_forward}" == "1" ]; then
		local CM=$(lsmod | grep xt_comment)
		local OS=$(uname -r)
		if [ -z "${CM}" -a -f "/lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko" ];then
			echo_date "加载xt_comment.ko内核模块！"
			insmod /lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko
		fi
		echo_date "签到狗：开启端口转发，允许公网访问！"
		local LANADDR=$(ifconfig br0|grep -Eo "inet addr.+"|awk -F ":| " '{print $3}' 2>/dev/null)
		local MATCH=$(iptables -t nat -S PREROUTING | grep signdog_rule)
		if [ -n "${LANADDR}" -a -z "${MATCH}" ];then
			iptables -t nat -A VSERVER -p tcp -m tcp --dport 9930 -j DNAT --to-destination ${LANADDR}:9930 -m comment --comment "signdog_rule"
		fi
	fi
}
stop_dnat(){
	local RULE=$(iptables -t nat -S | grep -w "signdog_rule")
	if [ -n "${RULE}" ];then
		iptables -t nat -S | grep -w "signdog_rule" | sed 's/-A/iptables -t nat -D/g' > clean.sh && chmod 777 clean.sh && ./clean.sh > /dev/null 2>&1 && rm clean.sh
	fi
}
close_in_five() {
	echo_date "插件将在5秒后自动关闭！！"
	local i=5
	while [ $i -ge 0 ]; do
		sleep 1
		echo_date $i
		let i--
	done
	stop
	echo_date "插件已关闭！！"
	unset_lock
	exit
}
stop() {
	# 关闭signdog进程
	if [ -n "$(pidof signdog)" ];then
		echo_date "停止签到狗3.0主进程，pid：$(pidof signdog)"
		killall signdog >/dev/null 2>&1
	fi

	if [ -L "/koolshare/init.d/S95signdog.sh" ];then
		echo_date "删除开机启动..."
		rm -rf /koolshare/init.d/S95signdog.sh >/dev/null 2>&1
	fi

	stop_dnat
}

case $1 in
start)
	set_lock
	if [ "${signdog_enable}" == "1" ]; then
		logger "[软件中心]: 启动签到狗！"
		start_signdog
	else
		logger "[软件中心]: 签到狗未开启，跳过开机启动！"
	fi
	unset_lock
	;;
restart)
	set_lock
	if [ "${signdog_enable}" == "1" ]; then
		stop
		start_signdog
	fi
	unset_lock
	;;
start_nat)
	set_lock
	if [ "${signdog_enable}" == "1" ]; then
		start_dnat
	fi
	unset_lock
	;;
stop)
	set_lock
	stop
	unset_lock
	;;
esac

case $2 in
web_submit)
	set_lock
	true > $LOG_FILE
	http_response "$1"
	if [ "${signdog_enable}" == "1" ]; then
		stop | tee -a $LOG_FILE
		start_signdog | tee -a $LOG_FILE
	else
		stop | tee -a $LOG_FILE
		echo_date "签到狗3.0已经停止运行，本窗口将再5s后关闭！" | tee -a $LOG_FILE
	fi
	echo XU6J03M6 | tee -a $LOG_FILE
	unset_lock
	;;
esac
