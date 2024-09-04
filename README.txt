Requirements: wpa_supplicant, dhcpcd, nftables, conntrack, awk, sshd, which

Currently does not support static WAN IP.

Additional dhcpcd hooks can be added to the sv/dhcpcd/hooks folder.

For example, a hook can automatically reconfigure a bridge side device to use the new WAN IP.
