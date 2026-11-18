# OpenWrt for Check Point L-71W (1430/1450)

[Русская версия](README.ru.md)

An unofficial OpenWrt SNAPSHOT build for the **Check Point L-71W**, the hardware sold as the 1430/1450 security
appliances. It is based on the OpenWrt pull request
[#24057](https://github.com/openwrt/openwrt/pull/24057) by **Sander van Deijck**, which adds the Annapurna Labs
Alpine target and the Check Point L-71, L-71W and L-72. At the time of writing the pull request is still open and not
merged. All credit for the port goes to its author and testers.

This repository adds:

- a ready-to-flash build of that pull request with a useful package set (LuCI over HTTPS, WireGuard, SQM, SMB server,
  ext4/USB storage);
- an installation guide based on a real flash over the **mini-USB console**;
- extra kernel modules for this exact image (USB printer, USB modems and phone tethering, USB LED trigger);
- small [recipes](recipes/README.md): front-panel LEDs, microSD network folder, USB print server, backup internet over a
  phone with automatic failover, remote access with Tailscale.

> **No warranty.** This is a snapshot from an unmerged pull request. Flashing replaces the Check Point firmware.
> Back up first (see below). We have **not** tested going back to the stock firmware.

## Hardware

From the pull request:

| | |
|---|---|
| SoC | Annapurna Labs AL21200, dual-core Cortex-A15 @ 1.7 GHz |
| RAM / flash | 1 GiB DDR3 / 1 GiB NAND |
| Ethernet | WAN, DMZ, 6× LAN (Marvell 88E6172 switch) |
| Wi-Fi | Qualcomm Atheros QCA9880 (802.11ac), one radio: **2.4 GHz or 5 GHz, not both at once** |
| USB | Renesas µPD720202 USB 3.0, one USB-A port |
| Card reader | microSD (internal USB card reader) |
| Console | 115200 8N1 on mini-USB and RJ-45 |

Interface names in OpenWrt: WAN = `eth0`, DMZ = `eth2`, LAN1–LAN6 = `lan1`…`lan6`.

## Downloads

See [Releases](https://github.com/PodaVV/openwrt-checkpoint-l71w/releases):

| File | What it is |
|---|---|
| `openwrt-alpine-al21200-checkpoint_l-71w-initramfs-kernel.bin` | image that runs from RAM, sent over YMODEM for the first install |
| `openwrt-alpine-al21200-checkpoint_l-71w-squashfs-sysupgrade.bin` | the firmware written to NAND |
| `extra-packages-r38194.tar.gz` | 41 extra packages for this image (see below) |
| `openwrt.tar.gz`, `packages.tar.gz`, `luci.tar.gz`, `routing.tar.gz` | source code of the exact commits used |
| `*.manifest`, `*.buildinfo`, `SHA256SUMS` | package list, build info, checksums |

Build: OpenWrt SNAPSHOT `r38194-72b9500ee1`, Linux 6.18.60, built on 10 Nov 2026. How it was built:
[build/README.md](build/README.md).

## What is in the firmware

On top of the default OpenWrt set for this device: `luci-ssl`, `luci-app-firewall`, `luci-app-package-manager`,
`wireguard-tools` + `luci-proto-wireguard`, `sqm-scripts` + `luci-app-sqm` + `kmod-sched-cake`, `ksmbd-server` +
`luci-app-ksmbd`, `block-mount`, `e2fsprogs`, `kmod-fs-ext4`, `kmod-usb-storage-uas`, `htop`, Russian translations of
LuCI. The full list is in the `.manifest` file of the release.

The LuCI language is set to **Russian** on first boot. Switch to English in *System → System → Language and Style*.
Defaults are standard OpenWrt: LAN `192.168.1.1/24` on LAN1–LAN6, WAN = DHCP client, DMZ not configured, Wi-Fi off,
**no root password**, so set one right away (`passwd`, or the LuCI banner).

## What we tested on our unit

| Feature | Status |
|---|---|
| Install over the mini-USB console (FTDI, appears as a COM port), YMODEM, sysupgrade to NAND | ✅ 10 Nov 2026 |
| Boot from NAND, reboots, `sysupgrade` with kept settings | ✅ |
| WAN as DHCP client, NAT to LAN and Wi-Fi | ✅ |
| LAN ports | ✅ used to transfer the image; not every port was checked |
| Wi-Fi access point 2.4 GHz, WPA2, 802.11n | ✅ comes up; client speed not measured |
| Wi-Fi client (station) mode | ✅ joined another network, got internet |
| Wi-Fi 5 GHz | ⬜ not tested (it is the default the radio config is generated with) |
| microSD card (ext4, 32 GB) | ✅ |
| USB printer as a network printer (Kyocera FS-1041, p910nd) | ✅ with extra packages, test page printed |
| Android USB tethering as backup internet, automatic failover | ✅ with extra packages (Pixel, `cdc_ncm`) |
| LEDs: Wi-Fi, Internet, USB, SD | ✅ with [recipes](recipes/README.md#leds) |
| Tailscale (userspace networking, subnet router) | ✅ see [recipes](recipes/README.md#remote-access-with-tailscale-no-public-ip-needed) |
| SMB share on the microSD card | ⚠️ server runs; access from a client not tested |
| WireGuard, SQM | ⚠️ installed, not configured by us |
| iPhone tethering, USB LTE modems | ⚠️ drivers included, not tested |
| Reset / reboot buttons | ⬜ not tested |
| Returning to the stock Check Point firmware | ⬜ **not tested** |

Things we noticed:

- `rtc-ds1307: hctosys: unable to read the hardware clock` at boot. On our unit the clock comes from NTP after boot.
- `xhci-pci-renesas: failed to load firmware renesas_usb_fw.mem, fallback to ROM`: harmless, USB works from the ROM.
- After moving a printer from a PC to the router it was not detected (`error -71`) until we power-cycled the printer.
- The Wi-Fi radio picked channel 13 on "auto". Some devices do not see channels 12–13; we limited auto to 1/6/11
  (`uci set wireless.radio0.channels='1 6 11'`).

## Installation

What you need: a PC with Windows or Linux; a mini-USB cable for the CONSOLE port (or a Cisco RJ-45 console cable with
a USB-RS232 adapter); a terminal that can send YMODEM (Tera Term on Windows, `minicom` + `lrzsz` on Linux); a network
cable. Plan about an hour: the YMODEM transfer alone takes about 10 minutes.

### 1. Back up the stock firmware

Before changing anything, save what you would need to go back:

- the boot environment: `fw_printenv` (write down `bootcmd`; ours was `run tf1_image2`);
- the partition table: `cat /proc/mtd`;
- ideally a full dump of every NAND partition (`nanddump`) to a USB stick or PC, and the stock configuration.

We kept a full dump, but **restoring the stock firmware was never tested**.

### 2. Get a shell in Maintenance Mode

These steps are from the pull request (commit `aa655bde57`, "Installation"):

1. Connect to the console at 115200 8N1. On Windows the mini-USB console appears as a new COM port
   (FTDI USB serial); install the FTDI driver if needed.
2. Power on and interrupt the boot with **Ctrl+C** when prompted.
3. Choose option **3, "Start in Maintenance Mode"**. On first boot it may ask you to create a password.
4. Wait for the shell:

   ```
   [Expert@MAINTENANCE_MODE]#
   ```

### 3. Make U-Boot boot OpenWrt from NAND, with YMODEM as fallback

```sh
fw_setenv bootcmd 'nand read.e 0x8000000 0x380000 0x1000000; bootm 0x8000000; loady 0x8000000; bootm 0x8000000; run tf1_image2'
fw_printenv bootcmd     # check it
reboot
```

U-Boot finds no OpenWrt in NAND yet and says it is ready for a YMODEM download at 115200.

### 4. Send the initramfs image over YMODEM

Rename the initramfs image to `initramfs.bin`, because some programs fail on the long name. In Tera Term:
*File → Transfer → YMODEM → Send*. It takes about 10 minutes; do not interrupt it. OpenWrt then boots from RAM.

> Note: for our first install we used the initramfs image published by the pull-request author. The initramfs from this
> release is built from the same sources and configuration but was not booted on hardware by us. It is only used to run
> step 5, so any initramfs of this revision for the L-71W will do.

### 5. Write the firmware to NAND

Connect the PC to a LAN port; it gets an address from OpenWrt (192.168.1.x). Copy the sysupgrade image and flash it
without keeping settings (`-n`, there is nothing to keep yet):

```sh
# on the PC
scp -O openwrt-alpine-al21200-checkpoint_l-71w-squashfs-sysupgrade.bin root@192.168.1.1:/tmp/fw.bin
# on the router (console or ssh root@192.168.1.1)
sha256sum /tmp/fw.bin          # compare with SHA256SUMS
sysupgrade -T /tmp/fw.bin      # test, must pass
sysupgrade -n /tmp/fw.bin
```

The router reboots through U-Boot and starts OpenWrt from NAND. Check with `cat /proc/mounts` that `/rom` is squashfs and
`/overlay` is UBIFS. If NAND ever becomes unbootable, the fallback in `bootcmd` brings you back to step 4.

Later upgrades are normal OpenWrt sysupgrades (LuCI *System → Backup / Flash Firmware*, or `sysupgrade` in the shell).

## Extra packages

The image has no package repository: official OpenWrt packages do not fit an unmerged target, and kernel modules must
match this exact kernel (`kernel=6.18.60~e4fecbcbfe5c98cf96db934e2a417307`). `extra-packages-r38194.tar.gz` contains
41 packages built from the same tree:

- printing: `kmod-usb-printer`, `p910nd`, `luci-app-p910nd` (+ Russian translation);
- USB LED trigger: `kmod-usb-ledtrig-usbport`;
- phones and modems: `kmod-usb-net-rndis`, `-cdc-ether`, `-cdc-ncm`, `-huawei-cdc-ncm`, `-ipheth`, `-qmi-wwan`,
  `-cdc-mbim`, `kmod-usb-serial-option`, `usbmuxd` (iPhone), `uqmi`, `umbim`, `comgt`, `usb-modeswitch`,
  `luci-proto-3g/ncm/qmi/mbim`, and their dependencies.

Install:

```sh
# copy the archive to the router, e.g. scp -O extra-packages-r38194.tar.gz root@192.168.1.1:/tmp/
cd /tmp && mkdir extra && tar -xzf extra-packages-r38194.tar.gz -C extra
apk add --allow-untrusted extra/*.apk
```

The packages are not signed with an OpenWrt key, hence `--allow-untrusted`. Keep a copy (for example on the microSD
card): a firmware upgrade keeps settings but not installed packages.

## Building it yourself

See [build/README.md](build/README.md): exact source commits, the build script and configuration, and how the extra
kernel modules were built for the existing image.

## License and credits

- The OpenWrt port for the Alpine target and the Check Point L-71/L-71W/L-72: Sander van Deijck,
  [openwrt/openwrt#24057](https://github.com/openwrt/openwrt/pull/24057), with thanks there to Julia Kittlinger for the
  Check Point source code and to the testers.
- OpenWrt and its packages are under their own licenses (mostly GPL-2.0); the source code of the exact commits is in
  the release.
- The documents and scripts in this repository are under GPL-2.0, see [LICENSE](LICENSE).
- Check Point is a trademark of Check Point Software Technologies Ltd. This project is not affiliated with Check Point
  or with the OpenWrt project.
