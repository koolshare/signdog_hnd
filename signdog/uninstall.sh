#!/bin/sh
eval $(dbus export signdog_)
source /koolshare/scripts/base.sh

cd /tmp
sh /koolshare/scripts/signdog_config.sh stop

rm -rf /koolshare/init.d/*signdog.sh
rm -rf /koolshare/bin/signdog
rm -rf /koolshare/res/icon-signdog.png
rm -rf /koolshare/scripts/signdog_*.sh
rm -rf /koolshare/webs/Module_signdog.asp
rm -rf /koolshare/scripts/uninstall_signdog.sh
rm -rf /tmp/signdog*

values=$(dbus list signdog | cut -d "=" -f 1)
for value in $values
do
	dbus remove $value
done
