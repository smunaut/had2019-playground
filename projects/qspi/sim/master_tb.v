/*
 * master_tb.v
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

module master_tb;

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

	wire [ 1:0] bus_addr;
	wire [31:0] bus_wdata;
	wire [31:0] bus_rdata;
	wire bus_cyc;
	wire bus_ack;
	wire bus_we;

	// Setup recording
	initial begin
		$dumpfile("master_tb.vcd");
		$dumpvars(0,master_tb);
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
	qspi_master_wb #(
		.N_CS(1)
	) dut_I (
		.spi_io_i(spi_io_i),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_io_t),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.bus_addr(bus_addr),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata),
		.bus_cyc(bus_cyc),
		.bus_ack(bus_ack),
		.bus_we(bus_we),
		.clk(clk_1x),
		.rst(rst)
	);

	qspi_phy_ecp5 #(
		.N_CS(1)
	) phy_I (
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
	reg x;

	always @(posedge clk_1x)
		if (rst)
			cnt <= 0;
		else
			cnt <= cnt + 1;

	always @(posedge clk_1x)
		if (rst)
			x <= 1'b0;
		else
			x <= (x & ~bus_ack) | ((cnt == 8'h10) | (cnt == 8'h12) | (cnt == 8'h14));

	assign bus_addr = 2'b01;
	assign bus_wdata = cnt[1] ? 32'h000000c5 : 32'h000002c5;
	assign bus_we = 1'b1;
	assign bus_cyc = x;

//	assign spi_io[1] = cnt[4] ? spi_io[0] : 1'bz;

endmodule // master_tb
