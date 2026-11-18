# Recipes

Small, optional settings we use on our L-71W. Each one is independent. Commands are for the router shell (SSH or serial console).
Several of them need the [extra packages](../README.md#extra-packages) from the release.

## LEDs

LED names on the L-71W (`ls /sys/class/leds`): `green:power`, `red:power`, `green:alarm`, `red:alarm`,
`green:wan-online`, `red:wan-online`, `green:wlan`, `green:sd`, `green:usb`, and `ath10k-phy0`.
`ath10k-phy0` is the radio's own LED and is **not** wired to the front panel; use `green:wlan` for Wi-Fi.

```sh
# Wi-Fi LED: on while the access point is up, blinks on traffic
uci add system led
uci set system.@led[-1].name='Wi-Fi'
uci set system.@led[-1].sysfs='green:wlan'
uci set system.@led[-1].trigger='netdev'
uci set system.@led[-1].dev='phy0-ap0'
uci add_list system.@led[-1].mode='link'; uci add_list system.@led[-1].mode='tx'; uci add_list system.@led[-1].mode='rx'

# Internet LED: on while a cable is in the WAN port, blinks on traffic
uci add system led
uci set system.@led[-1].name='WAN'
uci set system.@led[-1].sysfs='green:wan-online'
uci set system.@led[-1].trigger='netdev'
uci set system.@led[-1].dev='eth0'
uci add_list system.@led[-1].mode='link'; uci add_list system.@led[-1].mode='tx'; uci add_list system.@led[-1].mode='rx'

# USB LED: on while a device is plugged into the USB-A port (needs kmod-usb-ledtrig-usbport).
# The external port is usb1-port1 / usb2-port1; usb1-port2 is the internal card reader.
uci add system led
uci set system.@led[-1].name='USB'
uci set system.@led[-1].sysfs='green:usb'
uci set system.@led[-1].trigger='usbport'
uci add_list system.@led[-1].port='usb1-port1'; uci add_list system.@led[-1].port='usb2-port1'

uci commit system; /etc/init.d/led restart
```

SD LED: there is no disk-activity trigger for the USB card reader, so [`90-sd-led`](90-sd-led) lights the LED while the
card is present. Copy it to `/etc/hotplug.d/block/90-sd-led` and `chmod 755` it.

## microSD card: network folder, persistent log, weekly config backup

The card slot is an internal USB card reader (Realtek), the card appears as `/dev/sda`. The image already has ext4,
`block-mount` and the `ksmbd` SMB server.

```sh
mkfs.ext4 -F -L sd -m 0 /dev/sda1            # erases the card
uuid=$(block info /dev/sda1 | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')
uci add fstab mount; uci set fstab.@mount[-1].uuid="$uuid"; uci set fstab.@mount[-1].target='/mnt/sd'
uci set fstab.@mount[-1].options='noatime'; uci set fstab.@mount[-1].enabled='1'; uci commit fstab; block mount
mkdir -p /mnt/sd/share /mnt/sd/logs /mnt/sd/backup

# SMB share \\192.168.1.1\sd for one user (modern Windows refuses guest SMB, so use a user)
echo 'home:x:1000:1000:home:/var:/bin/false' >> /etc/passwd; echo 'home:x:1000:' >> /etc/group
echo 'home:*:0:0:99999:7:::' >> /etc/shadow
ksmbd.adduser -a -p 'CHANGE-ME' home
uci add ksmbd share; uci set ksmbd.@share[-1].name='sd'; uci set ksmbd.@share[-1].path='/mnt/sd/share'
uci set ksmbd.@share[-1].read_only='no'; uci set ksmbd.@share[-1].guest_ok='no'; uci set ksmbd.@share[-1].users='home'
uci set ksmbd.@share[-1].force_root='1'; uci set ksmbd.@share[-1].create_mask='0664'; uci set ksmbd.@share[-1].dir_mask='0775'
uci commit ksmbd; /etc/init.d/ksmbd enable; /etc/init.d/ksmbd restart

# system log on the card (survives reboots)
uci set system.@system[0].log_file='/mnt/sd/logs/messages'; uci set system.@system[0].log_size='1024'
uci commit system; /etc/init.d/log restart

# config backup every Sunday 04:30, keep 60 days
echo '30 4 * * 0 grep -q " /mnt/sd " /proc/mounts && sysupgrade -b /mnt/sd/backup/cfg-$(date +\%F).tar.gz && find /mnt/sd/backup -name "cfg-*.tar.gz" -mtime +60 -delete' >> /etc/crontabs/root
/etc/init.d/cron restart
```

## USB printer as a network printer (p910nd)

Needs `kmod-usb-printer`, `p910nd` (and optionally `luci-app-p910nd`). Tested with a Kyocera FS-1041 (host-based printer):
the driver stays on the PC, the router passes raw data from TCP 9100 to the USB printer.

```sh
uci set p910nd.@p910nd[0].device='/dev/usb/lp0'
uci set p910nd.@p910nd[0].port='0'            # 0 = TCP 9100
uci set p910nd.@p910nd[0].bidirectional='1'
uci set p910nd.@p910nd[0].enabled='1'
uci commit p910nd; /etc/init.d/p910nd enable; /etc/init.d/p910nd restart
```

p910nd starts by itself when the printer is plugged in. On Windows: *Add a printer → by TCP/IP address → 192.168.1.1*,
port 9100, protocol Raw, and the printer's normal driver. Do **not** open port 9100 on WAN; print remotely over a VPN.

If the printer is not detected (`dmesg` shows `device descriptor read/64, error -71`), power-cycle the printer with the
cable plugged into the router; that fixed it for us.

## Backup internet over a phone or USB modem, with automatic failover

Needs the USB network drivers from the extra packages (`kmod-usb-net-rndis`, `-cdc-ether`, `-cdc-ncm`, `-ipheth`…).
Android USB tethering shows up as `usb0`; an iPhone or a "HiLink" modem usually as the next `ethN` (`eth3` here).

```sh
uci set network.wan.metric='10'
uci set network.usbwan=interface; uci set network.usbwan.proto='dhcp'; uci set network.usbwan.device='usb0'
uci set network.usbwan.metric='20'
uci set network.usbwan_eth=interface; uci set network.usbwan_eth.proto='dhcp'; uci set network.usbwan_eth.device='eth3'
uci set network.usbwan_eth.metric='21'
z=$(uci show firewall | sed -n "s/^firewall\.\(@zone\[[0-9]\]\)\.name='wan'$/\1/p")
uci add_list firewall.$z.network='usbwan'; uci add_list firewall.$z.network='usbwan_eth'
uci commit; /etc/init.d/network reload; /etc/init.d/firewall reload
```

If the WAN cable is unplugged, traffic moves to the phone by itself. If the cable stays up but the provider has no
internet, [`wan-failover`](wan-failover) handles it: every 20 s it pings 1.1.1.1 / 8.8.8.8 / 9.9.9.9 **through eth0**;
after 3 failures it moves the WAN default route to metric 200, and moves it back to 10 when the pings answer again.

```sh
cp wan-failover /usr/sbin/wan-failover; cp wan-failover.init /etc/init.d/wan-failover
chmod 755 /usr/sbin/wan-failover /etc/init.d/wan-failover
/etc/init.d/wan-failover enable; /etc/init.d/wan-failover start
logread -e wan-failover
```

**Important:** Android shares by USB whatever internet the phone itself uses. If the phone is connected to this
router's Wi-Fi, you get a loop. Turn Wi-Fi off on the backup phone. Android also turns USB tethering off after every
reconnect or reboot of the phone.

## Remote access with Tailscale (no public IP needed)

The image has no `tun` module, so run Tailscale in userspace mode from the official static tarball:

```sh
cd /tmp
uclient-fetch -O ts.json 'https://pkgs.tailscale.com/stable/?mode=json'
f=$(jsonfilter -i ts.json -e '@.Tarballs.arm')
uclient-fetch -O "$f" "https://pkgs.tailscale.com/stable/$f"
uclient-fetch -O "$f.sha256" "https://pkgs.tailscale.com/stable/$f.sha256"
[ "$(cut -c1-64 "$f.sha256")" = "$(sha256sum "$f" | cut -c1-64)" ] && echo SHA OK
tar -xzf "$f"; cp tailscale_*_arm/tailscaled /usr/sbin/; cp tailscale_*_arm/tailscale /usr/bin/
# copy tailscale.init from this folder to /etc/init.d/tailscale, chmod 755, then:
/etc/init.d/tailscale enable; /etc/init.d/tailscale start
tailscale up --advertise-routes=192.168.1.0/24 --hostname=l71w --accept-dns=false
```

Open the printed link to log in, then in the Tailscale admin console approve the `192.168.1.0/24` route and disable key
expiry for the router. Add `/usr/sbin/tailscaled`, `/usr/bin/tailscale`, `/etc/init.d/tailscale` and `/etc/tailscale/`
to `/etc/sysupgrade.conf` to keep it across upgrades.
