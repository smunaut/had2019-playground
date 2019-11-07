/*
 * synth_wb.v
 *
 * vim: ts=4 sw=4
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
 */

`default_nettype none

module synth_wb (
	// Audio output
	output wire [15:0] audio_out_l,
	output wire [15:0] audio_out_r,

	// Bus interface
	input  wire [15:0] bus_addr,
	input  wire [31:0] bus_wdata,
	output wire [31:0] bus_rdata,
	input  wire bus_cyc,
	output wire bus_ack,
	input  wire bus_we,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Config bus
	wire [31:0] cb_data;
	wire [ 3:0] cb_voice;
	wire [ 2:0] cb_reg;
	reg  cb_stb_v;
	reg  cb_stb_g;

	// Wave Table
	wire [11:0] wtw_addr;
	wire [31:0] wtw_data;
	reg  wtw_ena;

	wire [11:0] wtr_addr_0;
	reg  [ 1:0] wtr_bytesel_1;
	wire [31:0] wtr_data32_1;
	reg  [ 7:0] wtr_data8_1;


	// Core
	// ----

	synth_core core_I (
		.audio_out_l(audio_out_l),
		.audio_out_r(audio_out_r),
		.wt_addr(wtr_addr_0),
		.wt_data(wtr_data8_1),
		.cb_data(cb_data),
		.cb_voice(cb_voice),
		.cb_reg(cb_reg),
		.cb_stb_v(cb_stb_v),
		.cb_stb_g(cb_stb_g),
		.clk(clk),
		.rst(rst)
	);


	// Wave Table
	// ----------

	// FPGA could handle width adaptation ... but not with inferrence and
	// I don't want to bother with instantiation here

	ram_sdp #(
		.AWIDTH(10),
		.DWIDTH(32)
	) wt_I (
		.wr_addr(wtw_addr),
		.wr_data(wtw_data),
		.wr_ena(wtw_ena),
		.rd_addr(wtr_addr_0),
		.rd_data(wtr_data32_1),
		.rd_ena(1'b1),
		.clk(clk)
	);

	always @(posedge clk)
		wtr_bytesel_1 <= wtr_addr_0[1:0];

	always @(*)
		case (wtr_bytesel_1)
			2'b00:   wtr_data8_1 = wtr_data32_1[ 7: 0];
			2'b01:   wtr_data8_1 = wtr_data32_1[15: 8];
			2'b10:   wtr_data8_1 = wtr_data32_1[23:16];
			2'b11:   wtr_data8_1 = wtr_data32_1[31:24];
			default: wtr_data8_1 = 8'hxx;
		endcase


	// Bus Interface
	// -------------

	reg ack;

	// Ack
	always @(posedge clk)
		ack <= bus_cyc & ~bus_ack;

	assign bus_ack = ack;

	// Read Mux
	assign bus_rdata = 32'h00000000;

	// Config Bus write
	assign cb_data  = bus_wdata;
	assign cb_voice = bus_addr[6:3];
	assign cb_reg   = bus_addr[2:0];

	always @(posedge clk)
		if (ack) begin
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b0;
		end else begin
			cb_stb_v <= bus_cyc & bus_we & (bus_addr[15:14] == 2'b00) & ~bus_addr[7];
			cb_stb_g <= bus_cyc & bus_we & (bus_addr[15:14] == 2'b00) &  bus_addr[7];
		end

	// Wave Table write
	assign wtw_addr = bus_addr[11:0];
	assign wtw_data = bus_wdata;

	always @(posedge clk)
		if (ack)
			wtw_ena <= 1'b0;
		else
			wtw_ena <= bus_cyc & bus_we & (bus_addr[15:14] == 2'b11);

endmodule // synth_wb
