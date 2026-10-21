FROM debian:13.4

LABEL org.opencontainers.image.authors="andmor-"

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get -qq install -y --no-install-recommends \
		build-essential \
		clang \
		curl \
		flex \
		bison \
		g++ \
		gawk \
		gcc \
		gettext \
		git \
		libncurses-dev \
		libssl-dev \
		python3-distutils-extra \
		python3-setuptools \
		rsync \
		unzip \
		zlib1g-dev \
		swig \
		file \
		wget \
		libpython3-dev \
		aria2 \
		jq \
		subversion \
		qemu-utils \
		ccache \
		rename \
		libelf-dev \
		vim \
		golang && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

# Docker exposes the total number of cores of the host in nproc -> set a reasonable nproc number for autobuild
RUN echo '#!/bin/sh' > /usr/local/bin/nproc && \
	echo 'echo 16' >> /usr/local/bin/nproc && \
	chmod +x /usr/local/bin/nproc

RUN useradd -m build
USER build

WORKDIR /home/build/

# Last verified working: 64900e756efa667774214f9c6b17c113222e01f7 - OpenWrt v25.12.6: adjust config defaults
ENV OPENWRT_VER=64900e756efa667774214f9c6b17c113222e01f7
ENV OPENWRT_BRANCH=openwrt-25.12
# Last verified working: a50e2e2c4550e5db65709e419e66cac0ee65147b - [kernel-6.12][common][hnat][Add a hash collision packet counter to the hnat_entry debugfs node]
ENV MTK_FEEDS_VER=a50e2e2c4550e5db65709e419e66cac0ee65147b
ENV MTK_FEEDS_BRANCH=main

RUN git clone --branch ${OPENWRT_BRANCH} https://github.com/openwrt/openwrt.git openwrt && \
	cd openwrt && \
	git checkout ${OPENWRT_VER}

RUN git clone --branch ${MTK_FEEDS_BRANCH} https://github.com/mediatek/mtk-openwrt-feeds.git && \
	cd mtk-openwrt-feeds && \
	git checkout ${MTK_FEEDS_VER}

RUN cd openwrt && \
	./scripts/feeds update -a && \
	./scripts/feeds install -a

# Backup patches and config to use after make clean in interatcive mode
COPY --chown=build:build assets/ ./assets

# Uncomment to use last known working version of feeds
#COPY --chown=build:build  assets/feed_revision mtk-openwrt-feeds/autobuild/unified/

# Community patches
### SFP quirks
COPY --chown=build:build assets/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12/
### GbE switch LEDs overlay. ref: https://github.com/woziwrt/bpi-r4-deploy/pull/11
COPY --chown=build:build assets/470-w-add-bpi-r4-leds-overlay.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12/
COPY --chown=build:build assets/471-w-bpi-r4-led-uboot.patch mtk-openwrt-feeds/25.12/files/package/boot/uboot-mediatek/patches/
### Per-band WiFi LED (MT7996, single-wiphy MLO) + shared tpt trigger. ref: https://lore.kernel.org/linux-wireless/20260714102615.2943-1-petr.wozniak@gmail.com/
COPY --chown=build:build assets/999-wifi-01-mt7996-per-band-leds.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/
COPY --chown=build:build assets/999-wifi-02-mt76-share-tpt-led-trigger.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/

COPY --chown=build:build assets/9999-image-bpi-r4-sdcard.patch mtk-openwrt-feeds/25.12/patches-base/
### Fix zeroed tx power. ref: https://github.com/openwrt/mt76/pull/968
COPY --chown=build:build assets/100-wifi-mt76-mt7996-Use-tx_power-from-default-fw-if-EEP.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/

# My patch tree on mtk SDK
### Fix 802.11r FT. ref: https://github.com/openwrt/mt76/pull/1071
COPY --chown=build:build assets/9999-wifi-mt76-mt7996-fix-FT-SAE-by-adding-BIP-batch-key-handling.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/
### Fix missing include
COPY --chown=build:build assets/9999-netfilter-add-ttl-import.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/target/linux/mediatek/patches-6.12/
### Add 8GB RAM support
COPY --chown=build:build assets/99999-enable_8g_images_on_prepared_mtk_pr21437.patch mtk-openwrt-feeds/25.12/patches-base/
### Add GbE LEDs overlay to filogic DTS. ref: https://github.com/woziwrt/bpi-r4-deploy/pull/11
COPY --chown=build:build assets/999999-add_leds_overlay_to_mtk_dts.patch mtk-openwrt-feeds/25.12/patches-base/

# Custom makefile for usteer
COPY --chown=build:build assets/usteer_Makefile /home/build/openwrt/feeds/packages/net/usteer/Makefile

# Uncomment if assets/feed_revision was used above
#COPY --chown=build:build  assets/9999-remove-rust-llvm-dl.patch mtk-openwrt-feeds/25.12/patches-feeds/

WORKDIR /home/build/openwrt

RUN bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic prepare

# Enable GbE LED trigger. See: https://github.com/woziwrt/bpi-r4-deploy/pull/11
RUN echo "CONFIG_LED_TRIGGER_PHY=y" >> target/linux/mediatek/filogic/config-6.12 && \
    mkdir -p files/etc/init.d && \
    mkdir -p files/etc/uci-defaults
COPY --chown=build:build assets/files/etc/init.d/mtk-led-fix files/etc/init.d/
COPY --chown=build:build assets/files/etc/init.d/fancontrol files/etc/init.d/
COPY --chown=build:build assets/files/etc/uci-defaults/95-mtk-led-fix-enable files/etc/uci-defaults/
COPY --chown=build:build assets/files/etc/uci-defaults/95-fancontrol-enable files/etc/uci-defaults/

COPY --chown=build:build assets/config .config

RUN make defconfig
# Run this in interactive mode to customize the image before building
# && \
#	bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build
