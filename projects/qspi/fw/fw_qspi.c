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
#include "psram.h"
#include "utils.h"

#include "config.h"


struct qpi_test {
	uint32_t csr;
	uint32_t _rsvd[63];
	uint32_t buf[64];
} __attribute__((packed,aligned(4)));

static volatile struct qpi_test * const qpi_test_regs = (void*)(QPI_TEST_BASE);


struct synth {
	struct {
		uint32_t r[8];
	} voice[16];
	uint32_t global[128];
} __attribute__((packed,aligned(4)));

static volatile struct synth * const synth_regs = (void*)(SYNTH_BASE);

static void
yolo(void)
{
	uint32_t addr;
	uint32_t check[2] = {0,0};
	uint32_t cv;

	/* Write the whole memory with alternating random pages */

		/* Even: Fill test buffer */
	for (int i=0; i<64; i++)
		check[0] ^= (qpi_test_regs->buf[i] = (79123411 * i) ^ -(17712347 * (i^32)));

		/* Even: Write */
	for (addr=0; addr < (1<<23); addr += 256)
	{
		/* Progress */
		if ((addr & 0xff00) == 0)
			printf("Writing Even %08x\n", addr);

		/* Issue write command */
		qpi_test_regs->csr = (0 << 31) | ((64-2) << 24) | addr;

		/* Wait for completion */
		while (qpi_test_regs->csr & 0xc0000000);
	}

		/* Odd: Fill test buffer */
	for (int i=0; i<64; i++)
		check[1] ^= (qpi_test_regs->buf[i] = (17712347 * i) ^ -(79123411 * (i^32)));

		/* Odd: Write */
	for (addr=128; addr < (1<<23); addr += 256)
	{
		/* Progress */
		if ((addr & 0xff00) == 0)
			printf("Writing Odd %08x\n", addr);

		/* Issue write command */
		qpi_test_regs->csr = (0 << 31) | ((64-2) << 24) | addr;

		/* Wait for completion */
		while (qpi_test_regs->csr & 0xc0000000);
	}

	/* Read the whole memory */
	for (addr=0; addr < (1<<23); addr += 128)
	{
		/* Progress */
		if ((addr & 0xff80) == 0)
			printf("Reading %08x\n", addr);

		/* Issue read command */
		qpi_test_regs->csr = (1 << 31) | ((64-2) << 24) | addr;

		/* Wait for completion */
		while (qpi_test_regs->csr & 0xc0000000);

		/* Check the page */
		cv = check[(addr >> 7) & 1];

		for (int i=0; i<64; i++)
			cv ^= qpi_test_regs->buf[i];

		if (cv)
			printf("Err @ %08x : %08x\n", addr, cv);
	}
}

void main()
{
	int cmd = 0;

	/* Init console IO */
	console_init();
	puts("Booting QSPI image..\n");

	/* PSRAM */
	psram_init();

	/* Synth */
	synth_regs->voice[0].r[0] = 0x00000005;	/* Control */
        synth_regs->voice[0].r[2] = 0x00000400;	/* Phase INC */
        synth_regs->voice[0].r[3] = 0x00001000;	/* Phase CMP */
        synth_regs->voice[0].r[4] = 0x00004040;	/* Volume */
        synth_regs->voice[0].r[5] = 0x00000010;	/* Duration */
        synth_regs->voice[0].r[6] = 0x00000110;	/* Attack config */
        synth_regs->voice[0].r[7] = 0x0000ff40;	/* Decay config */

	synth_regs->voice[1].r[0] = 0x0000000d;	/* Control */
        synth_regs->voice[1].r[2] = 0x00008000;	/* Phase INC */
        synth_regs->voice[1].r[3] = 0x00001000;	/* Phase CMP */
        synth_regs->voice[1].r[4] = 0x0000f0f0;	/* Volume */
        synth_regs->voice[1].r[5] = 0x00000040;	/* Duration */
        synth_regs->voice[1].r[6] = 0x0000c001;	/* Attack config */
        synth_regs->voice[1].r[7] = 0x0000c001;	/* Decay config */

	synth_regs->global[0] = 0x000003e6;	/* Divider */
	synth_regs->global[1] = 0x000000ff;	/* Global Volume */
	//synth_regs->global[2] = 0x00000001;	/* Voice force gate */


	/* Main loop */
	while (1)
	{
		/* Prompt ? */
		if (cmd >= 0)
			printf("Command> ");

		/* Poll for command */
		cmd = getchar_nowait();

		if (cmd >= 0) {
			uint32_t x[2];

			if (cmd > 32 && cmd < 127) {
				putchar(cmd);
				putchar('\r');
				putchar('\n');
			}

			switch (cmd)
			{
			case'0':
				synth_regs->voice[1].r[0] = 0x00000001;	/* Control */
				break;
			case'1':
				synth_regs->voice[1].r[0] = 0x00000005;	/* Control */
				break;
			case'2':
				synth_regs->voice[1].r[0] = 0x00000009;	/* Control */
				break;
			case'3':
				synth_regs->voice[1].r[0] = 0x0000000d;	/* Control */
				break;
			case '4':
				synth_regs->voice[1].r[6] = 0x0000c001;	/* Attack config */
				synth_regs->voice[1].r[7] = 0x0000c001;	/* Decay config */
				break;
			case '5':
				synth_regs->voice[1].r[6] = 0x00001010;	/* Attack config */
				synth_regs->voice[1].r[7] = 0x00001010;	/* Decay config */
				break;


			case 's':
				synth_regs->global[3] = 0x00000002;	/* Voice force gate */
				break;

			case 'e':
				psram_qpi_enter();
				break;

			case 'd':
				psram_qpi_exit();
				break;

			case 't':
				psram_read(&x[1], 0, 4);

				x[0] = 0xbadc0fee;
				psram_write(&x[0], 0, 4);
				x[0] = 0x01234567;

				psram_read(&x[0], 0, 4);
				printf("%08x\n", x[1]);
				printf("%08x\n", x[0]);
				break;

			case 'y':
				yolo();
				break;

			case 'p':
				printf("CSR  %08x\n", qpi_test_regs->csr);
				for (int i=0; i<64; i=i+1) {
					if ((i & 3) == 0)
						printf("[%02x] ", i);
					printf("%08x%c", qpi_test_regs->buf[i], ((i & 3) == 3) ? '\n' : ' ');
				}
				break;

			case 'r':
				for (int i=0; i<64; i=i+1) {
					uint32_t v = (79123411 * i) ^ -(17712347 * (i^32));
					if ((i & 3) == 0)
						printf("[%02x] ", i);
					printf("%08x%c", v, ((i & 3) == 3) ? '\n' : ' ');
				}
				break;

			case 'i':
				psram_get_id(NULL);
				break;

			default:
				break;
			}
		}
	}
}
