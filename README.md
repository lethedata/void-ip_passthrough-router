# IP Passthrough Router

These scripts configure Void into a router with IP Passthrough (Half-Bridge).

This is done via ARP Proxying for IP Passthrough, nftables port pinning for NAPT, and arptables for ARP request spoofing.

## Requirements
- OS: Void Linux (Preferably a fresh install)
- NICs: 3 Network Ports
- Non-Base Packages: nftables conntrack-tools
- Recommended tools: tcpdump

## Usage
1) Set variables under Required Variables in the `variables` file
2) Run install.sh script as root
3) Reboot

## Use Case

This was created as a way to "offload" 802.1x and DHCP from HA routers sharing a single Public IP via CARP. By doing this both routers can get updates and properly failover without any additional non-standard changes (ie routing rules and carp trigger scripting). NAT44 was considered however nftables stateless NAT has [issues](https://bugzilla.netfilter.org/show_bug.cgi?id=1771) and it was more desirable to have direct ownership of the IP.

## Extra Notes
- Commands needed by configuration scripts: wpa_supplicant, arptables, dhcpcd, nftables, conntrack, awk, sshd, which
- Artix Linux with runit might work but this is untested.
- Additional dhcpcd-hooks can be added to `sv/dhcpcd/hooks` and `sv/dhcpcd/dhcpcd-802dot1x` folders respectively. Scripts could be created to re-configuring client device holding the passed IP.
