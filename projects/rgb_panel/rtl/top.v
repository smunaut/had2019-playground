/*
 * top.v
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * vim: ts=4 sw=4
 */

`default_nettype none

module top (
	// LEDs
	output wire [8:0] led,

	// Buttons
	input  wire [7:0] btn,

	// RGB panel PMOD
	output wire [4:0] hub75_addr,
	output wire [5:0] hub75_data,
	output wire hub75_clk,
	output wire hub75_le,
	output wire hub75_blank,

	// Clock
	input  wire clk_8m
);

	// Params
	localparam integer N_BANKS  = 2;
	localparam integer N_ROWS   = 32;
	localparam integer N_COLS   = 64;
	localparam integer N_CHANS  = 3;
	localparam integer N_PLANES = 10;
	localparam integer BITDEPTH = 16;

	localparam integer LOG_N_BANKS = $clog2(N_BANKS);
	localparam integer LOG_N_ROWS  = $clog2(N_ROWS);
	localparam integer LOG_N_COLS  = $clog2(N_COLS);


	// Signals
	// -------

	// Clock / Reset logic
	wire clk;
	wire clk_2x;
	wire rst;

	// Frame buffer write port
	wire [LOG_N_BANKS-1:0] fbw_bank_addr;
	wire [LOG_N_ROWS-1:0]  fbw_row_addr;
	wire fbw_row_store;
	wire fbw_row_rdy;
	wire fbw_row_swap;

	wire [BITDEPTH-1:0] fbw_data;
	wire [LOG_N_COLS-1:0] fbw_col_addr;
	wire fbw_wren;

	wire frame_swap;
	wire frame_rdy;

	// Control
	reg  ctrl_run;


	// Hub75 driver
	// ------------

//	hub75_top #(
//		.N_BANKS(N_BANKS),
//		.N_ROWS(N_ROWS),
//		.N_COLS(N_COLS),
//		.N_CHANS(N_CHANS),
//		.N_PLANES(N_PLANES),
//		.BITDEPTH(BITDEPTH),
//		.PANEL_INIT("FM6126"),
//		.SCAN_MODE("ZIGZAG")
//	) hub75_I (
//		.hub75_addr(hub75_addr),
//		.hub75_data(hub75_data),
//		.hub75_clk(hub75_clk),
//		.hub75_le(hub75_le),
//		.hub75_blank(hub75_blank),
//		.fbw_bank_addr(fbw_bank_addr),
//		.fbw_row_addr(fbw_row_addr),
//		.fbw_row_store(fbw_row_store),
//		.fbw_row_rdy(fbw_row_rdy),
//		.fbw_row_swap(fbw_row_swap),
//		.fbw_data(fbw_data),
//		.fbw_col_addr(fbw_col_addr),
//		.fbw_wren(fbw_wren),
//		.frame_swap(frame_swap),
//		.frame_rdy(frame_rdy),
//		.ctrl_run(ctrl_run),
//		.cfg_pre_latch_len(8'h80),
//		.cfg_latch_len(8'h80),
//		.cfg_post_latch_len(8'h80),
//		.cfg_bcm_bit_len(8'h06),
//		.clk(clk),
//		.clk_2x(clk_2x),
//		.rst(rst)
//	);

	// Only start the scan when we have our first frame
	always @(posedge clk or posedge rst)
		if (rst)
			ctrl_run <= 1'b0;
		else
			ctrl_run <= ctrl_run | frame_swap;


	// Pattern generator
	// -----------------

	pgen #(
		.N_ROWS(N_BANKS * N_ROWS),
		.N_COLS(N_COLS),
		.BITDEPTH(BITDEPTH)
	) pgen_I (
		.fbw_row_addr({fbw_bank_addr, fbw_row_addr}),
		.fbw_row_store(fbw_row_store),
		.fbw_row_rdy(fbw_row_rdy),
		.fbw_row_swap(fbw_row_swap),
		.fbw_data(fbw_data),
		.fbw_col_addr(fbw_col_addr),
		.fbw_wren(fbw_wren),
		.frame_swap(frame_swap),
		.frame_rdy(frame_rdy),
		.clk(clk),
		.rst(rst)
	);


	// Clock / Reset
	// -------------

	sysmgr sys_mgr_I (
		.clk_in(clk_8m),
		.rst_in(1'b0),
		.clk_24m(clk),
		.clk_48m(clk_2x),
		.rst_out(rst)
	);

endmodule // top
