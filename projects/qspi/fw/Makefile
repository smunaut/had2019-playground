BOARD ?= had2019-badge
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)

CFLAGS=-Wall -Os -march=rv32iac -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section -D$(BOARD_DEFINE)=1 -Wl,--no-relax -Wno-aggressive-loop-optimizations


HEADERS_common=\
	config.h \
	console.h \
	mini-printf.h \
	psram.h \
	utils.h \
	$(NULL)

SOURCES_common=\
	start.S \
	console.c \
	mini-printf.c  \
	psram.c \
	utils.c \
	$(NULL)

HEADERS_qspi=\
	$(NULL)

SOURCES_qspi=\
	fw_qspi.c \
	$(NULL)


all: fw_qspi.bin


fw_qspi.elf: lnk-app.lds $(HEADERS_qspi) $(SOURCES_qspi) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_qspi)


%.hex: %.bin
	./bin2hex.py $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@


clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

.PHONY: clean
