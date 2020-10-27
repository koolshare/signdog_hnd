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
fun_wan_start(){
	if [ "${signdog_enable}" == "1" ];then
		if [ ! -L "/koolshare/init.d/S95signdog.sh" ];then
			echo_date "添加开机启动..."
			ln -sf /koolshare/scripts/signdog_config.sh /koolshare/init.d/S95signdog.sh
		fi
	else
		if [ -L "/koolshare/init.d/S95signdog.sh" ];then
			echo_date "删除开机启动..."
			rm -rf /koolshare/init.d/S95signdog.sh >/dev/null 2>&1
		fi
	fi
}
start_signdog() {
	# 插件开启的时候同步一次时间
	if [ "${signdog_enable}" == "1" ];then
		sync_ntp
	fi

	# 关闭signdog进程
	if [ -n "$(pidof signdog)" ];then
		echo_date "关闭当前签到狗3.0进程..."
		killall signdog >/dev/null 2>&1
	fi
	
	# 定时任务
	# if [ "${signdog_common_cron_time}" == "0" ]; then
	# 	cru d signdog_monitor >/dev/null 2>&1
	# else
	# 	if [ "${signdog_common_cron_hour_min}" == "min" ]; then
	# 		echo_date "设置定时任务：每隔${signdog_common_cron_time}分钟注册一次signdog服务..."
	# 		cru a signdog_monitor "*/"${signdog_common_cron_time}" * * * * /bin/sh /koolshare/scripts/signdog_config.sh"
	# 	elif [ "${signdog_common_cron_hour_min}" == "hour" ]; then
	# 		echo_date "设置定时任务：每隔${signdog_common_cron_time}小时注册一次signdog服务..."
	# 		cru a signdog_monitor "0 */"${signdog_common_cron_time}" * * * /bin/sh /koolshare/scripts/signdog_config.sh"
	# 	fi
	# 	echo_date "定时任务设置完成！"
	# fi

	# 开启signdog
	if [ "$signdog_enable" == "1" ]; then
		echo_date "启动签到狗3.0主程序..."
		export GOGC=40
		mkdir -p /koolshare/configs/singdog
		cd /koolshare/configs/singdog
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
		echo_date "签到狗3.0启动成功，pid：${SDPID}"
		fun_wan_start
	else
		stop
	fi
	echo_date "签到狗3.0插件启动完毕，本窗口将在5s内自动关闭！"
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

	# if [ -n "$(cru l|grep signdog_monitor)" ];then
	# 	echo_date "删除定时任务..."
	# 	cru d signdog_monitor >/dev/null 2>&1
	# fi

	if [ -L "/koolshare/init.d/S95signdog.sh" ];then
		echo_date "删除开机启动..."
   		rm -rf /koolshare/init.d/S95signdog.sh >/dev/null 2>&1
   	fi
}

case $1 in
start)
	set_lock
	if [ "${signdog_enable}" == "1" ]; then
		logger "[软件中心]: 启动signdog！"
		start_signdog
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
