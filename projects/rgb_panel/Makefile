# Project config
PROJ = rgb_panel

PROJ_DEPS := misc hub75
PROJ_RTL_SRCS := $(addprefix rtl/, \
	pgen.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
	hub75_top_tb
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
dfu_flash: $(BUILD_TMP)/$(PROJ).bit
	$(DFU_UTIL) -d 1d50:614a,1d50:614b -a 5 -R -D $<
