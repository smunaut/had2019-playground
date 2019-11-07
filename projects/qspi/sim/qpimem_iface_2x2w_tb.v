/*
 * qpimem_iface_2x2w_tb.v
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

module qpimem_iface_2x2w_tb;

	// Signals
	reg rst = 1'b1;
	reg clk_1x = 1'b0;
	reg clk_2x = 1'b0;

	wire [3:0] spi0_io;
	wire spi0_cs;
	wire spi0_sck;

	wire [3:0] spi1_io;
	wire spi1_cs;
	wire spi1_sck;

	wire [15:0] spi_io_i;
	wire [15:0] spi_io_o;
	wire [ 7:0] spi_io_t;
	wire [ 1:0] spi_sck_o;
	wire spi_cs_o;

    wire qpi_do_read;
    wire qpi_do_write;
    wire [23:0] qpi_addr;
    wire qpi_is_idle;
    wire [31:0] qpi_wdata;
    wire [31:0] qpi_rdata;
    wire qpi_next_word;

	reg  [15:0] bus_addr;
	reg  [31:0] bus_wdata;
	wire [31:0] bus_rdata[0:1];
	reg         bus_we;
	reg  [ 1:0] bus_cyc;
	wire [ 1:0] bus_ack;

	// Setup recording
	initial begin
		$dumpfile("qpimem_iface_2x2w_tb.vcd");
		$dumpvars(0,qpimem_iface_2x2w_tb);
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
	qpimem_iface_2x2w dut_I (
		.spi_io_i(spi_io_i),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_io_t),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
    	.qpi_do_read(qpi_do_read),
    	.qpi_do_write(qpi_do_write),
    	.qpi_addr(qpi_addr),
    	.qpi_is_idle(qpi_is_idle),
    	.qpi_wdata(qpi_wdata),
    	.qpi_rdata(qpi_rdata),
    	.qpi_next_word(qpi_next_word),
		.bus_addr(bus_addr[3:0]),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata[0]),
		.bus_cyc(bus_cyc[0]),
		.bus_ack(bus_ack[0]),
		.bus_we(bus_we),
		.clk(clk_1x),
		.rst(rst)
	);

	// PHY Chip 0
	qspi_phy_2x_ecp5 #(
		.N_CS(1)
	) phy0_I (
		.spi_io(spi0_io),
		.spi_cs(spi0_cs),	
		.spi_sck(spi0_sck),
		.spi_io_i(spi_io_i[7:0]),
		.spi_io_o(spi_io_o[7:0]),
		.spi_io_t(spi_io_t[3:0]),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.clk_2x(clk_2x),
		.clk_1x(clk_1x),
		.rst(rst)
	);

	// PHY Chip 1
	qspi_phy_2x_ecp5 #(
		.N_CS(1)
	) phy1_I (
		.spi_io(spi1_io),
		.spi_cs(spi1_cs),	
		.spi_sck(spi1_sck),
		.spi_io_i(spi_io_i[15:8]),
		.spi_io_o(spi_io_o[15:8]),
		.spi_io_t(spi_io_t[ 7:4]),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.clk_2x(clk_2x),
		.clk_1x(clk_1x),
		.rst(rst)
	);

	// Tester
	qpimem_test qpi_test_I (
		.qpi_do_read(qpi_do_read),
		.qpi_do_write(qpi_do_write),
		.qpi_addr(qpi_addr),
		.qpi_is_idle(qpi_is_idle),
		.qpi_wdata(qpi_wdata),
		.qpi_rdata(qpi_rdata),
		.qpi_next_word(qpi_next_word),
		.bus_addr(bus_addr[6:0]),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata[1]),
		.bus_cyc(bus_cyc[1]),
		.bus_ack(bus_ack[1]),
		.bus_we(bus_we),
		.clk(clk_1x),
		.rst(rst)
	);

	// Generate signals
	task wb_write;
		input s;
		input [ 3:0] addr;
		input [31:0] data;
		begin
			bus_addr   <= addr;
			bus_wdata  <= data;
			bus_cyc[s] <= 1'b1;
			bus_we     <= 1'b1;

			@(posedge clk_1x);	

			while (~bus_ack[s])
				@(posedge clk_1x);	

			bus_addr   <= 4'h0;
			bus_wdata  <= 32'h00000000;
			bus_cyc[s] <= 1'b0;
			bus_we     <= 1'b0;
		end
	endtask

	initial
	begin : cfg
		// Init
		bus_addr  <= 4'h0;
		bus_wdata <= 32'h00000000;
		bus_cyc   <= 1'b0;
		bus_we    <= 1'b0;

		// Wait for reset release
		@(negedge rst)
		#300 @(posedge clk_1x)		

		// Write
		wb_write(0, 4'h0, 32'h00000002);
		wb_write(0, 4'h9, 32'h00009F9F);
		wb_write(0, 4'h9, 32'h00000000);
		wb_write(0, 4'hb, 32'h00000000);
		wb_write(0, 4'hb, 32'h00000000);
		wb_write(0, 4'hb, 32'h00000000);
		wb_write(0, 4'hb, 32'h00000000);
		wb_write(0, 4'h0, 32'h00000004);

		wb_write(1, 4'h0, 32'h9e000000);
	end

endmodule // qpimem_iface_2x2w_tb
