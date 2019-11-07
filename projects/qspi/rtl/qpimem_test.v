/*
 * qpimem_test.v
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

module qpimem_test (
	// QPI memory interface
    output wire qpi_do_read,
    output wire qpi_do_write,
    output wire [23:0] qpi_addr,
    input  wire qpi_is_idle,

    output wire [31:0] qpi_wdata,
    input  wire [31:0] qpi_rdata,
    input  wire qpi_next_word,

	// Wishbone interface
	input  wire [ 6:0] bus_addr,
	input  wire [31:0] bus_wdata,
	output wire [31:0] bus_rdata,
	input  wire bus_cyc,
	output wire bus_ack,
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

	wire [31:0] bus_rdata_csr;
	wire [31:0] bus_rdata_ram;

	wire we_csr;
	wire we_ram;

	// QPI Control
	reg  [6:0] ctl_len;
	reg  [5:0] ctl_buf_addr;
	reg [23:0] ctl_ext_addr;
	wire ctl_wren;
	wire ctl_rden;
	wire ctl_move;


	// Control FSM
	// -----------

	localparam
		ST_IDLE = 0,
		ST_WRITE = 4,
		ST_WRITE_LAST = 5,
		ST_READ = 6,
		ST_READ_LAST = 7;

	reg  [2:0] ctl_state;
	reg  [2:0] ctl_state_nxt;


	// Bus interface
	// -------------

	// Ack
	assign ack_nxt = bus_cyc & ~ack;

	always @(posedge clk)
		ack <= ack_nxt;

	assign bus_ack = ack;

	// CSR Read
	assign bus_rdata_csr = { ctl_state[2:1], ctl_buf_addr, ctl_ext_addr };

	// Read Mux
	assign bus_rdata = bus_cyc ? (bus_addr[6] ? bus_rdata_ram : bus_rdata_csr) : 32'h00000000;

	// Write Enables
	assign we_csr = ack & bus_we & ~bus_addr[6];
	assign we_ram = ack & bus_we &  bus_addr[6];


	// Local buffer RAM
	// ----------------

	// Instance
`ifdef XX
	ram_tdp #(
		.AWIDTH(6),
		.DWIDTH(32)
	) ram_I (
		.p0_addr(bus_addr[5:0]),
		.p0_wr_data(bus_wdata),
		.p0_rd_data(bus_rdata_ram),
		.p0_wr_ena(we_ram),
		.p0_rd_ena(1'b1),
		.p1_addr(ctl_buf_addr),
		.p1_wr_data(qpi_rdata),
		.p1_wr_ena(ctl_wren),
		.p1_rd_data(qpi_wdata),
		.p1_rd_ena(ctl_rden),
		.clk(clk)
	);
`else
	ram_sdp #(
		.AWIDTH(6),
		.DWIDTH(32)
	) ram0_I (
		.rd_addr(bus_addr[5:0]),
		.rd_data(bus_rdata_ram),
		.rd_ena(1'b1),
		.wr_addr(ctl_buf_addr),
		.wr_data(qpi_rdata),
		.wr_ena(ctl_wren),
		.clk(clk)
	);

	ram_sdp #(
		.AWIDTH(6),
		.DWIDTH(32)
	) ram1_I (
		.wr_addr(bus_addr[5:0]),
		.wr_data(bus_wdata),
		.wr_ena(we_ram),
		.rd_addr(ctl_buf_addr),
		.rd_data(qpi_wdata),
		.rd_ena(ctl_rden),
		.clk(clk)
	);
`endif



	// QPI Mem interface
	// -----------------

	// State
	always @(posedge clk)
		if (rst)
			ctl_state <= ST_IDLE;
		else
			ctl_state <= ctl_state_nxt;

	// Next-State logic
	always @(*)
	begin
		// Default is to stay put
		ctl_state_nxt <= ctl_state;

		// Transition ?
		case (ctl_state)
			ST_IDLE:
				if (we_csr)
					ctl_state_nxt <= bus_wdata[31] ? ST_READ : ST_WRITE;

			ST_WRITE:
				if (ctl_len[6] & qpi_next_word)
					ctl_state_nxt <= ST_WRITE_LAST;

			ST_WRITE_LAST:
				if (qpi_next_word)
					ctl_state_nxt <= ST_IDLE;

			ST_READ:
				if (ctl_len[6] & qpi_next_word)
					ctl_state_nxt <= ST_READ_LAST;

			ST_READ_LAST:
				if (qpi_next_word)
					ctl_state_nxt <= ST_IDLE;
		endcase
	end

	// RAM control
	assign ctl_wren = ((ctl_state == ST_READ) || (ctl_state == ST_READ_LAST)) & qpi_next_word;
	assign ctl_rden = ((ctl_state == ST_WRITE) & qpi_next_word) | we_csr;

	// QPI control
    assign qpi_do_read  = (ctl_state == ST_READ);
    assign qpi_do_write = (ctl_state == ST_WRITE);

	// Internal address
	assign ctl_move = qpi_next_word | (we_csr & ~bus_wdata[31]);

	always @(posedge clk)
		if ((ctl_state == ST_IDLE) & ~we_csr)
			ctl_buf_addr <= 6'h00;
		else if (ctl_move)
			ctl_buf_addr <= ctl_buf_addr + 1;

	// External address
	always @(posedge clk)
		if (we_csr)
			ctl_ext_addr <= bus_wdata[23:0];

	assign qpi_addr = ctl_ext_addr;

	// Length
	always @(posedge clk)
		if (we_csr)
			ctl_len <= { 1'b0, bus_wdata[29:24] } - 1;
		else if (qpi_next_word)
			ctl_len <= ctl_len - 1;

endmodule // qpimem_iface
