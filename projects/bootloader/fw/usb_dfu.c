/*
 * usb_dfu.c
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

#include "spi.h"
#include "usb.h"
#include "usb_dfu.h"
#include "usb_dfu_proto.h"


#define DFU_VENDOR_PROTO
#define DFU_UTIL_SPEEDUP_WORDAROUND
#undef DFU_SOF_POLL_LIMIT
#define DFU_HOST_POLL_MS		5

#if 0
#include "console.h"
#define DBG_PRINTF(...) printf(__VA_ARGS__)
#else
#define DBG_PRINTF(...) do {} while (0)
#endif


#ifdef DFU_VENDOR_PROTO
enum usb_fnd_resp dfu_vendor_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer);
#endif


static const uint32_t dfu_valid_req[_DFU_MAX_STATE] = {
	/* appIDLE */
	(1 << USB_REQ_DFU_DETACH) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,

	/* appDETACH */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,

	/* dfuIDLE */
	(1 << USB_REQ_DFU_DETACH) |		/* Non-std */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_UPLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuDNLOAD_SYNC */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuDNBUSY */
	0,

	/* dfuDNLOAD_IDLE */
	(1 << USB_REQ_DFU_DNLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuMANIFEST_SYNC */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuMANIFEST */
	0,

	/* dfuMANIFEST_WAIT_RESET */
	0,

	/* dfuUPLOAD_IDLE */
	(1 << USB_REQ_DFU_UPLOAD) |
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	(1 << USB_REQ_DFU_ABORT) |
	0,

	/* dfuERROR */
	(1 << USB_REQ_DFU_GETSTATUS) |
	(1 << USB_REQ_DFU_CLRSTATUS) |
	(1 << USB_REQ_DFU_GETSTATE) |
	0,
};

static struct {
	enum dfu_state state;
	enum dfu_status status;

	uint8_t intf;	// Selected interface number
	uint8_t alt;	// Selected alt settings

	uint8_t tick;

	struct {
		uint8_t used;
		uint8_t wr;
		uint8_t rd;

		uint8_t data[2][4096] __attribute__((aligned(4)));
	} buf;

	struct {
		uint32_t addr_recv;
		uint32_t addr_prog;
		uint32_t addr_erase;
		uint32_t addr_end;

		int op_ofs;
		int op_len;

		enum {
			FL_IDLE = 0,
			FL_ERASE,
			FL_PROGRAM,
		} op;
	} flash;
} g_dfu;

static const struct {
	uint32_t start;
	uint32_t end;
} dfu_zones[2] = {
	{ 0x00180000, 0x00300000 },	/* ECP5 bitstream */
	{ 0x00300000, 0x00380000 },	/* RISC-V firmware */
};


//static void
void
_dfu_tick(void)
{
	/* Rate limit to once every 10 ms */
#ifdef DFU_SOF_POLL_LIMIT
	if (g_dfu.tick++ < DFU_SOF_POLL_LIMIT)
		return;
	g_dfu.tick = 0;
#endif

	/* Anything to do ? Is flash ready ? */
	if (g_dfu.flash.op == FL_IDLE) {
		if (g_dfu.buf.used) {
			/* Start a new operation */
			g_dfu.flash.op = FL_ERASE;
			g_dfu.flash.op_len = 4096;
			g_dfu.flash.op_ofs = 0;
		} else
			return;
	}

	/* If flash is busy, we're stuck anyway */
	else if (flash_read_sr() & 1)
		return;

	/* Erase */
	if (g_dfu.flash.op == FL_ERASE) {
		/* Done ? */
		if (g_dfu.flash.addr_erase >= (g_dfu.flash.addr_prog + g_dfu.flash.op_len)) {
			/* Yes, move to programming */
			g_dfu.flash.op = FL_PROGRAM;
			DBG_PRINTF("Erase done - t=%d\n", usb_get_tick());
		} else{
			/* No, issue the next command */
#if 0
			DBG_PRINTF("Erase start 4k @ %08x - t=%d\n", g_dfu.flash.addr_erase, usb_get_tick());
			flash_write_enable();
			flash_sector_erase(g_dfu.flash.addr_erase);
			g_dfu.flash.addr_erase += 4096;
#elif 0
			DBG_PRINTF("Erase start 32k @ %08x - t=%d\n", g_dfu.flash.addr_erase, usb_get_tick());
			flash_write_enable();
			flash_block_erase_32k(g_dfu.flash.addr_erase);
			g_dfu.flash.addr_erase += 32768;
#else
			DBG_PRINTF("Erase start 64k @ %08x - t=%d\n", g_dfu.flash.addr_erase, usb_get_tick());
			flash_write_enable();
			flash_block_erase_64k(g_dfu.flash.addr_erase);
			g_dfu.flash.addr_erase += 65536;
#endif
		}
	}

	/* Programming */
	if (g_dfu.flash.op == FL_PROGRAM) {
		/* Done ? */
		if (g_dfu.flash.op_ofs == g_dfu.flash.op_len) {
			/* Yes ! */
			g_dfu.flash.op = FL_IDLE;
			g_dfu.flash.addr_prog += g_dfu.flash.op_len;
			g_dfu.buf.rd ^= 1;
			g_dfu.buf.used--;
		} else {
			/* Max len */
			unsigned l = g_dfu.flash.op_len - g_dfu.flash.op_ofs;
			unsigned pl = 256 - ((g_dfu.flash.addr_prog + g_dfu.flash.op_ofs) & 0xff);
			if (l > pl)
				l = pl;

			/* Write page */
			DBG_PRINTF("Page program start @ %08x - t=%d\n", g_dfu.flash.addr_prog + g_dfu.flash.op_ofs, usb_get_tick());
			flash_write_enable();
			flash_quad_page_program(&g_dfu.buf.data[g_dfu.buf.rd][g_dfu.flash.op_ofs], g_dfu.flash.addr_prog + g_dfu.flash.op_ofs, l);

			/* Next page */
			g_dfu.flash.op_ofs += l;
		}
	}
}

static void
_dfu_bus_reset(void)
{
	if (g_dfu.state != appDETACH)
		usb_dfu_cb_reboot();
}

static void
_dfu_state_chg(enum usb_dev_state state)
{
	if (state == USB_DS_CONFIGURED)
		g_dfu.state = dfuIDLE;
}

static bool
_dfu_detach_done_cb(struct usb_xfer *xfer)
{
	usb_dfu_cb_reboot();
	return true;
}

static bool
_dfu_dnload_done_cb(struct usb_xfer *xfer)
{
	/* Next buffer */
	g_dfu.buf.wr ^= 1;
	g_dfu.buf.used++;

	/* State update */
	g_dfu.state = dfuDNLOAD_SYNC;

	return true;
}

static enum usb_fnd_resp
_dfu_ctrl_req(struct usb_ctrl_req *req, struct usb_xfer *xfer)
{
	uint8_t state;

	/* If this a class or vendor request for DFU interface ? */
	if (req->wIndex != g_dfu.intf)
		return USB_FND_CONTINUE;

#ifdef DFU_VENDOR_PROTO
	if ((USB_REQ_TYPE(req) | USB_REQ_RCPT(req)) == (USB_REQ_TYPE_VENDOR | USB_REQ_RCPT_INTF)) {
		/* Let vendor code use our large buffer */
		xfer->data = g_dfu.buf.data[0];
		xfer->len  = sizeof(g_dfu.buf);

		/* Call vendor code */
		return dfu_vendor_ctrl_req(req, xfer);
	}
#endif

	if ((USB_REQ_TYPE(req) | USB_REQ_RCPT(req)) != (USB_REQ_TYPE_CLASS | USB_REQ_RCPT_INTF))
		return USB_FND_CONTINUE;

	/* Check if this request is allowed in this state */
	if ((dfu_valid_req[g_dfu.state] & (1 << req->bRequest)) == 0)
		goto error;

	/* Handle request */
	switch (req->wRequestAndType)
	{
	case USB_RT_DFU_DETACH:
		/* In theory this should be in runtime mode only but we support
		 * it as a request to reboot to user mode when in DFU mode */
		xfer->cb_done = _dfu_detach_done_cb;
		break;

	case USB_RT_DFU_DNLOAD:
		/* Check for last block */
		if (req->wLength) {
			/* Check length doesn't overflow */
			g_dfu.flash.addr_recv += req->wLength;

			if (g_dfu.flash.addr_recv > g_dfu.flash.addr_end)
				goto error;

			/* Setup buffer for data */
			xfer->len     = req->wLength;
			xfer->data    = g_dfu.buf.data[g_dfu.buf.wr];
			xfer->cb_done = _dfu_dnload_done_cb;

			/* Fill end of buffer with 0xff if not fully used */
			if (xfer->len < 4096) {
				memset(&xfer->data[xfer->len], 0xff, 4096 - xfer->len);
			}
		} else {
			/* Last xfer */
			g_dfu.state = dfuMANIFEST_SYNC;
		}
		break;

	case USB_RT_DFU_UPLOAD:
		/* Not supported */
		goto error;

	case USB_RT_DFU_GETSTATUS:
		/* Update state */
		if (g_dfu.state == dfuDNLOAD_SYNC) {
			if (g_dfu.buf.used < 2) {
				g_dfu.state = state = dfuDNLOAD_IDLE;
			} else {
				state = dfuDNBUSY;
			}
		} else if (g_dfu.state == dfuMANIFEST_SYNC) {
#ifdef DFU_UTIL_SPEEDUP_WORDAROUND
			/* dfu-util adds an unecessary 1s delay if you don't
			 * respond with dfuIDLE directly instead of obeying the
			 * poll timeout ... */
			g_dfu.state = state = dfuIDLE;

			while (g_dfu.buf.used)
				_dfu_tick();
#else
			if (g_dfu.buf.used == 0) {
				g_dfu.state = state = dfuIDLE;
			} else {
				state = dfuMANIFEST;
			}
#endif
		} else {
			state = g_dfu.state;
		}

		/* Return data */
		xfer->data[0] = g_dfu.status;
		xfer->data[1] = (DFU_HOST_POLL_MS >>  0) & 0xff;
		xfer->data[2] = (DFU_HOST_POLL_MS >>  8) & 0xff;
		xfer->data[3] = (DFU_HOST_POLL_MS >> 16) & 0xff;
		xfer->data[4] = state;
		xfer->data[5] = 0;
		break;

	case USB_RT_DFU_CLRSTATUS:
		/* Clear error */
		g_dfu.state = dfuIDLE;
		g_dfu.status = OK;
		break;

	case USB_RT_DFU_GETSTATE:
		/* Return state */
		xfer->data[0] = g_dfu.state;
		break;

	case USB_RT_DFU_ABORT:
		/* Go to IDLE */
		g_dfu.state = dfuIDLE;
		break;

	default:
		goto error;
	}

	return USB_FND_SUCCESS;

error:
	g_dfu.state  = dfuERROR;
	g_dfu.status = errUNKNOWN;
	return USB_FND_ERROR;
}

static enum usb_fnd_resp
_dfu_set_intf(const struct usb_intf_desc *base, const struct usb_intf_desc *sel)
{
	if ((sel->bInterfaceClass != 0xfe) ||
	    (sel->bInterfaceSubClass != 0x01) ||
	    (sel->bInterfaceProtocol != 0x02))
		return USB_FND_CONTINUE;

	g_dfu.state = dfuIDLE;
	g_dfu.intf  = sel->bInterfaceNumber;
	g_dfu.alt   = sel->bAlternateSetting;

	g_dfu.flash.addr_recv  = dfu_zones[g_dfu.alt].start;
	g_dfu.flash.addr_prog  = dfu_zones[g_dfu.alt].start;
	g_dfu.flash.addr_erase = dfu_zones[g_dfu.alt].start;
	g_dfu.flash.addr_end   = dfu_zones[g_dfu.alt].end;

	return USB_FND_SUCCESS;
}

static enum usb_fnd_resp
_dfu_get_intf(const struct usb_intf_desc *base, uint8_t *alt)
{
	if ((base->bInterfaceClass != 0xfe) ||
	    (base->bInterfaceSubClass != 0x01) ||
	    (base->bInterfaceProtocol != 0x02))
		return USB_FND_CONTINUE;

	*alt = g_dfu.alt;

	return USB_FND_SUCCESS;
}


static struct usb_fn_drv _dfu_drv = {
//	.sof		= _dfu_tick,
	.bus_reset	= _dfu_bus_reset,
	.state_chg	= _dfu_state_chg,
	.ctrl_req	= _dfu_ctrl_req,
	.set_intf	= _dfu_set_intf,
	.get_intf	= _dfu_get_intf,
};


void __attribute__((weak))
usb_dfu_cb_reboot(void)
{
	/* Nothing */
}

void
usb_dfu_init(void)
{
	memset(&g_dfu, 0x00, sizeof(g_dfu));

	g_dfu.state = appDETACH;

	usb_register_function_driver(&_dfu_drv);
}
