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
#include "misc.h"
#include "mini-printf.h"
#include "spi.h"
#include "usb.h"
#include "usb_dfu.h"
#include "utils.h"

#include "config.h"


extern const struct usb_stack_descriptors dfu_stack_desc;
extern const uint8_t desc_ms_os_20[0x1E];


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

void
usb_dfu_cb_reboot(void)
{
	/* Force re-enumeration */
	usb_disconnect();

	/* Reboot */
	reboot_now();
}

static enum usb_fnd_resp
_ms_os_20_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	switch (req->wRequestAndType)
	{
	case 0x01c0:
		if (req->wIndex == 7) {
			xfer->data = (void*)desc_ms_os_20;
			xfer->len  = sizeof(desc_ms_os_20);
			return USB_FND_SUCCESS;
		} else {
			return USB_FND_ERROR;
		}
	}

	return USB_FND_CONTINUE;
}

static struct usb_fn_drv _ms_os_20_drv = {
	.ctrl_req = _ms_os_20_ctrl_req,
};


void main()
{
	int cmd = 0;
	bool do_dfu = false;

	/* Init console IO */
	console_init();
	puts("Booting DFU image..\n");

	/* SPI */
	spi_init();
	flash_reset();

	/* Should we expose the 'bootloader' section as writable? */
#if 0
	if ((btn_get() & BTN_START) == 0)
	{
#endif

#if 0
		/* We patch the descriptor length ... in RO section but not really RO */
		struct usb_conf_desc *conf = (void*)dfu_stack_desc.conf[0];
		conf->wTotalLength -= 18;

		/* Set protection bits so apps also can't accidentally brick the badge. */
		flash_write_protect_bootloader();
#endif

#if 0
	}
#endif

	/* Should we directly boot to app ? */
	do_dfu |= btn_get();

#if 0
	if (!do_dfu)
		reboot_now();
#endif

	/* Enable USB */
	serial_no_init();

	usb_init(&dfu_stack_desc);
	usb_dfu_init();
	usb_register_function_driver(&_ms_os_20_drv);
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
				usb_dfu_cb_reboot();
				break;
			default:
				break;
			}
		}

		/* USB poll */
		usb_poll();
	}
}
