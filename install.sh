#!/bin/sh
BACK_NUM=1
ERR_COMMAND=1030
ERR_VAR=1035

reqcmds="wpa_supplicant dhcpcd nft conntrack awk sshd which"
reqvars="WAN_INT BRIDGE_NAME BRIDGE_INT1 BRIDGE_INT2 LAN_IP LAN_NETWORK_NUM LAN_NETWORK_CIDR PORT_PIN_RANGE_LOW PORT_PIN_RANGE_HIGH PORT_RESERVE_COUNT"

echo "Validating configuration..."

for progs in $reqcmds; do
	if [ ! "$(command -v $progs)" ]; then
		echo "Installation Failed: $ERR_COMMAND"
		echo "Missing Command: $progs"
		echo "Required Commands: $reqcmds "
		exit $ERR_COMMAND
	fi
done

. "$(CDPATH='' cd --  "$(dirname -- "$0")" && pwd)"/variables

if [ "$HostSRV_DHCPWAN_ENABLED" != 1 ]; then
	echo "Installation Failed: $ERR_VAR"
	echo "Static WAN is not currently supported"
	exit $ERR_VAR
fi

if [ "$HostSRV_MACSPOOF_ENABLED" = 1 ]; then
	reqvars="$reqvars WAN_MAC"
fi

if [ "$HostSRV_802dot1x_ENABLED" = 1 ]; then
	reqvars="$reqvars HostSRV_802dot1x_WPA_CONF"
fi

for variable in $reqvars; do
	if [ -z "$(eval "echo \"\$$variable\"")" ]; then
		echo "Installation Failed: $ERR_VAR"
		echo "Please set required variables in variables file before installation."
		exit $ERR_VAR
	fi
done

ip link add name "$BRIDGE_NAME" > /dev/null 2>&1
ip link show dev "$WAN_INT" > /dev/null 2>&1 || \
	{ echo "ERROR: Bad Interface Name"; exit $ERR_VAR; }
ip link show dev "$BRIDGE_INT1" > /dev/null 2>&1 || \
	{ echo "ERROR: Bad Interface Name"; exit $ERR_VAR; }
ip link show dev "$BRIDGE_INT2" > /dev/null 2>&1 || \
	{ echo "ERROR: Bad Interface Name"; exit $ERR_VAR; }
ip link show dev "$BRIDGE_NAME" > /dev/null 2>&1 || \
	{ echo "ERROR: Bad Bridge Name"; exit $ERR_VAR; }

echo "Validation complete"
echo "Ready to Install."
echo "Press enter to continue..."
read ans

INSTALL_PATH="$(CDPATH='' cd --  "$(dirname -- "$0")" && pwd)"

sed -i 's@INSTALL_PATH=.*$@INSTALL_PATH='"$INSTALL_PATH"'@g' "$INSTALL_PATH"/variables

if [ -L  /etc/runit/runsvdir/default/sshd ]; then
	rm  /etc/runit/runsvdir/default/sshd
	echo "Original Service Disabled: sshd"
fi

if [ -L /etc/runit/runsvdir/default/dhcpcd ]; then
	rm /etc/runit/runsvdir/default/dhcpcd
	echo "Original Service Disabled: dhcpcd"
fi
if [ -L /etc/runit/runsvdir/default/wpa_supplicant ]; then
	rm /etc/runit/runsvdir/default/wpa_supplicant
	echo "Original Service Disabled: wpa_supplicant"
fi

until [ ! -e /etc/rc.local.bak."$BACK_NUM" ]
do
	BACK_NUM=$((BACK_NUM+1))
done

mv /etc/rc.local /etc/rc.local.bak."$BACK_NUM" 2>/dev/null \
&& echo "rc.local Backup: /etc/rc.local.bak.$BACK_NUM" \
|| echo "No rc.local file to backup"

echo '#!/bin/sh' > /etc/rc.local
echo '# Generated from install script' >> /etc/rc.local
echo "export INSTALL_PATH=$INSTALL_PATH" >> /etc/rc.local
echo "$INSTALL_PATH/rc-local/rc-startup.sh" >> /etc/rc.local
chmod +x /etc/rc.local
echo "Generated /etc/rc.local"

echo "Install Complete. Press enter to reboot."
read ans
reboot
