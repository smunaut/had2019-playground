# Project config
PROJ = bootloader

PROJ_DEPS := usb misc

PROJ_RTL_SRCS := $(addprefix rtl/, \
	picorv32.v \
	qspi_master_wb.v \
	qspi_phy_ecp5.v \
	soc_bram.v \
	soc_bridge.v \
	soc_had_misc.v \
	sysmgr.v \
)
PROJ_SIM_SRCS := $(addprefix sim/, \
	spiflash.v \
)
PROJ_SIM_SRCS += rtl/top.v
PROJ_TESTBENCHES := \
	dfu_helper_tb \
	top_tb
PROJ_PREREQ = \
	$(BUILD_TMP)/boot.hex
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= had2019-badge
DEVICE = 45k
PACKAGE = CABGA381
SPEEDGRADE = 8

NEXTPNR_ARGS = --pre-pack data/clocks.py

# Include default rules
include ../../build/project-rules.mk

# Custom rules
fw/fw_dfu.hex:
	make -C fw fw_dfu.hex

$(BUILD_TMP)/boot.hex:
	$(ECPBRAM) -g $@ -s 2019 -w 32 -d 8192

$(BUILD_TMP)/$(PROJ).bit $(BUILD_TMP)/$(PROJ).svf: $(BUILD_TMP)/$(PROJ).config $(BUILD_TMP)/boot.hex fw/fw_dfu.hex
	$(ECPBRAM) -v -f $(BUILD_TMP)/boot.hex -t fw/fw_dfu.hex -i $(BUILD_TMP)/$(PROJ).config -o $(BUILD_TMP)/$(PROJ)-sw.config
	$(ECPPACK) \
		--spimode $(FLASH_MODE) --freq $(FLASH_FREQ) \
		--bootaddr 0x180000 \
		--input $(BUILD_TMP)/$(PROJ)-sw.config \
		--svf $(BUILD_TMP)/$(PROJ).svf --svf-rowsize 100000 \
		--bit $(BUILD_TMP)/$(PROJ).bit

dfu_flash: $(BUILD_TMP)/$(PROJ).bit
	$(DFU_UTIL) -d 1d50:614a,1d50:614b -a 5 -R -D $<
