#!/bin/sh
INSTALL_PATH="$(CDPATH='' cd --  "$(dirname -- "$0")" && pwd)"

echo "Preparing to Uninstall."
echo "WARNING: Network connectivity will be lost after restart."
echo "Press enter to continue..."
read ans

sed -i 's@INSTALL_PATH=.*$@INSTALL_PATH=@g' "$INSTALL_PATH"/variables

if [ -L  /etc/runit/runsvdir/default/sshd ]; then
	rm  /etc/runit/runsvdir/default/sshd
	echo "Service Disabled: sshd"
fi

if [ -L /etc/runit/runsvdir/default/dhcpcd ]; then
	sv exit dhcpcd
	rm /etc/runit/runsvdir/default/dhcpcd
	echo "Service Disabled: dhcpcd"
fi

if [ -L /etc/runit/runsvdir/default/wpa_supplicant ]; then
	sv exit wpa_supplicant
	rm /etc/runit/runsvdir/default/wpa_supplicant
	echo "Service Disabled: wpa_supplicant"
fi

if [ -L /etc/runit/runsvdir/default/dhcpcd-802dot1x ]; then
	sv exit dhcpcd-802dot1x
	rm /etc/runit/runsvdir/default/dhcpcd-802dot1x
	echo "Service Disabled: dhcpcd-802dot1x"
fi

rm /etc/rc.local
echo "Removed rc.local"
echo "You will need to manually restore one of the following backup files located in /etc :"
ls -1 /etc/rc.local.bak.* 2> /dev/null || echo "No rc.local backups exist"

echo "Uninstall Complete. Press enter to reboot."
read ans
reboot
