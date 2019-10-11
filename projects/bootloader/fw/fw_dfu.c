/*
 * fw_dfu.c
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "console.h"
#include "mini-printf.h"
#include "spi.h"
#include "usb.h"
#include "usb_dfu.h"
#include "utils.h"

#include "config.h"


struct had_misc {
	uint32_t ctrl;
	uint32_t pwm;
	uint32_t lcd_cmd;
	uint32_t lcd_data;
} __attribute__((packed,aligned(4)));

static volatile struct had_misc * const had_misc_regs = (void*)(HAD_MISC_BASE);


extern const struct usb_stack_descriptors dfu_stack_desc;

static void
serial_no_init()
{
	uint8_t buf[8];
	char *id, *desc;
	int i;

	flash_manuf_id(buf);
	printf("Flash Manufacturer : %s\n", hexstr(buf, 3, true));

	flash_unique_id(buf);
	printf("Flash Unique ID    : %s\n", hexstr(buf, 8, true));

	/* Overwrite descriptor string */
		/* In theory in rodata ... but nothing is ro here */
	id = hexstr(buf, 8, false);
	desc = (char*)dfu_stack_desc.str[1];
	for (i=0; i<16; i++)
		desc[2 + (i << 1)] = id[i];
}

static void
boot_app(void)
{
	/* Force re-enumeration */
	usb_disconnect();

	/* Boot firmware */
	had_misc_regs->ctrl = (had_misc_regs->ctrl & 0x00ffffff) | 0xa5000000;
}

void
usb_dfu_cb_reboot(void)
{
	boot_app();
}


static void delay(int n) {
	for (int i=0; i<n; i++) {
		for (volatile int t=0; t<(1<<11); t++);
	}
}


static const uint8_t lcd_init_data[] = {
	0x02, 0xF0, 0x5A, 0x5A,
	0x02, 0xF1, 0x5A, 0x5A,
	0x13, 0xF2, 0x3B, 0x40, 0x03, 0x04, 0x02, 0x08, 0x08, 0x00, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x40, 0x08, 0x08, 0x08, 0x08,
	0x0e, 0xF4, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6d, 0x03, 0x00, 0x70, 0x03, 
	0x0c, 0xF5, 0x00, 0x54, 0x73, 0x00, 0x00, 0x04, 0x00, 0x00, 0x04, 0x00, 0x53, 0x71,
	0x08, 0xF6, 0x04, 0x00, 0x08, 0x03, 0x01, 0x00, 0x01, 0x00,
	0x05, 0xF7, 0x48, 0x80, 0x10, 0x02, 0x00,
	0x02, 0xF8, 0x11, 0x00,
	0x01, 0xF9, 0x27,
	0x14, 0xFA, 0x0B, 0x0B, 0x0F, 0x26, 0x2A, 0x30, 0x33, 0x12, 0x1F, 0x25, 0x31, 0x30, 0x24, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x3F,
	0x04, 0x2a, 0x00, 0x00, 0x01, 0xDF,
	0x04, 0x2b, 0x00, 0x00, 0x01, 0x3F,
	0x01, 0x36, 0xA0,
	0x01, 0x3A, 0x55,
	0x00, 0x11,
	0xfe, 0x78,	// Delay CMD
	0x00, 0x29,
	0xff		// End
};

extern const uint8_t lcd_screen[];

void lcd_logo()
{
	#define RGB(r,g,b) (\
		( ((r) >> 3) << 11 ) | \
		( ((g) >> 2) <<  5 ) | \
		( ((b) >> 3) <<  0 ) \
	)

	const uint32_t pal[] = {
		RGB(  0,  0,  0),
		RGB(  5,  5, 38),
		RGB(  9,  9, 70),
		RGB( 12, 12,100),
		RGB( 20, 20,138),
		RGB(152,152,152),
		RGB(255,255,140),
		RGB(255,255,255),
		   0,
		   0,
		   0,
		   0,
		   0,
		   0,
		   0,
		   0,
	};
	const uint8_t *p = lcd_screen;
	uint8_t c;
	int n;

	// Start draw
	had_misc_regs->lcd_cmd = 0x2c;

	for (int i=0; i<320*480;) {
		// Get command
		c = *p++;

		// Repeat count 
		n = c >> 4;
		if (n == 0xf) {
			n = *p++;
			if (n == 0xff) {
				n = *p++;
				n |= (*p++) << 8;
				n += 271;
			} else {
				n += 16;
			}
		} else {
			n += 1;
		}

		// Write
		while (n--) {
			c &= 0xf;
			had_misc_regs->lcd_data = pal[c];
			i++;
		}
	}
}

void lcd_init()
{
	const uint8_t *p = lcd_init_data;
	int n=0;

	while (1) {
		if (n) {
			had_misc_regs->lcd_data = *p++;
			n--;
		} else {
			n = *p++;

			if (n == 0xfe) {
				delay(*p++);
				n = 0;
			} else if (n == 0xff) {
				break;
			} else {
				had_misc_regs->lcd_cmd = *p++;
			}
		}
	}
}

void main()
{
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting DFU image..\n");

	/* SPI */
	spi_init();

	had_misc_regs->ctrl |= (1 << 15) | (1 << 9);
	had_misc_regs->pwm  = (had_misc_regs->pwm & ~(7 << 27)) | (1 << 27);

	lcd_init();
	lcd_logo();


	/* Enable USB directly */
	serial_no_init();
	usb_init(&dfu_stack_desc);
	usb_dfu_init();
	usb_connect();

	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			if (cmd > 32 && cmd < 127) {
				putchar(cmd);
				putchar('\r');
				putchar('\n');
			}

			switch (cmd)
			{
			case 'p':
				usb_debug_print();
				break;
			case 'c':
				usb_connect();
				break;
			case 'd':
				usb_disconnect();
				break;
			case 'b':
				boot_app();
				break;
			case 'i':
				serial_no_init();
				break;
			default:
				break;
			}
		}

		/* USB poll */
		usb_poll();
	}
}
