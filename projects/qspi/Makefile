# Project config
PROJ = qspi

PROJ_DEPS := misc synth

PROJ_RTL_SRCS := $(addprefix rtl/, \
	picorv32.v \
	qpimem_iface_2x2w.v \
	qpimem_test.v \
	qspi_phy_2x_ecp5.v \
	soc_bram.v \
	soc_bridge.v \
	sysmgr.v \
)
PROJ_SIM_SRCS := $(addprefix sim/, \
	GSR.v \
	IDDRX1F.v \
	ODDRX1F.v \
	PUR.v \
	qpimem_cache.v \
	simple_mem.v \
	simple_mem_words.v \
)
PROJ_SIM_SRCS += rtl/top.v
PROJ_TESTBENCHES := \
	qpimem_iface_2x2w_tb \
	phy_tb
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
fw/fw_qspi.hex: fw
	make -C fw fw_qspi.hex

$(BUILD_TMP)/boot.hex:
	$(ECPBRAM) -g $@ -s 2019 -w 32 -d 8192

$(BUILD_TMP)/$(PROJ).bit $(BUILD_TMP)/$(PROJ).svf: $(BUILD_TMP)/$(PROJ).config $(BUILD_TMP)/boot.hex fw/fw_qspi.hex
	$(ECPBRAM) -v -f $(BUILD_TMP)/boot.hex -t fw/fw_qspi.hex -i $(BUILD_TMP)/$(PROJ).config -o $(BUILD_TMP)/$(PROJ)-sw.config 
	$(ECPPACK) \
		--spimode $(FLASH_MODE) --freq $(FLASH_FREQ) \
		--bootaddr 0x180000 \
		--input $(BUILD_TMP)/$(PROJ)-sw.config \
		--svf $(BUILD_TMP)/$(PROJ).svf --svf-rowsize 100000 \
		--bit $(BUILD_TMP)/$(PROJ).bit

dfu_flash: $(BUILD_TMP)/$(PROJ).bit
	$(DFU_UTIL) -d 1d50:614a,1d50:614b -a 0 -R -D $<

# Always try to rebuild the hex file
.PHONY: fw
