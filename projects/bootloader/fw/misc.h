/*
 * misc.h
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

#pragma once

#define BTN_UP		(1 << 0)
#define BTN_DOWN	(1 << 1)
#define BTN_LEFT	(1 << 2)
#define BTN_RIGHT	(1 << 3)
#define BTN_B		(1 << 4)
#define BTN_A		(1 << 5)
#define BTN_SELECT	(1 << 6)
#define BTN_START	(1 << 7)

#define LCD_BACKLIGHT	9

#define FLASHCHIP_INTERNAL 0
#define FLASHCHIP_CART 1

void flashchip_select(int flash_sel);

uint32_t btn_get(void);

void led_on(int n);
void led_off(int n);
void led_set_pwm(int n, int level);

void reboot_now(void);

void lcd_init(void);
void lcd_on(void);
void lcd_off(void);
void lcd_show_logo(void);
