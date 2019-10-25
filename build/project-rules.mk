#
# project-rules.mk
#

# Default tools
YOSYS ?= yosys
YOSYS_READ_ARGS ?= -defer
YOSYS_SYNTH_ARGS ?= -abc9
NEXTPNR ?= nextpnr-ecp5
NEXTPNR_ARGS ?= --freq 50
ECPBRAM ?= ecpbram
ECPPACK ?= ecppack
IVERILOG ?= iverilog
DFU_UTIL ?= dfu-util

PLACER ?= heap
NEXTPNR_SYS_ARGS += --placer $(PLACER)

# Default config (qspi, dual-spi, fast-read) (2.4, 4.8, 9.7, 19.4, 38.8, 62.0)
FLASH_MODE = qspi
FLASH_FREQ = 38.8

ECP5_INCLUDES ?= -I$(shell yosys-config --datdir/ecp5/)
ECP5_LIBS ?= $(shell yosys-config --datdir/ecp5/cells_sim.v)


# Must be first rule and call it 'all' by convention
all: synth

# Root directory
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# Temporary build-directory
BUILD_TMP := $(abspath build-tmp)

$(BUILD_TMP):
	mkdir -p $(BUILD_TMP)

# Discover all cores
$(foreach core_dir, $(wildcard $(ROOT)/cores/*), $(eval include $(core_dir)/core.mk))

# Resolve dependency tree for project and collect sources
$(BUILD_TMP)/proj-deps.mk: Makefile $(BUILD_TMP) $(addprefix $(BUILD_TMP)/deps-core-,$(PROJ_DEPS))
	@echo "include $(BUILD_TMP)/deps-core-*" > $@
	@echo "PROJ_ALL_DEPS := \$$(DEPS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_RTL_SRCS := \$$(RTL_SRCS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_SIM_SRCS := \$$(SIM_SRCS_SOLVE_TMP)" >> $@
	@echo "PROJ_ALL_PREREQ := \$$(PREREQ_SOLVE_TMP)" >> $@

include $(BUILD_TMP)/proj-deps.mk

# Make all sources absolute
PROJ_RTL_SRCS := $(abspath $(PROJ_RTL_SRCS))
PROJ_TOP_SRC  := $(abspath $(PROJ_TOP_SRC))

# Board config
PIN_DEF ?= $(abspath data/$(PROJ_TOP_MOD)-$(BOARD).lpf)

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)
YOSYS_READ_ARGS += -D$(BOARD_DEFINE)=1

# Add those to the list
PROJ_ALL_RTL_SRCS += $(PROJ_RTL_SRCS)
PROJ_ALL_SIM_SRCS += $(PROJ_SIM_SRCS)
PROJ_ALL_PREREQ += $(PROJ_PREREQ)

# Include path
PROJ_SYNTH_INCLUDES := -I$(abspath rtl/) $(addsuffix /rtl/, $(addprefix -I$(ROOT)/cores/, $(PROJ_ALL_DEPS)))
PROJ_SIM_INCLUDES   := -I$(abspath sim/) $(addsuffix /sim/, $(addprefix -I$(ROOT)/cores/, $(PROJ_ALL_DEPS)))


# Synthesis & Place-n-route rules

$(BUILD_TMP)/$(PROJ).ys: $(PROJ_TOP_SRC) $(PROJ_ALL_RTL_SRCS)
	@echo "read_verilog $(YOSYS_READ_ARGS) $(PROJ_SYNTH_INCLUDES) $(PROJ_TOP_SRC) $(PROJ_ALL_RTL_SRCS)" > $@
	@echo "synth_ecp5 $(YOSYS_SYNTH_ARGS) -top $(PROJ_TOP_MOD) -json $(PROJ).json" >> $@

$(BUILD_TMP)/$(PROJ).synth.rpt $(BUILD_TMP)/$(PROJ).json: $(PROJ_ALL_PREREQ) $(BUILD_TMP)/$(PROJ).ys $(PROJ_ALL_RTL_SRCS)
	cd $(BUILD_TMP) && \
		$(YOSYS) -s $(BUILD_TMP)/$(PROJ).ys \
			 -l $(BUILD_TMP)/$(PROJ).synth.rpt

$(BUILD_TMP)/$(PROJ).pnr.rpt $(BUILD_TMP)/$(PROJ).config: $(BUILD_TMP)/$(PROJ).json $(PIN_DEF)
	$(NEXTPNR) $(NEXTPNR_ARGS) $(NEXTPNR_SYS_ARGS) \
		--$(DEVICE) --package $(PACKAGE)  --speed $(SPEEDGRADE) \
		-l $(BUILD_TMP)/$(PROJ).pnr.rpt \
		--json $(BUILD_TMP)/$(PROJ).json \
		--lpf $(PIN_DEF) \
		--textcfg $@ 

%.bit %.svf: %.config
	$(ECPPACK) --spimode $(FLASH_MODE) --freq $(FLASH_FREQ) --svf-rowsize 100000 --svf $*.svf --input $< --bit $*.bit


# Simulation
$(BUILD_TMP)/%_tb: sim/%_tb.v $(ECP5_LIBS) $(PROJ_ALL_PREREQ) $(PROJ_ALL_RTL_SRCS) $(PROJ_ALL_SIM_SRCS)
	$(IVERILOG) -Wall -DSIM=1 -D$(BOARD_DEFINE)=1 -o $@ \
		$(PROJ_SYNTH_INCLUDES) $(PROJ_SIM_INCLUDES) $(ECP5_INCLUDES) \
		$(addprefix -l, $(ECP5_LIBS) $(PROJ_ALL_RTL_SRCS) $(PROJ_ALL_SIM_SRCS)) \
		$<


# Action targets

synth: $(BUILD_TMP)/$(PROJ).bit $(BUILD_TMP)/$(PROJ).svf

sim: $(addprefix $(BUILD_TMP)/, $(PROJ_TESTBENCHES))

dfuprog: $(BUILD_TMP)/$(PROJ).bin
ifeq ($(DFU_SERIAL),)
	@echo "[!] DFU_SERIAL not defined"
else
	$(DFU_UTIL) -e -S $(DFU_SERIAL) -a 0 -D $<
endif

clean:
	@rm -Rf $(BUILD_TMP)


.PHONY: all synth sim prog sudo-prog clean
