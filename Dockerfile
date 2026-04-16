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
	echo 'echo 5' >> /usr/local/bin/nproc && \
	chmod +x /usr/local/bin/nproc

RUN useradd -m build
USER build

WORKDIR /home/build/

# Last verified working: 12e56ac8d4bc056768c962796f55531a6da2b4cf - mvebu: fix kmod for switch on clearfog base/pro
ENV OPENWRT_VER=12e56ac8d4bc056768c962796f55531a6da2b4cf
ENV OPENWRT_BRANCH=openwrt-25.12
# Last verified working: 14dc256bd536382ea427712eb3896e669beeae71 - [kernel-6.12][common][hnat][Add bridge forward 3-tuple HNAT offload support]
ENV MTK_FEEDS_VER=14dc256bd536382ea427712eb3896e669beeae71
ENV MTK_FEEDS_BRANCH=master

RUN git clone --branch ${OPENWRT_BRANCH} https://github.com/openwrt/openwrt.git openwrt && \
	cd openwrt && \
	git checkout ${OPENWRT_VER}

RUN git clone --branch ${MTK_FEEDS_BRANCH} https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds && \
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
COPY --chown=build:build assets/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12/
COPY --chown=build:build assets/9999-image-bpi-r4-sdcard.patch mtk-openwrt-feeds/25.12/patches-base/
COPY --chown=build:build assets/100-wifi-mt76-mt7996-Use-tx_power-from-default-fw-if-EEP.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/

# My patch tree on mtk SDK
COPY --chown=build:build assets/9999-wifi-mt76-mt7996-fix-FT-SAE-by-adding-BIP-batch-key-handling.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches/
COPY --chown=build:build assets/9999-netfilter-add-ttl-import.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/target/linux/mediatek/patches-6.12/
COPY --chown=build:build assets/99999-enable_8g_images_on_prepared_mtk_pr21437.patch mtk-openwrt-feeds/25.12/patches-base/
COPY --chown=build:build assets/usteer_Makefile /home/build/openwrt/package/network/services/usteer/Makefile
# Uncomment if assets/feed_revision was used above
#COPY --chown=build:build  assets/9999-remove-rust-llvm-dl.patch mtk-openwrt-feeds/25.12/patches-feeds/

WORKDIR /home/build/openwrt

RUN bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic prepare

COPY --chown=build:build assets/config .config

RUN make defconfig
# Run this in interactive mode to customize the image before building
# && \
#	bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build
