#!/bin/sh

. "$(CDPATH='' cd --  "$(dirname -- "$0")" && pwd)"/../../variables

add_routes()
{

	ip route add "$new_network_number/$new_subnet_cidr" dev "$WAN_INT" protocol dhcp
	ip route add "$new_ip_address/32" dev "$BRIDGE_NAME" protocol dhcp
	ip route add default via "$new_routers" dev "$WAN_INT" protocol dhcp
	echo "Routes Added"
}


add_rules()
{
	nft add rule ip PASSTHROUGH prerouting ip saddr "$new_ip_address" th sport != "$PORT_PIN_RANGE_LOW"-"$PORT_PIN_RANGE_HIGH" notrack return
	nft add rule ip PASSTHROUGH prerouting ip daddr "$new_ip_address" ip protocol != icmp th dport != "$PORT_PIN_RANGE_LOW"-"$PORT_PIN_RANGE_HIGH" notrack return
	nft add rule ip PASSTHROUGH prerouting ip daddr "$new_ip_address" icmp type echo-request notrack return
	nft add rule ip FILTER forward-ctinvalid ip daddr "$new_ip_address" ip protocol icmp accept
	nft add rule ip NAT pnat meta oif "$WAN_INT" ip saddr "$LAN_NETWORK" ip protocol { tcp, udp, icmp } snat to "$new_ip_address" : "$PAT_RANGE_LOW"-"$PAT_RANGE_HIGH" fully-random
	echo "Rules Added"
}

flush_routes()
{
	ip route flush protocol dhcp
	ip neigh flush to "${old_ip_address:-0.0.0.0}"
	echo "Routes Flushed"
}

flush_rules()
{
	conntrack -F
	nft flush chain ip NAT pnat
	nft flush chain ip PASSTHROUGH prerouting
	nft flush chain ip FILTER forward-ctinvalid
	echo "Rules Flushed"
}

if [ "$interface" = "$WAN_INT" ]; then
        if $if_up; then
        	if [ "$new_ip_address" != "${old_ip_address:-0.0.0.0}" ]; then
                	flush_routes
                	flush_rules
                	add_rules
                	add_routes
                fi
        elif $if_down; then
        	flush_routes
                flush_rules
        fi
fi
