# OpenWrt для Check Point L-71W (1430/1450)

[English version](README.md)

Неофициальная сборка OpenWrt SNAPSHOT для **Check Point L-71W** — это «железо» продавалось как устройства
безопасности 1430/1450. В основе — заявка в OpenWrt [#24057](https://github.com/openwrt/openwrt/pull/24057) от
**Sander van Deijck**: она добавляет платформу Annapurna Labs Alpine и устройства Check Point L-71, L-71W и L-72.
На момент публикации заявка открыта и в OpenWrt не принята. Вся заслуга переноса — её автора и тестировщиков.

Что здесь добавлено:

- готовая к прошивке сборка этой заявки с полезным набором пакетов (LuCI по HTTPS, WireGuard, SQM, сервер SMB,
  ext4 и USB-накопители);
- инструкция по установке по реальной прошивке **через консоль mini-USB**;
- дополнительные модули ядра именно для этого образа (USB-принтер, USB-модемы и раздача с телефона, индикатор USB);
- небольшие [рецепты](recipes/README.md) (на английском): индикаторы, сетевая папка на microSD, принт-сервер,
  запасной интернет через телефон с автоматическим переключением, удалённый доступ через Tailscale;
- [настройки нашего рабочего роутера](example-config/README.md) (на английском) без личных данных: имя сети и пароль
  Wi-Fi заменены на `SSID` / `1234567890`, MAC-адреса и уникальные идентификаторы убраны, пароли не включены.

> **Без гарантий.** Это снимок из непринятой заявки. Прошивка заменяет ПО Check Point. Сначала сделайте резервную
> копию (ниже). Возврат на заводскую прошивку **не проверялся**.

## Железо

По данным заявки:

| | |
|---|---|
| Процессор | Annapurna Labs AL21200, 2 ядра Cortex-A15, 1,7 ГГц |
| ОЗУ / флеш | 1 ГиБ DDR3 / 1 ГиБ NAND |
| Ethernet | WAN, DMZ, 6× LAN (коммутатор Marvell 88E6172) |
| Wi-Fi | Qualcomm Atheros QCA9880 (802.11ac), один радиомодуль: **2,4 ГГц или 5 ГГц, не оба сразу** |
| USB | Renesas µPD720202 USB 3.0, один порт USB-A |
| Картридер | microSD (внутренний USB-картридер) |
| Консоль | 115200 8N1 на mini-USB и RJ-45 |

Имена портов в OpenWrt: WAN = `eth0`, DMZ = `eth2`, LAN1–LAN6 = `lan1`…`lan6`.

## Скачать

В разделе [Releases](https://github.com/PodaVV/openwrt-checkpoint-l71w/releases):

| Файл | Что это |
|---|---|
| `openwrt-alpine-al21200-checkpoint_l-71w-initramfs-kernel.bin` | образ, который работает из ОЗУ; передаётся по YMODEM при первой установке |
| `openwrt-alpine-al21200-checkpoint_l-71w-squashfs-sysupgrade.bin` | прошивка, которая пишется в NAND |
| `extra-packages-r38194.tar.gz` | 41 дополнительный пакет для этого образа (ниже) |
| `openwrt.tar.gz`, `packages.tar.gz`, `luci.tar.gz`, `routing.tar.gz` | исходный код именно тех коммитов, из которых собрано |
| `*.manifest`, `*.buildinfo`, `SHA256SUMS` | список пакетов, сведения о сборке, контрольные суммы |

Сборка: OpenWrt SNAPSHOT `r38194-72b9500ee1`, Linux 6.18.60, собрана 10.11.2026. Как собиралась —
[build/README.md](build/README.md) (на английском).

## Что в прошивке

Сверх стандартного набора OpenWrt для этого устройства: `luci-ssl`, `luci-app-firewall`, `luci-app-package-manager`,
`wireguard-tools` + `luci-proto-wireguard`, `sqm-scripts` + `luci-app-sqm` + `kmod-sched-cake`, `ksmbd-server` +
`luci-app-ksmbd`, `block-mount`, `e2fsprogs`, `kmod-fs-ext4`, `kmod-usb-storage-uas`, `htop`, русский перевод LuCI.
Полный список — в файле `.manifest` в выпуске.

Язык LuCI при первом запуске ставится **русский**; сменить — *Система → Система → Язык и оформление*.
Остальное по умолчанию как в OpenWrt: LAN `192.168.1.1/24` на портах LAN1–LAN6, WAN получает адрес по DHCP, DMZ не
настроен, Wi-Fi выключен, **пароля root нет** — задайте его сразу (`passwd` или по подсказке в LuCI).

## Что проверено на нашем экземпляре

| Что | Итог |
|---|---|
| Установка через консоль mini-USB (FTDI, появляется как COM-порт), YMODEM, sysupgrade в NAND | ✅ 10.11.2026 |
| Загрузка из NAND, перезагрузки, `sysupgrade` с сохранением настроек | ✅ |
| WAN по DHCP, NAT на LAN и Wi-Fi | ✅ |
| Порты LAN | ✅ через LAN передавали образ; каждый порт отдельно не проверяли |
| Точка доступа Wi-Fi 2,4 ГГц, WPA2, 802.11n | ✅ поднимается; скорость клиентов не мерили |
| Wi-Fi в режиме клиента | ✅ подключались к другой сети, интернет был |
| Wi-Fi 5 ГГц | ⬜ не проверяли (с ним генерируется исходная настройка радио) |
| Карта microSD (ext4, 32 ГБ) | ✅ |
| USB-принтер как сетевой (Kyocera FS-1041, p910nd) | ✅ с доп. пакетами, пробная страница напечатана |
| Раздача интернета с Android по USB как запасной канал, автопереключение | ✅ с доп. пакетами (Pixel, `cdc_ncm`) |
| Индикаторы Wi-Fi, Internet, USB, SD | ✅ по [рецептам](recipes/README.md#leds) |
| Tailscale (userspace, раздача домашней сети) | ✅ см. [рецепты](recipes/README.md#remote-access-with-tailscale-no-public-ip-needed) |
| Общая папка SMB на карте | ⚠️ сервер работает, вход с клиента не проверяли |
| WireGuard, SQM | ⚠️ установлены, мы их не настраивали |
| Раздача с iPhone, USB-модемы LTE | ⚠️ драйверы есть, не проверяли |
| Кнопки сброса и перезагрузки | ⬜ не проверяли |
| Возврат на заводскую прошивку Check Point | ⬜ **не проверяли** |

Что заметили:

- При загрузке `rtc-ds1307: hctosys: unable to read the hardware clock`. У нас время приходит по NTP после загрузки.
- `xhci-pci-renesas: failed to load firmware renesas_usb_fw.mem, fallback to ROM` — не страшно, USB работает из ROM.
- Принтер, переставленный с ПК на роутер, не определялся (`error -71`), пока его не выключили и не включили.
- На «авто» радио выбрало канал 13, а часть устройств каналы 12–13 не видит. Мы ограничили авто каналами 1/6/11
  (`uci set wireless.radio0.channels='1 6 11'`).

## Установка

Понадобится: ПК с Windows или Linux; кабель mini-USB в порт CONSOLE (или консольный кабель Cisco RJ-45 с переходником
USB-RS232); программа терминала с передачей по YMODEM (Tera Term на Windows, `minicom` + `lrzsz` на Linux); сетевой
кабель. Заложите около часа: одна передача по YMODEM идёт около 10 минут.

### 1. Сохраните заводскую прошивку

До любых изменений сохраните то, что понадобится для возврата:

- переменные загрузчика: `fw_printenv` (запишите `bootcmd`; у нас было `run tf1_image2`);
- таблицу разделов: `cat /proc/mtd`;
- лучше всего — полный снимок всех разделов NAND (`nanddump`) на флешку или ПК и заводскую конфигурацию.

Мы полный снимок сохранили, но **восстановление заводской прошивки ни разу не проверялось**.

### 2. Войдите в оболочку Maintenance Mode

Шаги из заявки (коммит `aa655bde57`, раздел «Installation»):

1. Подключитесь к консоли, 115200 8N1. В Windows консоль mini-USB появляется как новый COM-порт (FTDI USB serial);
   при необходимости поставьте драйвер FTDI.
2. Включите роутер и прервите загрузку **Ctrl+C**, когда будет предложено.
3. Выберите пункт **3, «Start in Maintenance Mode»**. При первом входе может попросить задать пароль.
4. Дождитесь оболочки:

   ```
   [Expert@MAINTENANCE_MODE]#
   ```

### 3. Научите U-Boot грузить OpenWrt из NAND, а при неудаче — принимать образ по YMODEM

```sh
fw_setenv bootcmd 'nand read.e 0x8000000 0x380000 0x1000000; bootm 0x8000000; loady 0x8000000; bootm 0x8000000; run tf1_image2'
fw_printenv bootcmd     # проверить
reboot
```

В NAND ещё нет OpenWrt, поэтому U-Boot сообщит, что готов принять файл по YMODEM на 115200.

### 4. Передайте образ initramfs по YMODEM

Переименуйте образ initramfs в `initramfs.bin`: некоторые программы не справляются с длинным именем. В Tera Term:
*File → Transfer → YMODEM → Send*. Передача идёт около 10 минут, прерывать нельзя. Затем OpenWrt загрузится из ОЗУ.

> Мы при первой установке использовали образ initramfs, опубликованный автором заявки. Образ initramfs из этого выпуска
> собран из тех же исходников и с той же настройкой, но мы его на железе не запускали. Он нужен только для шага 5,
> поэтому подойдёт любой initramfs этой ревизии для L-71W.

### 5. Запишите прошивку в NAND

Подключите ПК к порту LAN — он получит адрес от OpenWrt (192.168.1.x). Скопируйте образ sysupgrade и прошейте без
сохранения настроек (`-n`, сохранять ещё нечего):

```sh
# на ПК
scp -O openwrt-alpine-al21200-checkpoint_l-71w-squashfs-sysupgrade.bin root@192.168.1.1:/tmp/fw.bin
# на роутере (консоль или ssh root@192.168.1.1)
sha256sum /tmp/fw.bin          # сравнить с SHA256SUMS
sysupgrade -T /tmp/fw.bin      # проверка, должна пройти
sysupgrade -n /tmp/fw.bin
```

Роутер перезагрузится через U-Boot и запустит OpenWrt из NAND. Проверьте `cat /proc/mounts`: `/rom` — squashfs,
`/overlay` — UBIFS. Если NAND когда-нибудь перестанет загружаться, запасной вариант в `bootcmd` вернёт вас к шагу 4.

Дальнейшие обновления — обычный sysupgrade OpenWrt (LuCI *Система → Резервное копирование / прошивка* или `sysupgrade`).

## Дополнительные пакеты

У прошивки нет хранилища пакетов: официальные пакеты OpenWrt к непринятой платформе не подходят, а модули ядра должны
совпадать именно с этим ядром (`kernel=6.18.60~e4fecbcbfe5c98cf96db934e2a417307`). В `extra-packages-r38194.tar.gz` —
41 пакет, собранный в том же дереве:

- печать: `kmod-usb-printer`, `p910nd`, `luci-app-p910nd` (+ русский перевод);
- индикатор USB: `kmod-usb-ledtrig-usbport`;
- телефоны и модемы: `kmod-usb-net-rndis`, `-cdc-ether`, `-cdc-ncm`, `-huawei-cdc-ncm`, `-ipheth`, `-qmi-wwan`,
  `-cdc-mbim`, `kmod-usb-serial-option`, `usbmuxd` (iPhone), `uqmi`, `umbim`, `comgt`, `usb-modeswitch`,
  `luci-proto-3g/ncm/qmi/mbim` и их зависимости.

Установка:

```sh
# скопировать архив на роутер, например scp -O extra-packages-r38194.tar.gz root@192.168.1.1:/tmp/
cd /tmp && mkdir extra && tar -xzf extra-packages-r38194.tar.gz -C extra
apk add --allow-untrusted extra/*.apk
```

Пакеты не подписаны ключом OpenWrt, поэтому `--allow-untrusted`. Сохраните их копию (например, на карту microSD):
обновление прошивки сохраняет настройки, но не установленные пакеты.

## Собрать самому

См. [build/README.md](build/README.md): точные коммиты исходников, сценарий и настройка сборки, и как собирались
дополнительные модули ядра для уже установленного образа.

## Лицензии и благодарности

- Перенос OpenWrt на платформу Alpine и Check Point L-71/L-71W/L-72 — Sander van Deijck,
  [openwrt/openwrt#24057](https://github.com/openwrt/openwrt/pull/24057); там же благодарность Julia Kittlinger за
  исходники Check Point и тестировщикам.
- OpenWrt и его пакеты — под своими лицензиями (в основном GPL-2.0); исходный код использованных коммитов — в выпуске.
- Тексты и сценарии этого репозитория — под GPL-2.0, см. [LICENSE](LICENSE).
- Check Point — товарный знак Check Point Software Technologies Ltd. Проект не связан ни с Check Point, ни с OpenWrt.
