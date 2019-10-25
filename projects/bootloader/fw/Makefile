BOARD ?= had2019-badge
CROSS ?= riscv-none-embed-
CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

BOARD_DEFINE=BOARD_$(shell echo $(BOARD) | tr a-z\- A-Z_)

CFLAGS=-Wall -Os -march=rv32iac -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section -D$(BOARD_DEFINE)=1


HEADERS_common=\
	config.h \
	console.h \
	mini-printf.h \
	misc.h \
	spi.h \
	usb_hw.h \
	usb_priv.h \
	usb_proto.h \
	utils.h

SOURCES_common=\
	start.S \
	console.c \
	mini-printf.c  \
	misc.c \
	spi.c \
	usb.c \
	usb_ctrl_ep0.c \
	usb_ctrl_std.c \
	utils.c

HEADERS_dfu=\
	usb_dfu.h \
	usb_dfu_proto.h \
	usb_str_dfu.gen.h

SOURCES_dfu=\
	fw_dfu.c \
	logo.c \
	usb_dfu.c \
	usb_dfu_vendor.c \
	usb_desc_dfu.c


all: fw_dfu.bin


fw_dfu.elf: lnk-app.lds $(HEADERS_dfu) $(SOURCES_dfu) $(HEADERS_common) $(SOURCES_common)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-app.lds,--strip-debug -o $@ $(SOURCES_common) $(SOURCES_dfu)


%.hex: %.bin
	./bin2hex.py $< $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

usb_str_%.gen.h: usb_str_%.txt
	./usb_gen_strings.py $< $@ $(BOARD)


clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

.PHONY: prog_dfu prog_app clean
