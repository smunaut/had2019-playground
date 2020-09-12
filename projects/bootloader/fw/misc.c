/*
 * misc.c
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

#include "config.h"
#include "misc.h"


struct had_misc {
	uint32_t ctrl;
	uint32_t pwm;
} __attribute__((packed,aligned(4)));

static volatile struct had_misc * const had_misc_regs = (void*)(HAD_MISC_BASE);


// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

uint32_t
btn_get(void)
{
	return ((had_misc_regs->ctrl >> 16) & 1) ^ 1;
}


// ---------------------------------------------------------------------------
// LEDs
// ---------------------------------------------------------------------------

void
led_on(int n)
{
	had_misc_regs->ctrl |= (1 << n);
}

void
led_off(int n)
{
	had_misc_regs->ctrl &= ~(1 << n);
}

void
led_set_pwm(int n, int level)
{
	had_misc_regs->pwm = (had_misc_regs->pwm & ~(7 << (3*n))) | (level << (3*n));
}


// ---------------------------------------------------------------------------
// Reboot
// ---------------------------------------------------------------------------

void __attribute__((noreturn))
reboot_now(void)
{
	had_misc_regs->ctrl = (had_misc_regs->ctrl & 0x00ffffff) | 0xa5000000;
	while (1);
}
