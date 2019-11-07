/*
 * phy_tb.v
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
`timescale 1ns / 100ps

module phy_tb;

	// Signals
	reg rst = 1'b1;
	reg clk_1x = 1'b0;
	reg clk_2x = 1'b0;

	wire [3:0] spi_io;
	wire spi_cs;
	wire spi_sck;

	wire [7:0] spi_io_i;
	wire [7:0] spi_io_o;
	wire [3:0] spi_io_t;
	wire [1:0] spi_sck_o;
	wire spi_cs_o;

	// Setup recording
	initial begin
		$dumpfile("phy_tb.vcd");
		$dumpvars(0,phy_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 20000 $finish;
	end

	// Clocks
	always #10 clk_1x = !clk_1x;
	always #5  clk_2x = !clk_2x;

	// SIM models stuff
	PUR PUR_INST(.PUR(1'b1));
	GSR GSR_INST(.GSR(1'b1));

	// DUT
	qspi_phy_2x_ecp5 #(
		.N_CS(1)
	) dut_I (
		.spi_io(spi_io),
		.spi_cs(spi_cs),	
		.spi_sck(spi_sck),
		.spi_io_i(spi_io_i),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_io_t),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.clk_2x(clk_2x),
		.clk_1x(clk_1x),
		.rst(rst)
	);

	// Generate signals
	reg [7:0] cnt;

	always @(posedge clk_1x)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + 1;

	assign spi_sck_o = { cnt[3], 1'b0 };
	assign spi_cs_o  = cnt[3];
	assign spi_io_t  = cnt[3] ? 4'h0  : 4'hf;
	assign spi_io_o  = cnt[3] ? (8'hC5 + cnt) : 8'h00;

endmodule // phy_tb
