COMPILE_NS_USER ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER ?= 64
COMPILE_S_KERNEL ?= 64

# 项目配置
TOP_DIR          := $(shell pwd)
OUTPUT_DIR       := $(TOP_DIR)/build
TF_A_PATH        := $(TOP_DIR)/atf
BL31_PATH        := $(TF_A_PATH)/build/rk3588/debug/bl31
UBOOT_PATH       := $(TOP_DIR)/u-boot
OPTEE_OS_PATH    := $(TOP_DIR)/optee_os
TEE_BIN          := $(OPTEE_OS_PATH)/out/arm-plat-rockchip/core
RKBIN_BIN        := $(TOP_DIR)/rkbin
SPL_BIN          := $(UBOOT_PATH)/spl/u-boot-spl.bin
TPL_BIN          := $(RKBIN_BIN)/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin
UBUNTU_IMG_XZ    := $(TOP_DIR)/ubuntu-22.04-preinstalled-server-arm64-rock-5b.img.xz
UBUNTU_IMG       := $(TOP_DIR)/ubuntu-22.04-preinstalled-server-arm64-rock-5b.img
MANIFEST_XML     := $(TOP_DIR)/manifest.xml
TF_A_VERSION      := $(shell xmllint --xpath 'string(//project[@path="trusted-firmware-a"]/@revision)' $(MANIFEST_XML) 2>/dev/null)
OPTEE_VERSION     := $(shell xmllint --xpath 'string(//project[@path="optee_os"]/@revision)' $(MANIFEST_XML) 2>/dev/null)
UBOOT_VERSION     := $(shell xmllint --xpath 'string(//project[@path="u-boot"]/@revision)' $(MANIFEST_XML) 2>/dev/null)
UBUNTU_IMG_VERSION := $(shell xmllint --xpath 'string(//project[@path="ubuntu-image"]/@revision)' $(MANIFEST_XML) 2>/dev/null)

CROSS_COMPILE    ?= aarch64-linux-gnu-
ARCH             ?= arm
# 输出文件
BL31_ELF         := $(OUTPUT_DIR)/bl31.elf
TEE_BIN_OUT      := $(OUTPUT_DIR)/tee.bin
IDBLOADER_IMG    := $(OUTPUT_DIR)/idbloader.img
UBOOT_ITB        := $(OUTPUT_DIR)/u-boot.itb

# 默认目标
.PHONY: all
all: check-toolchain download-sources check-env atf optee uboot ubuntu-image
	@echo "=== 所有组件构建完成 ==="
	@echo "输出文件在: $(OUTPUT_DIR)"
	@ls -la $(OUTPUT_DIR)/
	
################################################################################
# 下载源代码
################################################################################
.PHONY: download-sources
download-sources: download-rkbin download-atf download-optee download-uboot download-ubuntu

.PHONY: download-rkbin
download-rkbin:
	@echo "=== 下载 rkbin ==="
	@if [ ! -d "$(RKBIN_BIN)" ]; then \
		echo "克隆 rkbin..."; \
		git clone https://github.com/rockchip-linux/rkbin.git $(RKBIN_BIN); \
		echo "rkbin 下载完成"; \
	else \
		echo "rkbin 已存在，跳过下载"; \
	fi

.PHONY: download-atf
download-atf:
	@echo "=== 下载 TF-A (版本: $(TF_A_VERSION)) ==="
	@if [ -z "$(TF_A_VERSION)" ]; then \
		echo "错误: 无法从 manifest.xml 获取 TF-A 版本"; \
		exit 1; \
	fi
	@if [ ! -d "$(TF_A_PATH)" ]; then \
		echo "克隆 TF-A ($(TF_A_VERSION))..."; \
		git clone -b $(TF_A_VERSION) https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git $(TF_A_PATH); \
		echo "TF-A 下载完成"; \
	else \
		echo "TF-A 已存在，检查版本..."; \
		cd $(TF_A_PATH) && \
		current_branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
		current_commit=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
		echo "当前分支: $$current_branch, 提交: $$current_commit"; \
		echo "目标版本: $(TF_A_VERSION)"; \
	fi

.PHONY: download-optee
download-optee:
	@echo "=== 下载 OP-TEE (版本: $(OPTEE_VERSION)) ==="
	@if [ -z "$(OPTEE_VERSION)" ]; then \
		echo "错误: 无法从 manifest.xml 获取 OP-TEE 版本"; \
		exit 1; \
	fi
	@if [ ! -d "$(OPTEE_OS_PATH)" ]; then \
		echo "克隆 OP-TEE ($(OPTEE_VERSION))..."; \
		git clone -b $(OPTEE_VERSION) https://github.com/OP-TEE/optee_os.git $(OPTEE_OS_PATH); \
		echo "OP-TEE 下载完成"; \
	else \
		echo "OP-TEE 已存在，检查版本..."; \
		cd $(OPTEE_OS_PATH) && \
		current_branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
		current_commit=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
		echo "当前分支: $$current_branch, 提交: $$current_commit"; \
		echo "目标版本: $(OPTEE_VERSION)"; \
	fi

.PHONY: download-uboot
download-uboot:
	@echo "=== 下载 U-Boot (版本: $(UBOOT_VERSION)) ==="
	@if [ -z "$(UBOOT_VERSION)" ]; then \
		echo "错误: 无法从 manifest.xml 获取 U-Boot 版本"; \
		exit 1; \
	fi
	@if [ ! -d "$(UBOOT_PATH)" ]; then \
		echo "克隆 U-Boot ($(UBOOT_VERSION))..."; \
		git clone -b $(UBOOT_VERSION) https://source.denx.de/u-boot/u-boot.git $(UBOOT_PATH); \
		echo "U-Boot 下载完成"; \
	else \
		echo "U-Boot 已存在，检查版本..."; \
		cd $(UBOOT_PATH) && \
		current_branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
		current_commit=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
		echo "当前分支: $$current_branch, 提交: $$current_commit"; \
		echo "目标版本: $(UBOOT_VERSION)"; \
	fi

.PHONY: download-ubuntu
download-ubuntu:
	@echo "=== 下载 Ubuntu 镜像 (版本: $(UBUNTU_IMG_VERSION)) ==="
	@if [ -z "$(UBUNTU_IMG_VERSION)" ]; then \
		echo "错误: 无法从 manifest.xml 获取 Ubuntu 镜像版本"; \
		exit 1; \
	fi
	@if [ ! -f "$(UBUNTU_IMG_XZ)" ] && [ ! -f "$(UBUNTU_IMG)" ]; then \
		echo "下载 Ubuntu 22.04 镜像 ($(UBUNTU_IMG_VERSION))..."; \
		wget -O $(UBUNTU_IMG_XZ) https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/$(UBUNTU_IMG_VERSION)/ubuntu-22.04-preinstalled-server-arm64-rock-5b.img.xz; \
		if [ $$? -eq 0 ]; then \
			echo "Ubuntu 镜像下载完成"; \
		else \
			echo "错误: Ubuntu 镜像下载失败"; \
			exit 1; \
		fi; \
	else \
		echo "Ubuntu 镜像文件已存在"; \
	fi
	@if [ -f "$(UBUNTU_IMG_XZ)" ] && [ ! -f "$(UBUNTU_IMG)" ]; then \
		echo "解压 Ubuntu 镜像..."; \
		xz -dk $(UBUNTU_IMG_XZ); \
		if [ $$? -eq 0 ]; then \
			echo "Ubuntu 镜像解压完成: $(UBUNTU_IMG)"; \
			echo "镜像大小: $$(du -h $(UBUNTU_IMG) | cut -f1)"; \
		else \
			echo "错误: Ubuntu 镜像解压失败"; \
			exit 1; \
		fi; \
	elif [ -f "$(UBUNTU_IMG)" ]; then \
		echo "Ubuntu 镜像已存在: $(UBUNTU_IMG)"; \
		echo "镜像大小: $$(du -h $(UBUNTU_IMG) | cut -f1)"; \
	fi

################################################################################
# 环境检查
################################################################################
.PHONY: check-env
check-env:
	@echo "=== 检查构建环境 ==="
	@mkdir -p $(OUTPUT_DIR)
	@for comp in atf rkbin optee_os u-boot; do \
		if [ ! -d "$$comp" ]; then \
			echo "错误: 缺少 $$comp 目录"; \
			exit 1; \
		else \
			echo "找到 $$comp 目录"; \
		fi; \
	done
	@echo "=== 环境检查完成 ==="

# 安装依赖
.PHONY: deps
deps:
	@echo "=== 安装构建依赖 ==="
	sudo apt-get update
	sudo apt-get install -y \
		git build-essential bc swig python3-dev python3-pip \
		device-tree-compiler libssl-dev libncurses5-dev \
		flex bison libfdt-dev libusb-1.0-0-dev \
		gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
		wget xz-utils parted dosfstools mtools u-boot-tools

################################################################################
# TF-A
################################################################################
.PHONY: atf
atf: $(BL31_ELF)

$(BL31_ELF):
	@echo "=== 构建 TF-A ==="
	cd $(TF_A_PATH) && \
	make CROSS_COMPILE=$(CROSS_COMPILE) PLAT=rk3588 DEBUG=1 SPD=opteed clean && \
	make CROSS_COMPILE=$(CROSS_COMPILE) PLAT=rk3588 DEBUG=1 SPD=opteed
	cp $(BL31_PATH)/bl31.elf $(OUTPUT_DIR)
	@echo "TF-A 构建完成: $(BL31_ELF)"

################################################################################
# OP-TEE
################################################################################
.PHONY: optee
optee: $(TEE_BIN_OUT)

$(TEE_BIN_OUT):
	@echo "=== 构建 OP-TEE ==="
	cd $(OPTEE_OS_PATH) && \
	make CFG_ARM64_core=y \
	     CROSS_COMPILE64=$(CROSS_COMPILE) \
	     CFG_USER_TA_TARGETS=ta_arm64 \
	     CFG_DT=y \
	     CFG_CORE_ARM64_PA_BITS=34 \
	     PLATFORM=rockchip \
	     PLATFORM_FLAVOR=rk3588
	if [ -f "$(TEE_BIN)/tee.bin" ]; then \
		cp $(TEE_BIN)/tee.bin $(OUTPUT_DIR); \
		echo "OP-TEE 构建完成: $(TEE_BIN_OUT)"; \
	else \
		echo "警告: 未找到 OP-TEE 输出文件，但继续构建过程..."; \
	fi

################################################################################
# U-Boot
################################################################################
.PHONY: uboot
uboot: $(IDBLOADER_IMG) $(UBOOT_ITB)

$(IDBLOADER_IMG) $(UBOOT_ITB): $(BL31_ELF)
	@echo "=== 构建 U-Boot ==="
	@# 检查必要的依赖文件
	if [ ! -f "$(TPL_BIN)" ]; then \
		echo "错误: 未找到 TPL 文件: $(TPL_BIN)"; \
		exit 1; \
	fi
	cd $(UBOOT_PATH) && \
	make distclean && \
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) rock5b-rk3588_defconfig && \
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) \
	     ROCKCHIP_TPL=$(TPL_BIN) \
	     BL31=$(BL31_ELF) \
	     TEE=$(TEE_BIN_OUT)
	@# 生成 idbloader.img
	cd $(UBOOT_PATH) && \
	mkimage -T rksd -n rk3568 -d $(TPL_BIN):$(SPL_BIN) idbloader.img
	cp $(UBOOT_PATH)/idbloader.img $(OUTPUT_DIR)
	cp $(UBOOT_PATH)/u-boot.itb $(OUTPUT_DIR)
	@echo "U-Boot 构建完成: $(IDBLOADER_IMG), $(UBOOT_ITB)"

################################################################################
# ubuntu-image
################################################################################
.PHONY: ubuntu-image
ubuntu-image: $(UBUNTU_IMG)

$(UBUNTU_IMG):
	@echo "=== 处理 Ubuntu 镜像 ==="
	if [ -f "$(UBUNTU_IMG_XZ)" ]; then \
		if [ ! -f "$(UBUNTU_IMG)" ]; then \
			echo "解压 Ubuntu 镜像..."; \
			xz -dk $(UBUNTU_IMG_XZ); \
			echo "Ubuntu 镜像解压完成: $(UBUNTU_IMG)"; \
		else \
			echo "Ubuntu 镜像已存在: $(UBUNTU_IMG)"; \
		fi; \
	else \
		echo "警告: 未找到 Ubuntu 镜像文件: $(UBUNTU_IMG_XZ)"; \
	fi

.PHONY: clean
clean:
	@echo "=== 清理构建文件 ==="
	-cd $(TF_A_PATH) && make clean
	-cd $(OPTEE_OS_PATH) && make clean
	-cd $(UBOOT_PATH) && make distclean
	-rm -rf $(OUTPUT_DIR)

.PHONY: distclean
distclean: clean
	@echo "=== 深度清理 ==="
	-rm -f $(UBUNTU_IMG)

.PHONY: info
info:
	@echo "=== Rock 5B 构建系统信息 ==="
	@echo "项目目录: $(TOP_DIR)"
	@echo "输出目录: $(OUTPUT_DIR)"
	@echo "工具链: $(CROSS_COMPILE)"
	@echo "架构: $(ARCH)"
	@echo "可用目标:"
	@echo "  make all        - 构建所有组件"
	@echo "  make atf        - 只构建 TF-A"
	@echo "  make optee      - 只构建 OP-TEE"
	@echo "  make uboot      - 只构建 U-Boot"
	@echo "  make ubuntu-image - 处理 Ubuntu 镜像"
	@echo "  make clean      - 清理构建文件"
	@echo "  make disclean      - 深度清理构建文件"
	@echo "  make info       - 显示此信息"

################################################################################
# Boot image, shall be copied to SD card
################################################################################
.PHONY: flash-check
flash-check:
	@echo "=== 检查烧录环境 ==="
	@if [ -f "flash_rock5b.sh" ]; then \
		chmod +x flash_rock5b.sh; \
		echo "发现烧录脚本: flash_rock5b.sh"; \
		echo "运行: ./flash_rock5b.sh /dev/sdX 进行烧录"; \
	else \
		echo "未找到烧录脚本，请创建 flash_rock5b.sh"; \
	fi

include common.mk

DEBUG ?= 1

# Do not leave a partially downloaded binary in case wget fails midway
.DELETE_ON_ERROR:

################################################################################
# Paths to git projects and various binaries
################################################################################
TF_A_PATH		?= $(ROOT)/trusted-firmware-a
BINARIES_PATH		?= $(ROOT)/out
UBOOT_PATH		?= $(ROOT)/u-boot
UBOOT_BIN		?= $(UBOOT_PATH)/u-boot.bin
ROOT_IMG 		?= $(ROOT)/out-br/images/rootfs.ext2
BOOT_IMG		?= $(ROOT)/out/rock5b.img
RKDEVELOPTOOL_PATH	?= $(ROOT)/rkdeveloptool
RKDEVELOPTOOL_BIN	?= $(RKDEVELOPTOOL_PATH)/rkdeveloptool
LOADER_BIN		?= $(BINARIES_PATH)/rk3588_spl_loader_v1.15.113.bin
TPL_BIN		        ?= $(BINARIES_PATH)/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin

LINUX_MODULES ?= y

BR2_TARGET_ROOTFS_CPIO = n
BR2_TARGET_ROOTFS_CPIO_GZIP = n
BR2_TARGET_ROOTFS_EXT2 = y
BR2_TARGET_GENERIC_GETTY_PORT = ttyS2
ifeq ($(LINUX_MODULES),y)
# If modules are installed...
# ...enable automatic device detection and driver loading
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV = y
# ...and configure eth0 automatically based on ifup helpers
BR2_PACKAGE_IFUPDOWN_SCRIPTS = y
# BR2_SYSTEM_DHCP = eth0
# An image with module takes more space
BR2_TARGET_ROOTFS_EXT2_SIZE = 640M
# Enable SSH daemon for remote login
BR2_PACKAGE_OPENSSH = y
BR2_PACKAGE_OPENSSH_SERVER = y
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/rock5b/post-build.sh
else
BR2_TARGET_ROOTFS_EXT2_SIZE = 112M
endif

################################################################################
# Targets
################################################################################

all: boot-img

clean: buildroot-clean

include toolchain.mk

################################################################################
# Arm Trusted Firmware-A
################################################################################
TF_A_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
		M0_CROSS_COMPILE="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

TF_A_DEBUG ?= $(DEBUG)
ifeq ($(TF_A_DEBUG),0)
TF_A_LOGLVL ?= 30
TF_A_OUT = $(TF_A_PATH)/build/rk3588/release
else
TF_A_LOGLVL ?= 40
TF_A_OUT = $(TF_A_PATH)/build/rk3588/debug
endif

TF_A_FLAGS ?= ARCH=aarch64 PLAT=rk3588 SPD=opteed DEBUG=$(TF_A_DEBUG) \
	      LOG_LEVEL=$(TF_A_LOGLVL) \
              BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	      BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	      BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN)

.PHONY: tfa
tfa:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) bl31

.PHONY: tfa-clean
tfa-clean:
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS) clean

clean: tfa-clean

################################################################################
# U-Boot
################################################################################
UBOOT_DEFCONFIG_FILES := $(UBOOT_PATH)/configs/nanopc-t6-rk3588_defconfig \
			 $(ROOT)/build/kconfigs/u-boot_rock5b.conf

UBOOT_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL) \
	       CC=$(CROSS_COMPILE_NS_KERNEL)gcc \
	       HOSTCC="$(CCACHE) gcc"

$(TPL_BIN):
	mkdir -p $(BINARIES_PATH)
	cd $(BINARIES_PATH) && \
		wget -O $(notdir $(TPL_BIN)) https://github.com/rockchip-linux/rkbin/raw/master/bin/rk35/$(notdir $(TPL_BIN))

UBOOT_EXPORTS ?= BL31=$(TF_A_OUT)/bl31/bl31.elf TEE=$(OPTEE_OS_BIN) ROCKCHIP_TPL=$(TPL_BIN)

u-boot-defconfig: $(UBOOT_PATH)/.config

$(UBOOT_PATH)/.config: $(UBOOT_DEFCONFIG_FILES)
	cd $(UBOOT_PATH) && \
                scripts/kconfig/merge_config.sh $(UBOOT_DEFCONFIG_FILES)

.PHONY: u-boot-defconfig

.PHONY: u-boot
u-boot: $(TPL_BIN) $(UBOOT_PATH)/.config optee-os tfa
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS)

.PHONY: u-boot-clean
u-boot-clean:
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS) distclean

clean: u-boot-clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH ?= arm64
LINUX_DEFCONFIG_COMMON_FILES ?= $(LINUX_PATH)/arch/arm64/configs/defconfig \
				$(CURDIR)/kconfigs/rock5b.conf

.PHONY: linux-defconfig
linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64
LINUX_COMMON_TARGETS += Image rockchip/rk3588-nanopc-t6.dtb \
			$(if $(filter y,$(LINUX_MODULES)),modules)

.PHONY: linux
linux: linux-common
ifeq ($(LINUX_MODULES),y)
	$(MAKE) -C $(LINUX_PATH) ARCH=arm64 modules_install \
		INSTALL_MOD_PATH=$(BINARIES_PATH)/modules
endif

$(LINUX_PATH)/arch/arm64/boot/Image.gz: linux
	gzip -c $(LINUX_PATH)/arch/arm64/boot/Image >$@

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_PLATFORM = rockchip-rk3588
OPTEE_OS_COMMON_FLAGS += CFG_ENABLE_EMBEDDED_TESTS=y

.PHONY: optee-os
optee-os: optee-os-common

.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

clean: optee-os-clean

################################################################################
# Boot image, shall be copied to SD card
################################################################################

# U-Boot offset comes from CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR=0x4000
# Partition no. 5 ends at 12288 + BR2_TARGET_ROOTFS_EXT2_SIZE (in kiB)
# File size needs to be slightly bigger to accomodate for whatever meta-data
rootfs-size-kib := $(shell echo $(BR2_TARGET_ROOTFS_EXT2_SIZE) | sed 's/M/*1024/')
p5-end-kib := $(shell echo $$((12288 + $(rootfs-size-kib))))
img-size-kib := $(shell echo $$(($(p5-end-kib) + 1024)))

.PHONY: boot-img
boot-img: u-boot buildroot $(LINUX_PATH)/arch/arm64/boot/Image.gz
	mkdir -p $(BINARIES_PATH)
	rm -f $(BOOT_IMG)
	truncate -s $(img-size-kib)KiB $(BOOT_IMG)
	parted -s $(BOOT_IMG) \
		unit kiB \
		mklabel gpt \
		mkpart idbloader 32 4032 \
		mkpart primary fat32 4032 4096 \
		mkpart primary fat32 4096 8192 \
		mkpart uboot 8192 12288 \
		mkpart root fat32 12288 $(p5-end-kib)
	sgdisk -u 5:17d61bff-8fdc-4089-b675-9be21b9f6ac7 $(BOOT_IMG)
	dd if=$(UBOOT_PATH)/idbloader.img of=$(BOOT_IMG) bs=1kiB seek=32 conv=notrunc
	dd if=$(UBOOT_PATH)/u-boot.itb of=$(BOOT_IMG) bs=1kiB seek=8192 conv=notrunc
	e2mkdir $(ROOT_IMG):/boot
	e2cp $(LINUX_PATH)/arch/arm64/boot/Image.gz $(ROOT_IMG):/boot
	e2cp $(LINUX_PATH)/arch/arm64/boot/dts/rockchip/rk3588-nanopc-t6.dtb $(ROOT_IMG):/boot
ifeq ($(LINUX_MODULES),y)
	find $(BINARIES_PATH)/modules -type f | while read f; do e2cp -a $$f $(ROOT_IMG):$$(echo $$f | sed s@$(BINARIES_PATH)/modules@@); done
endif
	dd if=$(ROOT_IMG) of=$(BOOT_IMG) bs=1kiB seek=12288 conv=notrunc

.PHONY: boot-img-clean
boot-img-clean:
	rm -f $(BOOT_IMG)

clean: boot-img-clean

################################################################################
# rkdeveloptool
################################################################################

$(RKDEVELOPTOOL_PATH)/Makefile:
	cd $(RKDEVELOPTOOL_PATH) && \
		autoreconf -i && \
		./configure CXXFLAGS=-Wno-format-truncation

$(RKDEVELOPTOOL_BIN): $(RKDEVELOPTOOL_PATH)/Makefile
	$(MAKE) -C $(RKDEVELOPTOOL_PATH)

rkdeveloptool: $(RKDEVELOPTOOL_BIN)

rkdeveloptool-clean:
	$(MAKE) -C $(RKDEVELOPTOOL_PATH) clean

rkdeveloptool-distclean:
	$(MAKE) -C $(RKDEVELOPTOOL_PATH) clean

clean: rkdeveloptool-clean

$(LOADER_BIN):
	mkdir -p $(BINARIES_PATH)
	cd $(BINARIES_PATH) && \
		wget https://dl.radxa.com/rock5/sw/images/loader/rock-5b/release/$(notdir $(LOADER_BIN))

################################################################################
# Flash the image via USB onto the onboard eMMC
################################################################################

define flash-help
        @echo
        @echo "Please connect the board to the computer via a USB A-C cable."
        @echo "The cable should be connected to the Type-C port on the NanoPC T6."
        @echo "Remove the microSD card and power cable from the board."
        @echo "Press and hold the Maskrom (MASK) button."
        @echo "While holding the MASK button, insert the power cable."
        @echo "This should normally put the device into Maskrom mode."
        @echo "(For more details, visit: https://wiki.friendlyelec.com/wiki/index.php/NanoPC-T6)"
        @echo
        @read -r -p "Press enter to continue, Ctrl-C to cancel:" dummy
endef

flash: $(BOOT_IMG) $(LOADER_BIN) $(RKDEVELOPTOOL_BIN)
	$(call flash-help)
	$(RKDEVELOPTOOL_BIN) db $(LOADER_BIN)
	sleep 1
	$(RKDEVELOPTOOL_BIN) wl 0 $(BOOT_IMG)

nuke-emmc: $(LOADER_BIN) $(RKDEVELOPTOOL_BIN)
	@echo
	@echo "** WARNING: this command will make the onboard eMMC unbootable!"
	@echo "It can be used to boot from the SD card again."
	$(call flash-help)
	dd if=/dev/zero of=$(BINARIES_PATH)/zero.img bs=1M count=64
	$(RKDEVELOPTOOL_BIN) db $(LOADER_BIN)
	sleep 1
	$(RKDEVELOPTOOL_BIN) wl 0 $(BINARIES_PATH)/zero.img
