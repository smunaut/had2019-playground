/*
 * psram.c
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

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "console.h"
#include "psram.h"


struct psram {
	/* Main control and status */
	uint32_t csr;

	/* Reserved */
	uint32_t _rsvd1;

	/* Response read */
	struct {
		uint32_t nowait;
		uint32_t block;
	} resp;

	/* Reserved */
	uint32_t _rsvd2[4];

	/* Commands */
	struct {
		uint32_t spi_wr_16b;
		uint32_t spi_wr_32b;
		uint32_t spi_rd_16b;
		uint32_t spi_rd_32b;
		uint32_t qpi_wr_16b;
		uint32_t qpi_wr_32b;
		uint32_t qpi_rd_16b;
		uint32_t qpi_rd_32b;
	} cmd;
} __attribute__((packed,aligned(4)));

static volatile struct psram * const psram_regs = (void*)(PSRAM_BASE);


void
psram_init(void)
{
	printf("%08x\n", psram_regs->csr);
}


#define PSRAM_CMD_QPI_WRITE	0x38
#define PSRAM_CMD_QPI_READ	0xEB
#define PSRAM_CMD_QPI_ENTER	0x35
#define PSRAM_CMD_QPI_EXIT	0xF5
#define PSRAM_CMD_READ_ID	0x9F

#define DUAL_CMD(x) (((x) << 8) | (x))

void
psram_read(void *dst, uint32_t addr, unsigned len)
{
	uint8_t addr_b[3];
	uint32_t cmd[2];

	/* Request manual control */
	psram_regs->csr = (1 << 1);

	/* Command */
	addr_b[2] = (addr >> 16) & 0xff;
	addr_b[1] = (addr >>  8) & 0xff;
	addr_b[0] = (addr      ) & 0xff;

	cmd[0] = (addr_b[2] << 24) | (addr_b[2] << 16) | DUAL_CMD(PSRAM_CMD_QPI_READ);
	cmd[1] = (addr_b[1] << 24) | (addr_b[1] << 16) | (addr_b[0] << 8) | (addr_b[0]);

	printf("CMD: %08x %08x\n", cmd[0], cmd[1]);

	psram_regs->cmd.qpi_wr_32b = cmd[0];
	psram_regs->cmd.qpi_wr_32b = cmd[1];

	/* Dummy */
	psram_regs->cmd.qpi_rd_16b = 0;
	psram_regs->cmd.qpi_rd_16b = 0;
	psram_regs->cmd.qpi_rd_16b = 0;

	/* Read */
	psram_regs->cmd.qpi_rd_32b = 0;

	/* Release manual control */
	psram_regs->csr = (1 << 2);

	/* Wait for completion */
	while (!(psram_regs->csr & (1 << 4)));

	/* Get response */
	*((uint32_t*)dst) = psram_regs->resp.block; /* Dummy */
	*((uint32_t*)dst) = psram_regs->resp.block; /* Dummy */
	*((uint32_t*)dst) = psram_regs->resp.block; /* Dummy */
	*((uint32_t*)dst) = psram_regs->resp.block;
}

void
psram_write(void *dst, uint32_t addr, unsigned len)
{
	uint8_t addr_b[3];
	uint32_t cmd[2];

	/* Request manual control */
	psram_regs->csr = (1 << 1);

	/* Command */
	addr_b[2] = (addr >> 16) & 0xff;
	addr_b[1] = (addr >>  8) & 0xff;
	addr_b[0] = (addr      ) & 0xff;

	cmd[0] = (addr_b[2] << 24) | (addr_b[2] << 16) | DUAL_CMD(PSRAM_CMD_QPI_WRITE);
	cmd[1] = (addr_b[1] << 24) | (addr_b[1] << 16) | (addr_b[0] << 8) | (addr_b[0]);

	printf("CMD: %08x %08x\n", cmd[0], cmd[1]);

	psram_regs->cmd.qpi_wr_32b = cmd[0];
	psram_regs->cmd.qpi_wr_32b = cmd[1];

	/* Data */
	psram_regs->cmd.qpi_wr_32b = 0x12345678; // *((uint32_t*)dst);

	/* Release manual control */
	psram_regs->csr = (1 << 2);

	/* Wait for completion */
	while (!(psram_regs->csr & (1 << 4)));
}

void
psram_qpi_enter(void)
{
	/* Request manual control */
	psram_regs->csr = (1 << 1);

	/* Command */
	psram_regs->cmd.spi_wr_16b = DUAL_CMD(PSRAM_CMD_QPI_ENTER);

	/* Release manual control */
	psram_regs->csr = (1 << 2);

	/* Wait for completion */
	while (!(psram_regs->csr & (1 << 4)));
}

void
psram_qpi_exit(void)
{
	/* Request manual control */
	psram_regs->csr = (1 << 1);

	/* Command */
	psram_regs->cmd.qpi_wr_16b = DUAL_CMD(PSRAM_CMD_QPI_EXIT);

	/* Release manual control */
	psram_regs->csr = (1 << 2);

	/* Wait for completion */
	while (!(psram_regs->csr & (1 << 4)));
}

void
psram_get_id(uint8_t *id)
{
	/* Request manual control */
	psram_regs->csr = (1 << 1);

	/* Command */
	psram_regs->cmd.spi_wr_32b = DUAL_CMD(PSRAM_CMD_READ_ID);
	psram_regs->cmd.spi_wr_32b = 0;
	psram_regs->cmd.spi_rd_32b = 0;
	psram_regs->cmd.spi_rd_32b = 0;
	psram_regs->cmd.spi_rd_32b = 0;
	psram_regs->cmd.spi_rd_32b = 0;

	/* Release manual control */
	psram_regs->csr = (1 << 2);

	/* Wait for completion */
	while (!(psram_regs->csr & (1 << 4)));

	/* Read off data */
	printf("%08x\n", psram_regs->resp.block);
	printf("%08x\n", psram_regs->resp.block);
	printf("%08x\n", psram_regs->resp.block);
	printf("%08x\n", psram_regs->resp.block);
}
