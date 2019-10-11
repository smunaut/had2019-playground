/*
 * qspi_master_wb.v
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

module qspi_master_wb #(
	parameter integer N_CS = 1,
)(
	// SPI PHY interface
	input  wire [3:0] spi_io_i,
	output reg  [3:0] spi_io_o,
	output reg  [3:0] spi_io_t,

	output wire spi_sck_o,
	output wire [N_CS-1:0] spi_cs_o,

	// Wishbone interface
	input  wire [ 1:0] bus_addr,
	input  wire [31:0] bus_wdata,
	output reg  [31:0] bus_rdata,
	input  wire bus_cyc,
	input  wire bus_ack,
	input  wire bus_we,

	// Clock
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Bus interface
	wire ack_nxt;
	reg  ack;

	wire rd_rst;

	wire [31:0] rd_csr;

	// Bit-Bang state
	reg  [N_CS-1:0] bb_cs;
	reg        bb_clk;
	reg  [3:0] bb_io_t;
	reg  [3:0] bb_io_o;
	wire [3:0] bb_io_i;

	// FIFOs
	wire [9:0] txf_di;
	reg  txf_wren;
	wire txf_full;
	wire [9:0] txf_do;
	wire txf_rden;
	wire txf_empty;

	wire [7:0] rxf_di;
	reg  rxf_wren;
	wire rxf_full;
	wire [7:0] rxf_do;
	wire rxf_rden;
	wire rxf_empty;

	wire rxf_wren_i;
	reg  rxf_overflow_clr;
	reg  rxf_overflow;

	// Shift Registers
	wire shift_out_ld_mode;
	wire [7:0] shift_out_ld_data;

	wire shift_out_shift_mode;
	wire [7:0] shift_out_shift_data;

	wire shift_out_ld;
	reg  [7:0] shift_out;
	wire shift_out_ce;

	reg  shift_in_mode;
	reg  [7:0] shift_in;
	reg  shift_in_ce;

	reg  shift_in_last;

	// Commands
	reg cmd_valid;
	reg [1:0] cmd_cur;
	reg [4:0] cmd_cnt;



	// [0] - Control / Status
	//
	//	[31] RX FIFO Empty
	//  [30] RX FIFO Full
	//  [29] RX FIFO Overflow
	//  [27] TX FIFO Empty
	//  [26] TX FIFO Full
	//  [23:16] Chip-Select
	//  [   12] Bit-Bang CLK force
	//  [11: 8] Bit-Bang IO tristate
	//	[ 7: 4] Bit-Bang IO output
	//  [ 3: 0] Bit-Bang IO input
	//
	//
	// [1] - Data
	//       Rd: [7:0] Data from read
	//       Wr: [7:0] Data to write
	//           [9:8] 00 - WO 1 bit
	//                 01 - RW 1 bit
	//                 10 - Write 4 bit
	//                 11 - Read  4 bit


	// Bus interface
	// -------------

	// Ack
	assign ack_nxt = bus_cyc & ~ack & ~(bus_we & bus_addr[0] & txf_full);

	always @(posedge clk)
		ack <= ack_nxt;

	assign bus_ack = ack;

	// CSR
	always @(posedge clk)
		if (rst) begin
			bb_cs   <= { N_CS{1'b1} };
			bb_clk  <= 1'b0;
			bb_io_t <= 4'hf;
			bb_io_o <= 4'h0;
		end else if (ack & bus_we & ~bus_addr[0]) begin
			bb_cs   <= bus_wdata[16+N_CS-1:16];
			bb_clk  <= bus_wdata[12];
			bb_io_t <= bus_wdata[11:8];
			bb_io_o <= bus_wdata[7:4];
		end

	always @(posedge clk)
		rxf_overflow_clr <= bus_cyc & bus_we & ~ack & ~bus_addr[0] & bus_wdata[29];

	assign rd_csr = {
		rxf_empty, rxf_full, rxf_overflow, 1'b0,
		txf_empty, txf_full, 2'b00,
		{ (8-N_CS){1'b0} }, bb_cs,
		bb_clk, 3'b000,
		bb_io_t, bb_io_o, bb_io_i
	};

	// TX FIFO write
	assign txf_di   = bus_wdata[9:0];

	always @(posedge clk)
		txf_wren <= bus_cyc & bus_we & ~ack & bus_addr[0] & ~txf_full;

	// TX FIFO read
	assign rxf_rden = ack & bus_addr[0] & ~bus_we & ~bus_rdata[31];

	// Read mux
	assign rd_rst = ~bus_cyc | ack;

	always @(posedge clk)
		if (rd_rst)
			bus_rdata <= 32'h00000000;
		else
			bus_rdata <= bus_addr[0] ?
				{ rxf_empty, 23'b0, rxf_do } :
				rd_csr;


	// FIFOs
	// -----

	// TX
	fifo_sync_ram #(
		.DEPTH(16),
		.WIDTH(10)
	) tx_fifo_I (
		.wr_data(txf_di),
		.wr_ena(txf_wren),
		.wr_full(txf_full),
		.rd_data(txf_do),
		.rd_ena(txf_rden),
		.rd_empty(txf_empty),
		.clk(clk),
		.rst(rst)
	);

	// RX
	fifo_sync_ram #(
		.DEPTH(16),
		.WIDTH(8)
	) rx_fifo_I (
		.wr_data(rxf_di),
		.wr_ena(rxf_wren_i),
		.wr_full(rxf_full),
		.rd_data(rxf_do),
		.rd_ena(rxf_rden),
		.rd_empty(rxf_empty),
		.clk(clk),
		.rst(rst)
	);

	// RX Overflow tracking
	assign rxf_wren_i = rxf_wren & ~rxf_full;

	always @(posedge clk)
		rxf_overflow <= (rxf_overflow & ~rxf_overflow_clr) | (rxf_wren & rxf_full);


	// Shift registers
	// ---------------

	// Output
	assign shift_out_ld_data = shift_out_ld_mode ?
		{ txf_do[4], txf_do[5], txf_do[6], txf_do[7], txf_do[0], txf_do[1], txf_do[2], txf_do[3] } :
		txf_do[7:0];

	assign shift_out_shift_data = shift_out_shift_mode ?
		{ shift_out[3:0], 4'h0 } :
		{ shift_out[6:0], 1'b0 };

	always @(posedge clk)
		if (shift_out_ce)
			shift_out <= shift_out_ld ? shift_out_ld_data : shift_out_shift_data;

	// Input
	always @(posedge clk)
		if (shift_in_ce)
			shift_in <= shift_in_mode ?
				{ shift_in[3:0], spi_io_i[3:0] } :
				{ shift_in[6:0], spi_io_i[1] };

	assign rxf_di = shift_in;


	// Control
	// -------

	// Commands
	always @(posedge clk)
		if (rst) begin
			cmd_valid <= 1'b0;
			cmd_cur   <= 2'bxx;
			cmd_cnt   <= 5'bxxxxx;
		end else begin
			if (~cmd_valid | cmd_cnt[4]) begin
				cmd_valid <= ~txf_empty;
				cmd_cur   <= txf_do[9:8];
				cmd_cnt   <= txf_do[9] ? 5'd2 : 5'd14;
			end else begin
				cmd_cnt   <= cmd_cnt - 1;
			end
		end

	assign txf_rden = ~txf_empty & (~cmd_valid | cmd_cnt[4]);

	// CS is Bit-Banged
	assign spi_cs_o = bb_cs;

	// Clock can be forced high
	assign spi_sck_o = bb_clk | (cmd_valid & cmd_cnt[0]);

	// Shift Out control
	assign shift_out_ld_mode = txf_do[9];
	assign shift_out_shift_mode = cmd_cur[1];
	assign shift_out_ld = txf_rden;
	assign shift_out_ce = cmd_valid ? cmd_cnt[0] : ~txf_empty;

	// IO control
	always @(*)
	begin
		if (~cmd_valid) begin
			// No active command, pins under bit-bang control
			spi_io_o <= bb_io_o;
			spi_io_t <= bb_io_t;
		end else if (cmd_cur[1]) begin
			// Quad mode
			spi_io_o <= { shift_out[4], shift_out[5], shift_out[6], shift_out[7] };
			spi_io_t <= { 4{cmd_cur[0]} };
		end else begin
			// Single mode
			spi_io_o <= { bb_io_o[3:2], 1'b0, shift_out[7] };
			spi_io_t <= { bb_io_t[3:2], 2'b10 };
		end
	end

	assign bb_io_i = spi_io_i;

	// Capture control
	always @(posedge clk)
		if (rst) begin
			shift_in_ce   <= 1'b0;
			shift_in_mode <= 1'b0;
			shift_in_last <= 1'b0;
			rxf_wren      <= 1'b0;
		end else begin
			shift_in_ce   <= cmd_valid & cmd_cnt[0];
			shift_in_mode <= cmd_cur[1];
			shift_in_last <= cmd_valid & cmd_cnt[4] & cmd_cur[0];	// Only for 'reads'
			rxf_wren      <= shift_in_last;
		end

endmodule // qspi_master_wb
