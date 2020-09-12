/*
 * usb_desc_dfu.c
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

#include "usb_proto.h"
#include "usb.h"

#define NULL ((void*)0)
#define num_elem(a) (sizeof(a) / sizeof(a[0]))

#define U16_TO_U8_LE(x) ((x) & 0xff), (((x) >> 8) & 0xff)
#define U32_TO_U8_LE(x) ((x) & 0xff), (((x) >> 8) & 0xff), (((x) >> 16) & 0xff), (((x) >> 24) & 0xff)


enum microsoft_os_20_type
{
	MS_OS_20_SET_HEADER_DESCRIPTOR		= 0x00,
	MS_OS_20_SUBSET_HEADER_CONFIGURATION	= 0x01,
	MS_OS_20_SUBSET_HEADER_FUNCTION		= 0x02,
	MS_OS_20_FEATURE_COMPATBLE_ID		= 0x03,
	MS_OS_20_FEATURE_REG_PROPERTY		= 0x04,
	MS_OS_20_FEATURE_MIN_RESUME_TIME	= 0x05,
	MS_OS_20_FEATURE_MODEL_ID		= 0x06,
	MS_OS_20_FEATURE_CCGP_DEVICE		= 0x07,
	MS_OS_20_FEATURE_VENDOR_REVISION	= 0x08,
};

const uint8_t desc_ms_os_20[0x1E] = {
	/* Set header: length, type, windows version, total length */
	U16_TO_U8_LE(0x000A),
	U16_TO_U8_LE(MS_OS_20_SET_HEADER_DESCRIPTOR),
	U32_TO_U8_LE(0x06030000),
	U16_TO_U8_LE(sizeof(desc_ms_os_20)),

	/* MS OS 2.0 Compatible ID descriptor: length, type, compatible ID, sub compatible ID */
	U16_TO_U8_LE(0x0014),
	U16_TO_U8_LE(MS_OS_20_FEATURE_COMPATBLE_ID),
	'W', 'I', 'N', 'U', 'S', 'B', 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};


static const struct {
	struct usb_conf_desc conf;
	struct usb_intf_desc if_fpga;
	struct usb_dfu_desc dfu_fpga;
	struct usb_intf_desc if_riscv;
	struct usb_dfu_desc dfu_riscv;
	struct usb_intf_desc if_bootloader;
	struct usb_dfu_desc dfu_bootloader;
} __attribute__ ((packed)) _dfu_conf_desc = {
	.conf = {
		.bLength                = sizeof(struct usb_conf_desc),
		.bDescriptorType        = USB_DT_CONF,
		.wTotalLength           = sizeof(_dfu_conf_desc),
		.bNumInterfaces         = 1,
		.bConfigurationValue    = 1,
		.iConfiguration         = 4,
		.bmAttributes           = 0x80,
		.bMaxPower              = 0x32, /* 100 mA */
	},
	.if_fpga = {
		.bLength		= sizeof(struct usb_intf_desc),
		.bDescriptorType	= USB_DT_INTF,
		.bInterfaceNumber	= 0,
		.bAlternateSetting	= 0,
		.bNumEndpoints		= 0,
		.bInterfaceClass	= 0xfe,
		.bInterfaceSubClass	= 0x01,
		.bInterfaceProtocol	= 0x02,
		.iInterface		= 5,
	},
	.dfu_fpga = {
		.bLength		= sizeof(struct usb_dfu_desc),
		.bDescriptorType	= USB_DT_DFU,
		.bmAttributes		= 0x0d,
		.wDetachTimeOut		= 1000,
		.wTransferSize		= 4096,
		.bcdDFUVersion		= 0x0101,
	},
	.if_riscv = {
		.bLength		= sizeof(struct usb_intf_desc),
		.bDescriptorType	= USB_DT_INTF,
		.bInterfaceNumber	= 0,
		.bAlternateSetting	= 1,
		.bNumEndpoints		= 0,
		.bInterfaceClass	= 0xfe,
		.bInterfaceSubClass	= 0x01,
		.bInterfaceProtocol	= 0x02,
		.iInterface		= 6,
	},
	.dfu_riscv = {
		.bLength		= sizeof(struct usb_dfu_desc),
		.bDescriptorType	= USB_DT_DFU,
		.bmAttributes		= 0x0d,
		.wDetachTimeOut		= 1000,
		.wTransferSize		= 4096,
		.bcdDFUVersion		= 0x0101,
	},
	.if_bootloader = {
		.bLength		= sizeof(struct usb_intf_desc),
		.bDescriptorType	= USB_DT_INTF,
		.bInterfaceNumber	= 0,
		.bAlternateSetting	= 2,
		.bNumEndpoints		= 0,
		.bInterfaceClass	= 0xfe,
		.bInterfaceSubClass	= 0x01,
		.bInterfaceProtocol	= 0x02,
		.iInterface		= 7,
	},
	.dfu_bootloader = {
		.bLength		= sizeof(struct usb_dfu_desc),
		.bDescriptorType	= USB_DT_DFU,
		.bmAttributes		= 0x0d,
		.wDetachTimeOut		= 1000,
		.wTransferSize		= 4096,
		.bcdDFUVersion		= 0x0101,
	},
};

static const struct usb_conf_desc * const _conf_desc_array[] = {
	&_dfu_conf_desc.conf,
};

static const struct usb_dev_desc _dev_desc = {
	.bLength		= sizeof(struct usb_dev_desc),
	.bDescriptorType	= USB_DT_DEV,
	.bcdUSB			= 0x0201,
	.bDeviceClass		= 0,
	.bDeviceSubClass	= 0,
	.bDeviceProtocol	= 0,
	.bMaxPacketSize0	= 64,
	.idVendor		= 0x1d50,
	.idProduct		= 0x614b,
	.bcdDevice		= 0x0005,	/* v0.5 */
	.iManufacturer		= 2,
	.iProduct		= 3,
	.iSerialNumber		= 1,
	.bNumConfigurations	= num_elem(_conf_desc_array),
};

static const struct {
	struct usb_bos_desc bos;
	struct usb_bos_plat_cap_hdr cap_hdr;
	uint8_t cap_data[8];
} __attribute__ ((packed)) _dfu_bos_desc = {
	.bos = {
		.bLength		= sizeof(struct usb_bos_desc),
		.bDescriptorType	= USB_DT_BOS,
		.wTotalLength		= sizeof(_dfu_bos_desc),
		.bNumDeviceCaps		= 1,
	},
	.cap_hdr = {
		.bLength		= sizeof(struct usb_bos_plat_cap_hdr) + 8,
		.bDescriptorType	= USB_DT_DEV_CAP,
		.bDevCapabilityType	= 5, /* PLATFORM */
		.bReserved		= 0,
		.PlatformCapabilityUUID	= {
			0xDF, 0x60, 0xDD, 0xD8, 0x89, 0x45, 0xC7, 0x4C,
			0x9C, 0xD2, 0x65, 0x9D, 0x9E, 0x64, 0x8A, 0x9F,
		},
	},
	.cap_data = {
		U32_TO_U8_LE(0x06030000),		/* dwWindowsVersion */
		U16_TO_U8_LE(sizeof(desc_ms_os_20)),	/* wMSOSDescriptorSetTotalLength */
		0x01,					/* bMS_VendorCode */
		0x00,					/* bAltEnumCode */
	},
};


#include "usb_str_dfu.gen.h"

const struct usb_stack_descriptors dfu_stack_desc = {
	.dev    = &_dev_desc,
	.bos    = &_dfu_bos_desc.bos,
	.conf   = _conf_desc_array,
	.n_conf = num_elem(_conf_desc_array),
	.str    = _str_desc_array,
	.n_str  = num_elem(_str_desc_array),
};
