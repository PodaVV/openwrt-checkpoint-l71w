#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export TZ=UTC
stage="$1"
src="$HOME/openwrt"
feeds="$HOME/l71w-feeds"
mkdir "$src" "$feeds"
extract() {
    local name="$1" path="$2" sha="$3"
    local archive="$stage/$name.tar.gz"
    tar -tzf "$archive" > "$HOME/$name.archive-list"
    grep -Fxq "$name-$sha/" "$HOME/$name.archive-list"
    tar --strip-components=1 -xzf "$archive" -C "$path"
}
extract openwrt "$src" 72b9500ee163e4a0877ea01e4dd9d9f630c8fcc8
for line in 'packages 5a7284c15af9074df840dfeb12b9b0d0f4e6a4e5' 'luci 4a3d16e914564ccf239802ad8dd57026c3860dd0' 'routing ea8633da9c461a9bdc62a0323439d31180762e03'; do
    read -r feed sha <<<"$line"
    mkdir "$feeds/$feed"
    extract "$feed" "$feeds/$feed" "$sha"
    if [[ "$feed" == luci ]]; then
        git -C "$feeds/$feed" init -q -b build/l71w
        git -C "$feeds/$feed" remote add origin https://github.com/openwrt/luci.git
        git -C "$feeds/$feed" -c protocol.version=2 fetch -q --filter=blob:none --depth=3500 origin "$sha"
        git -C "$feeds/$feed" reset -q --mixed FETCH_HEAD
        test "$(git -C "$feeds/$feed" rev-parse HEAD)" = "$sha"
    fi
    echo "src-link $feed $feeds/$feed" >>"$src/feeds.conf"
done
cd "$src"
test ! -e version
echo 'r38194-72b9500ee1' > version
echo 1794177024 > version.date
./scripts/feeds update -a >"$HOME/feed-update.log" 2>&1
./scripts/feeds install -a >"$HOME/feed-install.log" 2>&1
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-l71w-language <<'EOF'
#!/bin/sh
case "$(uci -q get luci.main.lang)" in
    auto|'') uci set luci.main.lang=ru && uci commit luci ;;
esac
EOF
chmod 755 files/etc/uci-defaults/99-l71w-language
cat > .config <<'EOF'
CONFIG_TARGET_alpine=y
CONFIG_TARGET_alpine_al21200=y
CONFIG_TARGET_alpine_al21200_DEVICE_checkpoint_l-71w=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_apk-mbedtls=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_luci-app-ksmbd=y
CONFIG_PACKAGE_ksmbd-server=y
CONFIG_PACKAGE_htop=y
CONFIG_LUCI_LANG_ru=y
CONFIG_PACKAGE_luci-i18n-base-ru=y
CONFIG_PACKAGE_luci-i18n-firewall-ru=y
CONFIG_PACKAGE_luci-i18n-package-manager-ru=y
CONFIG_PACKAGE_luci-i18n-sqm-ru=y
CONFIG_PACKAGE_luci-i18n-ksmbd-ru=y
EOF
cp .config "$HOME/requested.config"
make defconfig >"$HOME/defconfig.log" 2>&1
while IFS= read -r line; do grep -Fxq "$line" .config || { echo "Unresolved config $line"; exit 2; }; done <"$HOME/requested.config"
echo CONFIG_OK
./scripts/diffconfig.sh >"$HOME/selected.config"
make -j8 download >"$HOME/download.log" 2>&1
echo SOURCES_DOWNLOADED
make -j6 V=s >"$HOME/compile.log" 2>&1
echo BUILD_OK
