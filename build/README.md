# How the release was built

## Sources (exact revisions)

| Tree | Repository | Commit |
|---|---|---|
| OpenWrt (PR #24057 head) | https://github.com/sanderpqr/openwrt (branch `checkpoint-l71`) | `72b9500ee163e4a0877ea01e4dd9d9f630c8fcc8` |
| packages feed | https://github.com/openwrt/packages | `5a7284c15af9074df840dfeb12b9b0d0f4e6a4e5` |
| luci feed | https://github.com/openwrt/luci | `4a3d16e914564ccf239802ad8dd57026c3860dd0` |
| routing feed | https://github.com/openwrt/routing | `ea8633da9c461a9bdc62a0323439d31180762e03` |

Because the pull-request branch may be rebased, the release also carries the source archives of these exact commits
(`openwrt.tar.gz`, `packages.tar.gz`, `luci.tar.gz`, `routing.tar.gz`, GitHub "archive" format).
Version string: `r38194-72b9500ee1`.

## Firmware image

[`build-l71w.sh`](build-l71w.sh) is the script that produced the release images (Ubuntu 24.04 in WSL2, as a normal
user). It takes one argument: a folder with the four source archives above. It unpacks them, links the feeds, adds
[`99-l71w-language`](99-l71w-language) (sets the LuCI language to Russian on first boot; drop it for English), writes
[`requested.config`](requested.config), runs `make defconfig`, checks that every requested option survived, and builds.
[`selected.config`](selected.config) is the resulting `diffconfig`.

## Extra packages (kernel modules) for this exact image

OpenWrt only accepts kernel modules whose `kernel` package matches the running image. The hash after the kernel
version (`6.18.60~e4fecbcbfe5c98cf96db934e2a417307`) is an md5 of every enabled kernel option, **including modules**.
Enabling more modules later changes the hash, so new `kmod-*` packages would refuse to install on the existing image.

To add modules without reflashing we pinned the hash, see [`vermagic-pin.diff`](vermagic-pin.diff), and enabled the
packages in [`extra-packages.config`](extra-packages.config) as `=m`. This is only safe if the built-in (`=y`) part of
the kernel does not change. We checked it before using the modules:

- `.config.set` of the kernel (the input the hash is computed from): no `=y` changes, only 14 new `=m` modules;
- the full kernel `.config` showed `RD_*`/`DECOMPRESS_*` differences, which turned out to be the difference between the
  initramfs and the normal kernel variant; the router's running kernel has those decompressors built in (`/proc/kallsyms`);
- `CONFIG_USB_SERIAL_GENERIC=y` belongs to the new `usbserial.ko` module itself.

On the router all 14 new modules load without "version magic" / "unknown symbol" errors.

Building more modules the same way: apply the diff, add `CONFIG_PACKAGE_kmod-…=m`, `make defconfig`,
`make target/linux/compile`, compare `=y` lines of `build_dir/target-*/linux-*/linux-6.18.60/.config.set` with the
original, and only then `make package/kernel/linux/compile`.
