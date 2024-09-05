#!/bin/sh

# Error Codes
ERR_VAR_RC=1001
ERR_COMMAND=1030
ERR_FLLBK=1031
ERR_VAR=1035

# Required Commands & Variables
reqcmds="wpa_supplicant dhcpcd nft arptables conntrack awk sshd which"
reqvars="WAN_INT BRIDGE_NAME BRIDGE_INT1 BRIDGE_INT2 LAN_IP LAN_NETWORK_NUM LAN_NETWORK_CIDR PORT_PIN_RANGE_LOW PORT_PIN_RANGE_HIGH PORT_RESERVE_COUNT INSTALL_PATH"

error_fallback(){
	echo "**Configuration Failure**"
	echo "Dropping to fallback mode"
	error_srvdisable
	[ -r /etc/ssh/sshd_config ] || error_fallback_enter

	if [ -L  /etc/runit/runsvdir/default/sshd ]; then
		rm  /etc/runit/runsvdir/default/sshd
		echo "Service disabled: sshd"
	fi

	ip link add name br-fallback type bridge || error_fallback_enter
	ip addr add 100.64.1.100/24 brd + dev br-fallback 
	for i in /sys/class/net/*; do
		int="${i#*/sys/class/net/}"
		if ! [ "$int" = "lo" ] && ! [ "$int" = "br-fallback" ]; then
			ip link set "$int" down 2>/dev/null
			ip addr flush "$int" 2>/dev/null
			ip link set "$int" master br-fallback 2>/dev/null
			ip link set "$int" up 2>/dev/null
		fi
	done
	ip link set br-fallback up || error_fallback_enter
	echo "Starting sshd with root password login available..."
	cmdsshd=$(whereis -b sshd | awk '{ print $2 }')
	$cmdsshd -p 22 -o PermitRootLogin=yes || error_fallback_enter
	echo "**Fallback Mode**"
	echo "IP Addr: 100.64.1.100/24"
	echo "SSH Port: 22"
	exit
}

error_fallback_enter(){
	echo "ERROR: Unable to enter fallback mode"
	exit $ERR_FLLBK
}

error_srvdisable() {
	if  [ -L  /etc/runit/runsvdir/default/dhcpcd ]; then
		rm  /etc/runit/runsvdir/default/dhcpcd
		echo "Service disabled to avoid errors: dhcpcd"
	fi
	if  [ -L  /etc/runit/runsvdir/default/dhcpcd-802dot1x ]; then
		rm  /etc/runit/runsvdir/default/dhcpcd-802dot1x
		echo "Service disabled to avoid errors: dhcpcd-802dot1x"
	fi
	if [ -L  /etc/runit/runsvdir/default/wpa_supplicant ]; then
		rm  /etc/runit/runsvdir/default/wpa_supplicant
		echo "Service disabled to avoid errors: wpa_supplicant"
	fi
}

check_variables(){
	if [ "$HostSRV_DHCPWAN_ENABLED" != 1 ]; then
		echo "ERROR: Static WAN is not currently supported"
		error_srvdisable
		exit $ERR_VAR
	fi

	if [ "$HostSRV_MACSPOOF_ENABLED" = 1 ]; then
		reqvars="$reqvars WAN_MAC"
	fi
	if [ "$HostSRV_802dot1x_ENABLED" = 1 ]; then
		reqvars="$reqvars HostSRV_802dot1x_WPA_CONF"
	fi
	# Check Required Variables
	for variable in $reqvars; do
		if [ -z "$(eval "echo \"\$$variable\"")" ]; then
			echo "ERROR: Missing Variable $variable"
			error_srvdisable
			exit $ERR_VAR
		fi
	done

	if [ "$PORT_RESERVE_COUNT" -ge $((PORT_PIN_RANGE_HIGH-PORT_PIN_RANGE_LOW)) ]; then
		echo "ERROR: PORT_RESERVE_COUNT to large"
		error_srvdisable
		exit $ERR_VAR
	fi
}

enable_srv(){
	if ! [ -L  /etc/runit/runsvdir/default/sshd ]; then
		ln -s  "$INSTALL_PATH"/sv/sshd /etc/runit/runsvdir/default/sshd
		echo "Service Enabled: sshd"
	fi
	if [ "$HostSRV_SSHWAN_ENABLED" = 1 ]; then
		for variable in HostSRV_SSH_PORTSRV HostSRV_SSH_PORTFWD; do
			if [ -z "$(eval "echo \"\$$variable\"")" ]; then
				echo "ERROR: Missing Variable $variable"
				error_srvdisable
				exit $ERR_VAR
			fi
		done
		if [ "$HostSRV_SSH_PORTFWD" -le "$PORT_PIN_RANGE_LOW" ] || [ "$HostSRV_SSH_PORTFWD" -gt "$PAT_RANGE_LOW" ]; then
			echo "ERROR: HostSRV_SSH_PORTFWD Port out of PORT_RESERVE_COUNT Range"
			error_srvdisable
			exit $ERR_VAR
		fi
	fi

	if [ "$HostSRV_802dot1x_ENABLED" = 1 ]; then
		if ! [ -L  /etc/runit/runsvdir/default/wpa_supplicant ]; then
			ln -s "$INSTALL_PATH"/sv/wpa_supplicant /etc/runit/runsvdir/default/wpa_supplicant
			echo "Service Enabled: wpa_supplicant"
		fi
		wpaset='dhcpcd-802dot1x'
	else
		if [ -L  /etc/runit/runsvdir/default/wpa_supplicant ]; then
			rm  /etc/runit/runsvdir/default/wpa_supplicant
			echo "Service Disabled: wpa_supplicant"
		fi
	fi

	if [ "$HostSRV_DHCPWAN_ENABLED" = 1 ]; then
		if [ -z "${wpaset}" ]; then
			if  [ -L  /etc/runit/runsvdir/default/dhcpcd-802dot1x ]; then
				rm  /etc/runit/runsvdir/default/dhcpcd-802dot1x
				echo "Service Disabled: dhcpcd-802dot1x"
			fi
			if ! [ -L  /etc/runit/runsvdir/default/dhcpcd ]; then
				ln -s "$INSTALL_PATH"/sv/dhcpcd /etc/runit/runsvdir/default/dhcpcd
				echo "Service Enabled: dhcpcd"
			fi
		else
			if  [ -L  /etc/runit/runsvdir/default/dhcpcd ]; then
				rm  /etc/runit/runsvdir/default/dhcpcd
				echo "Service Disabled: dhcpcd"
			fi
			if ! [ -L  /etc/runit/runsvdir/default/dhcpcd-802dot1x ]; then
				ln -s "$INSTALL_PATH"/sv/dhcpcd-802dot1x /etc/runit/runsvdir/default/dhcpcd-802dot1x
				echo "Service Enabled: dhcpcd-802dot1x"
			fi
		fi
	else
		if  [ -L  /etc/runit/runsvdir/default/dhcpcd ]; then
			rm  /etc/runit/runsvdir/default/dhcpcd
			echo "Service Disabled: dhcpcd"
		fi
		if  [ -L  /etc/runit/runsvdir/default/dhcpcd-802dot1x ]; then
			rm  /etc/runit/runsvdir/default/dhcpcd-802dot1x
			echo "Service Disabled: dhcpcd-802dot1x"
		fi
	fi
}

add_bridge(){
	ip link add name "$BRIDGE_NAME" type bridge|| \
			{ echo "ERROR: Bad Bridge Name"; error_fallback; exit $ERR_VAR; }
}

validate_interface(){
	ip link show dev "$WAN_INT" > /dev/null 2>&1 || \
		{ echo "ERROR: Bad Interface Name"; error_fallback; exit $ERR_VAR; }
	ip link show dev "$BRIDGE_INT1" > /dev/null 2>&1 || \
		{ echo "ERROR: Bad Interface Name"; error_fallback; exit $ERR_VAR; }
	ip link show dev "$BRIDGE_INT2" > /dev/null 2>&1 || \
		{ echo "ERROR: Bad Interface Name"; error_fallback; exit $ERR_VAR; }
}

load_kernel_modules(){
	# Configure Modules
	sysctl -w net.ipv4.ip_forward=1
	sysctl -w net.ipv4.conf."$BRIDGE_NAME".proxy_arp=1
	sysctl -w net.ipv4.conf."$WAN_INT".proxy_arp=1
	sysctl -w net.ipv4.ip_local_port_range="$PAT_RANGE_LOW $PAT_RANGE_HIGH"
	if [ "${NF_CONNTRACK_HASHSIZE:-0}" -ge "32" ] ; then
		modprobe nf_conntrack hashsize="$NF_CONNTRACK_HASHSIZE"
	fi
}

load_arp_rules(){
	# Prevent Leaking LAN IP out WAN. Replaced with dhcpcd-hook 01-netconf.sh
	arptables -t filter -A OUTPUT -o "$WAN_INT" -j DROP
}

configure_interfaces(){
	# Configure Interfaces
	## WAN
	if [ "$HostSRV_MACSPOOF_ENABLED" = 1 ]; then
		ip link set "$WAN_INT" address "$WAN_MAC"
	fi
	ip link set "$WAN_INT" up
	## Bridge
	ip link set "$BRIDGE_INT1" master "$BRIDGE_NAME"
	ip link set "$BRIDGE_INT2" master "$BRIDGE_NAME"
	ip addr add "$LAN_IP/$LAN_NETWORK_CIDR" brd + dev "$BRIDGE_NAME" || \
		{ echo "ERROR: Bad IP or CIRD"; error_fallback; exit $ERR_VAR; }
	ip link set "$BRIDGE_INT1" up
	ip link set "$BRIDGE_INT2" up
	ip link set "$BRIDGE_NAME" up
}

load_nftable_template(){
	# Load Base nftable Rules
	eval "nft -f - <<EOF
	$(cat "$INSTALL_PATH"/rc-local/nftables-template.conf)
EOF"
	if [ "$HostSRV_SSHWAN_ENABLED" = 1 ]; then
		nft add rule ip FILTER input_wan tcp dport $HostSRV_SSH_PORTSRV ct count 5 accept comment \"Allow 5 SSH Connections\"
		nft add rule ip NAT pfwd tcp dport $HostSRV_SSH_PORTFWD dnat to "$LAN_IP":$HostSRV_SSH_PORTSRV comment \"HostSRV: SSH\"
	fi
}

if [ -z "${INSTALL_PATH}" ] ; then
	echo "ERROR: Missing INSTALL_PATH variable not set or exported in rc.local"
	error_srvdisable
	exit $ERR_VAR_RC
fi

# Validate Required Commands
# Loop through list
for progs in $reqcmds; do
	if [ ! "$(command -v $progs)" ]; then
		echo "ERROR: Missing Command $progs"
		error_srvdisable
		exit $ERR_COMMAND
	fi
done

# Load Variables
. "$INSTALL_PATH"/variables

if [ "$FALLBACK_BOOT" = 1 ]; then
	error_fallback
fi

check_variables
enable_srv
add_bridge
validate_interface
load_kernel_modules
load_arp_rules
configure_interfaces
load_nftable_template
