/*
 * hub75_phy.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * Copyright (C) 2019  Piotr Esden-Tempski <piotr@esden.net>
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

`default_nettype none

module hub75_phy #(
	parameter integer N_BANKS  = 2,
	parameter integer N_ROWS   = 32,
	parameter integer N_CHANS  = 3,
	parameter integer PHY_N    = 1,		// # of PHY in //
	parameter integer PHY_AIR  = 0,		// PHY Address Inc/Reset

	// Auto-set
	parameter integer SDW         = N_BANKS * N_CHANS,
	parameter integer LOG_N_ROWS  = $clog2(N_ROWS)
)(
	// Hub75 interface pads
	output wire [PHY_N-1:0] hub75_addr_inc,
	output wire [PHY_N-1:0] hub75_addr_rst,
	output wire [(PHY_N*LOG_N_ROWS)-1:0] hub75_addr,
	output wire [SDW-1  :0] hub75_data,
	output wire [PHY_N-1:0] hub75_clk,
	output wire [PHY_N-1:0] hub75_le,
	output wire [PHY_N-1:0] hub75_blank,

	// PHY interface signals
	input wire phy_addr_inc,
	input wire phy_addr_rst,
	input wire [LOG_N_ROWS-1:0] phy_addr,
	input wire [SDW-1:0] phy_data,
	input wire phy_clk,
	input wire phy_le,
	input wire phy_blank,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);
	// Signals
		// Delay to match DDR clk output
	wire phy_addr_inc_d;
	wire phy_addr_rst_d;
	wire [LOG_N_ROWS-1:0] phy_addr_d;
	wire [SDW-1:0] phy_data_d;
	wire phy_le_d;
	wire phy_blank_d;

	// Address
	genvar i;
	generate
		if (PHY_AIR == 0) begin
			for (i=0; i<PHY_N; i=i+1)
			begin
				delay_bus #(2, LOG_N_ROWS) dly_addr_I (phy_addr, phy_addr_d, clk);

				OFS1P3DX ior_addr_I[LOG_N_ROWS-1:0] (
					.CD(rst),
					.D(phy_addr_d),
					.SP(1'b1),
					.SCLK(clk),
					.Q(hub75_addr[i*LOG_N_ROWS+:LOG_N_ROWS])
				);
			end
		end else begin
//			SB_IO #(
//				.PIN_TYPE(6'b010100),
//				.PULLUP(1'b0),
//				.NEG_TRIGGER(1'b0),
//				.IO_STANDARD("SB_LVCMOS")
//			) iob_addr_inc_I[PHY_N-1:0] (
//				.PACKAGE_PIN(hub75_addr_inc),
//				.CLOCK_ENABLE(1'b1),
//				.OUTPUT_CLK(clk),
//				.D_OUT_0(phy_addr_inc ^ PHY_AIR[1])
//			);
//
//			SB_IO #(
//				.PIN_TYPE(6'b010100),
//				.PULLUP(1'b0),
//				.NEG_TRIGGER(1'b0),
//				.IO_STANDARD("SB_LVCMOS")
//			) iob_addr_rst_I[PHY_N-1:0] (
//				.PACKAGE_PIN(hub75_addr_rst),
//				.CLOCK_ENABLE(1'b1),
//				.OUTPUT_CLK(clk),
//				.D_OUT_0(phy_addr_rst ^ PHY_AIR[2])
//			);
		end
	endgenerate

	// Data lines
	delay_bus #(2, SDW) dly_data_I (phy_data, phy_data_d, clk);

	OFS1P3DX ior_data_I[SDW-1:0] (
		.CD(rst),
		.D(phy_data_d),
		.SP(1'b1),
		.SCLK(clk),
		.Q(hub75_data)
	);

	// Clock DDR register
	ODDRX1F ior_clk_I[PHY_N-1:0] (
		.D0(1'b0),
		.D1(phy_clk),
		.RST(1'b0),
		.SCLK(clk),
		.Q(hub75_clk)
	);

	// Latch
	delay_bit #(2) dly_le_I (phy_le, phy_le_d, clk);

	OFS1P3DX ior_le_I[PHY_N-1:0] (
		.CD(rst),
		.D(phy_le_d),
		.SP(1'b1),
		.SCLK(clk),
		.Q(hub75_le)
	);

	// Blanking
	delay_bit #(2) dly_blank_I (phy_blank, phy_blank_d, clk);

	OFS1P3DX ior_blank_I[PHY_N-1:0] (
		.CD(rst),
		.D(phy_blank_d),
		.SP(1'b1),
		.SCLK(clk),
		.Q(hub75_blank)
	);

endmodule
