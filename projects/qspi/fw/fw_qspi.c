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


struct audio {
	uint32_t csr;
	uint32_t evt;
	uint32_t pcm_cfg;
	uint32_t pcm_data;
} __attribute__((packed,aligned(4)));

struct synth {
	/* Per-Voice registers */
	struct {
		uint32_t ctrl;
		uint32_t _rsvd;
		uint32_t phase_inc;
		uint32_t phase_cmp;
		uint32_t volume;
		uint32_t duration;
		uint32_t attack;
		uint32_t decay;
	} voice[16];

	/* Global register */
	uint32_t samplerate_div;
	uint32_t volume;
	uint32_t voice_force;
	uint32_t voice_start;
	uint32_t _rsvd[4];

	/* Commands (only valid for queuing !!!) */
	uint32_t cmd_wait;
	uint32_t cmd_gen_event;

} __attribute__((packed,aligned(4)));

static volatile struct audio * const audio_regs  = (void*)((AUDIO_BASE) + 0x00000);
static volatile uint32_t *     const synth_wt    = (void*)((AUDIO_BASE) + 0x10000);
static volatile struct synth * const synth_now   = (void*)((AUDIO_BASE) + 0x20000);
static volatile struct synth * const synth_queue = (void*)((AUDIO_BASE) + 0x30000);

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
	synth_now->voice[0].ctrl      = 0x00000005;	/* Control */
        synth_now->voice[0].phase_inc = 0x00000400;	/* Phase INC */
        synth_now->voice[0].phase_cmp = 0x00001000;	/* Phase CMP */
        synth_now->voice[0].volume    = 0x00004040;	/* Volume */
        synth_now->voice[0].duration  = 0x00000010;	/* Duration */
        synth_now->voice[0].attack    = 0x00000110;	/* Attack config */
        synth_now->voice[0].decay     = 0x0000ff40;	/* Decay config */

	synth_now->samplerate_div = 0x000003e6;	/* Divider */
	synth_now->volume         = 0x000000ff;	/* Global Volume */
	synth_now->voice_force    = 0x00000001;	/* Voice force gate */

	printf("\n");
	printf("Synth[0]: %08x\n", synth_now->samplerate_div);
	printf("Synth[1]: %08x\n", synth_now->volume);
	printf("Synth[2]: %08x\n", synth_now->voice_force);

	printf("Audio[0]: %08x\n", audio_regs->csr);
	printf("Audio[1]: %08x\n", audio_regs->evt);
	printf("Audio[2]: %08x\n", audio_regs->pcm_cfg);

	audio_regs->pcm_cfg = (1 << 31);

	for (int i=0; i<50; i++) {
		synth_queue->voice_force = 0;
		synth_queue->cmd_wait = 10000;
		synth_queue->voice_force = 1;
		synth_queue->cmd_wait = 10000;
        	synth_queue->voice[0].phase_inc = 0x100 * i;
	}

	for (int i=0; i<50; i++)
		printf("Audio[0]: %08x\n", audio_regs->csr);


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
