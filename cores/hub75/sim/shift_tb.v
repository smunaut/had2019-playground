/*
 * shift_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
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
`timescale 1ns / 100ps

module shift_tb;

	// Signals
	reg rst = 1'b1;
	reg clk_1x = 1'b0;
	reg clk_2x = 1'b0;

	wire [5:0] phy_data;
	wire phy_clk;

	reg  [(2*3*8)-1:0] ram_data;
	wire [5:0] ram_col_addr;
	wire ram_rden;

	wire [7:0] ctrl_plane;
	wire ctrl_go;
	wire ctrl_rdy;

	// Setup recording
	initial begin
		$dumpfile("shift_tb.vcd");
		$dumpvars(0,shift_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 1000000 $finish;
	end

	// Clocks
	always #20 clk_1x = !clk_1x;
	always #10 clk_2x = !clk_2x;

	// DUT
	hub75_shift #(
		.N_BANKS(2),
		.N_COLS(64),
		.N_CHANS(3),
		.N_PLANES(8)
	) dut_I (
		.phy_data(phy_data),
		.phy_clk(phy_clk),
		.ram_data(ram_data),
		.ram_col_addr(ram_col_addr),
		.ram_rden(ram_rden),
		.ctrl_plane(ctrl_plane),
		.ctrl_go(ctrl_go),
		.ctrl_rdy(ctrl_rdy),
		.clk(clk_1x),
		.rst(rst)
	);

	assign ctrl_plane = 8'h01;
	reg [7:0] delay;

	integer i;
	always @(posedge clk_1x)
		if (ram_rden)
		begin
			ram_data <= 0;
			for (i=0; i<6; i=i+1)
				ram_data[i*8] <= ram_col_addr[i];
		end
	
	always @(posedge clk_1x)
		if (rst)
			delay <= 0;
		else if (ctrl_rdy)
			delay <= delay + 1;
		else
			delay <= 0;
			
	assign ctrl_go = delay[7] & ctrl_rdy;

	phy_test x (
		.phy_data(phy_data),
		.phy_clk(phy_clk),
		.clk_1x(clk_1x),
		.clk_2x(clk_2x)
	);

endmodule // shift_tb


module phy_test (
	output wire [2:0] pad_data,
	output wire pad_clk,
	input wire [5:0] phy_data,
	input wire phy_clk,
	input wire clk_1x,
	input wire clk_2x
);


	reg msel;
	reg msel2;
	reg [2:0] phy_data_mux;


	always @(posedge clk_2x)
		msel <= (msel ^ 1'b1) & phy_clk;
	
	always @(posedge clk_2x)
		msel2 <= msel;

	always @(posedge clk_2x)
		phy_data_mux <= msel ? phy_data[2:0] : phy_data[5:3];

	SB_IO #(
		.PIN_TYPE(6'b010100),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_data_I[2:0] (
		.PACKAGE_PIN(pad_data),
		.CLOCK_ENABLE({3{1'b1}}),
		.OUTPUT_CLK({3{clk_2x}}),
		.D_OUT_0(phy_data_mux)
	);

	SB_IO #(
		.PIN_TYPE(6'b010000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_I (
		.PACKAGE_PIN(pad_clk),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk_2x),
		.D_OUT_0(~msel2),
		.D_OUT_1(~msel2)
	);

endmodule

