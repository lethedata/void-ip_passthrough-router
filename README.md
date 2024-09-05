# IP Passthrough Router

These scripts configure Void into a router with IP Passthrough (Half-Bridge). This is done via ARP Proxying for IP Passthrough, nftables port pinning for NAPT, and arptables for ARP request spoofing.

## Requirements
- OS: Void Linux (Preferably a fresh install)
- NICs: 3 Network Ports
- Non-Base Packages: nftables conntrack-tools
- Recommended tools: tcpdump

## Usage
1) Download and extract tar file in a directly such as `/opt/passthrough_router`
2) Set variables under Required Variables in the `variables` file
3) Run install.sh script as root
4) Reboot

## Use Case

This was created as a way to "offload" 802.1x and DHCP from HA routers sharing a single Public IP via CARP. By doing this both routers can get updates and properly failover without any additional non-standard changes (ie routing rules and carp trigger scripting). NAT44 was considered however nftables stateless NAT has [issues](https://bugzilla.netfilter.org/show_bug.cgi?id=1771) and it was more desirable to have direct ownership of the IP.

## Extra Notes
- Commands needed by configuration scripts: wpa_supplicant, arptables, dhcpcd, nftables, conntrack, awk, sshd, whereis
- Artix Linux with runit might work but this is untested.
- Additional dhcpcd-hooks can be added to `sv/dhcpcd/hooks` and `sv/dhcpcd/dhcpcd-802dot1x` folders respectively. Scripts could be created to re-configuring client device holding the passed IP.
- extras folder contains commands to build nftable and arptable rules.
- LAN Network is a small CG-NAT network to avoid reserving RFC1918 addresses.
- If interface configuration fails during boot-up for some reason there is a fallback mode that makes the device available via ssh on 100.64.1.100:22 with password root access. 

## To-Do
- Increase fallback mode use across more boot stages.
