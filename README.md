# OpenWrt MTK SDK Builder (OpenWrt 25.12, MT7988, BPI‑R4, 8GB RAM Support)

Debian based Docker image for building the MediaTek OpenWrt SDK against OpenWrt 25.12, with full support for the Banana Pi R4, including the 8GB RAM variant.

The image backports OpenWrt PR [#21437](https://github.com/openwrt/openwrt/pull/21437) by @frank-w (8GB DRAM support) into the OpenWrt 25.12 branch pre‑prepared with `autobuild.sh prepare`. The Dockerfile itself and the remaining patches, are based on the build scripts maintained by [@woziwrt](https://github.com/woziwrt/bpi-r4-6.12) and [@chenglong-do](https://github.com/chenglong-do/bpi-r4-openwrt-25.12-mtk)

All that is done here is to mix these and write it into a docker image for multi-platform usage, reproducibility and clean state management.

---

## Build the Docker Image

```sh
docker build --tag openwrt-mtk-builder_openwrt25.12_4bg .
```

---

## Run an Interactive Build Environment

```sh
docker run -it openwrt-mtk-builder_openwrt25.12_4bg bash
```
This drops you into a fully prepared OpenWrt/MTK SDK environment where you can rebuild, inspect logs, or modify configs.

From here you can run:
```sh
make menuconfig
```
to add/remove packages to the build.

## Build
To run the build:
```sh
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build
```

The final images will be located at:
```sh
/home/build/openwrt/bin/targets/mediatek/filogic
```

---

## Notes

- OpenWrt and MTK feed revisions are pinned.
- All modifications are applied via patches.
- The resulting images boot cleanly on the Banana Pi R4 (including the 8GB RAM model) for both: emmc and sdcard. **There is currently an issue when booting from NAND where the boot procedure hangs after loading the kernel with: "Waiting for root device: /dev/fit0"**. To fix this you can install only the sysupgrade squashfs part from openwrt online snapshots.
- This Docker image is developed and tested on macos M1, so it pulls Debian for ARM. Packages installed with `apt` may differ between ARM and x86 hosts.
- This repository is not intended to upstream or distribute any code or images; it provides a practical build environment to generate working images in multiple host architectures, without dealing with MTK SDK quirks.

## References
- https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/refs/heads/master/autobuild/unified/doc/MediaTek_OpenWrt_2512_User_Guide.md
- https://www.fw-web.de/dokuwiki/doku.php?id=en:bpi-r4:start
- https://forum.openwrt.org/t/banana-bpi-r4-all-related-to-mtk-sdk/221080
- https://www.openwrt.pro/post-640.html
- https://openwrt.org/inbox/toh/sinovoip/bananapi_bpi-r4
- https://forum.openwrt.org/t/tutorial-build-customize-and-use-mediatek-open-source-u-boot-and-atf/134897