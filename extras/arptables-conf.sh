#!/bin/sh
arptables -t filter -A OUTPUT -o "$WAN_INT" -j DROP
# Rule replaced via dhcpcd-hook 01-netconf.sh
#arptables -t filter -R OUTPUT 1 -o "$WAN_INT" -j mangle --mangle-ip-s "$new_ip_address"
