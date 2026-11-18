# Example configuration

The configuration of our working L-71W, with personal data removed. Paths mirror the router's file system.
Use it as a reference or copy single files; do not copy everything over a fresh install blindly.

What is set up here compared with a fresh install:

| File | What it does |
|---|---|
| `etc/config/network` | DMZ port (`eth2`) added to the LAN bridge, so all 7 ports are LAN; WAN metric 10; backup uplinks `usbwan` (`usb0`, Android tethering, metric 20) and `usbwan_eth` (`eth3`, iPhone / HiLink modem, metric 21) |
| `etc/config/firewall` | stock OpenWrt firewall + `usbwan`, `usbwan_eth` in the `wan` zone (NAT) |
| `etc/config/wireless` | 2.4 GHz AP, WPA2-AES (`psk2+ccmp`), 802.11n HT20, auto channel limited to 1/6/11. **Placeholder SSID and password: change them.** |
| `etc/config/system` | time zone Europe/Kyiv, log on the microSD card, LEDs for Wi-Fi, Internet and USB |
| `etc/config/fstab` | microSD card mounted at `/mnt/sd` (put your card's UUID) |
| `etc/config/ksmbd` | SMB share `sd` on the card for user `home` (create the user and password, see [recipes](../recipes/README.md#microsd-card-network-folder-persistent-log-weekly-config-backup)) |
| `etc/config/p910nd` | USB printer on TCP 9100 |
| `etc/crontabs/root` | config backup to the card every Sunday 04:30, kept 60 days |
| `etc/hotplug.d/block/90-sd-led` | SD LED on while the card is present |
| `etc/init.d/wan-failover`, `usr/sbin/wan-failover` | failover to the phone/modem when the provider has no internet |
| `etc/init.d/tailscale` | Tailscale service (binaries are not included) |
| `etc/sysupgrade.conf` | keeps the files above across firmware upgrades |

Removed or replaced: the Wi-Fi name and password, the router name and description, MAC addresses (commented out; keep the
ones your router generated), the DHCPv6 DUID and IPv6 ULA prefix (your router generates its own), the card UUID, and the
logins/password databases (root, SMB, Home Assistant). The packages for printing, USB tethering and the USB LED are in
the release (`extra-packages-r38194.tar.gz`).

Applying a file, for example the wireless one:

```sh
scp -O example-config/etc/config/wireless root@192.168.1.1:/etc/config/wireless   # edit ssid/key first
ssh root@192.168.1.1 'wifi reload'
```
