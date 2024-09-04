#!/bin/sh
# This script contains the command version of nftables-template.conf and dhcpcd-hook 01-netconf.sh

###
# Passthrough
###
nft add table PASSTHROUGH
nft add chain ip PASSTHROUGH prerouting { type filter hook prerouting priority raw\; policy accept\; }
# Chain rules generated via dhcpcd-hook 01-netconf.sh
#nft add rule ip PASSTHROUGH prerouting ip saddr $WAN_IP th sport != "$PORT_PIN_RANGE_LOW"-"$PORT_PIN_RANGE_HIGH" notrack return
#nft add rule ip PASSTHROUGH prerouting ip daddr $WAN_IP ip protocol != icmp th dport != "$PORT_PIN_RANGE_LOW"-"$PORT_PIN_RANGE_HIGH" notrack return
#nft add rule ip PASSTHROUGH prerouting ip daddr $WAN_IP icmp type echo-request notrack return

###
# Filters
###
nft add table ip FILTER
# Forward
nft add chain ip FILTER forward { type filter hook forward priority filter\; policy drop\; }
nft add chain ip FILTER forward-ctinvalid
# Chain rules generated via dhcpcd-hook 01-netconf.sh
#nft add rule ip FILTER forward-ctinvalid ip daddr $WAN_IP ip protocol icmp accept
nft add rule ip FILTER forward ct state untracked th sport != "$PORT_PIN_RANGE_LOW"-"$PORT_PIN_RANGE_HIGH" accept
nft add rule ip FILTER forward ct state vmap { established: accept, related: accept, invalid: goto forward-ctinvalid }
nft add rule ip FILTER forward ip saddr $LAN_NETWORK ip protocol { tcp, udp, icmp } accept
# Output
nft add chain ip FILTER output { type filter hook output priority filter\; policy drop\; }
nft add rule ip FILTER output ip protocol { tcp, udp, icmp } accept
# Input
nft add chain ip FILTER input { type filter hook input priority filter\; policy drop\; }
nft add chain ip FILTER input_wan
nft add rule ip FILTER input ct state vmap { established: accept, related: accept, invalid: drop }
nft add rule ip FILTER input meta iif vmap { lo : accept, $BRIDGE_NAME : accept, $WAN_INT : jump input_wan}
# Chain rules generated via rc-startup.sh
#nft add rule ip FILTER input_wan tcp dport $HostSRV_SSH_PORTSRV ct count 5 accept comment \"Allow 5 SSH Connections\"

###
# NAT
###
# conntrack -F on disconnect
nft add table NAT
# Port NAT
nft add chain ip NAT pnat  { type nat hook postrouting priority srcnat\; policy accept\; }
# Chain rules generated via dhcpcd-hook 01-netconf.sh
#nft add rule ip NAT pnat meta oif $WAN_INT ip saddr $LAN_NETWORK ip protocol { tcp, udp, icmp } snat to $WAN_IP : "$PAT_RANGE_LOW"-"$PAT_RANGE_HIGH" fully-random
# Port Forwarding
nft add chain ip NAT pfwd { type nat hook prerouting priority dstnat\; policy accept\; }
# Chain rules generated via rc-startup.sh
#nft add rule ip NAT pfwd tcp dport $HostSRV_SSH_PORTFWD dnat to "$LAN_IP":$HostSRV_SSH_PORTSRV comment \"HostSRV: SSH\"
