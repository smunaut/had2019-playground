/*
 * top.v
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

module top (
	// LEDs
//	output wire [8:0] led,

	// Buttons
//	input  wire [7:0] btn,

	// LCD
//	inout  wire [17:0] lcd_db,
//	output wire lcd_rd,
//	output wire lcd_wr,
//	output wire lcd_rs,
//	output wire lcd_rst,
//	output wire lcd_cs,
//	input  wire lcd_id,
//	input  wire lcd_fmark,
//	output wire lcd_blen,

	// Debug UART
	input  wire uart_rx,
	output wire uart_tx,

	// SPI Flash
//	inout  wire flash_mosi,
//	inout  wire flash_miso,
//	inout  wire flash_wp,
//	inout  wire flash_hold,
////	inout  wire flash_sck,
//	inout  wire flash_cs,

	// SPI PSRAM
	inout  wire [3:0] psrama_sio,
	inout  wire psrama_nce,
	inout  wire psrama_sclk,

	inout  wire [3:0] psramb_sio,
	inout  wire psramb_nce,
	inout  wire psramb_sclk,

	// USB
//	inout  wire usb_dp,
//	inout  wire usb_dm,
//	output wire usb_pu,
//	input  wire usb_vdet,

	// Boot
//	output wire programn,

	// Generic IO
//	inout  wire [29:0] genio,

	// Audio
	output wire audio_pdm,

	// Clock
	input  wire clk
);

	// Config
	// ------

	localparam RAM_AW = 13;	/* 8k x 32 = 32 kbytes */

	localparam WB_N  =  4;
	localparam WB_DW = 32;
	localparam WB_AW = 16;
	localparam WB_AI =  2;


	// Signals
	// -------

	// Memory bus
	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_rdata;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;

	// BRAM
	wire [RAM_AW-1:0] bram_addr;
	wire [31:0] bram_rdata;
	wire [31:0] bram_wdata;
	wire [ 3:0] bram_wmsk;
	wire        bram_we;

	// Wishbone
	wire [WB_AW-1:0] wb_addr;
	wire [WB_DW-1:0] wb_wdata;
	wire [(WB_DW/8)-1:0] wb_wmsk;
	wire [WB_DW-1:0] wb_rdata [0:WB_N-1];
	wire [(WB_DW*WB_N)-1:0] wb_rdata_flat;
	wire [WB_N-1:0] wb_cyc;
	wire wb_we;
	wire [WB_N-1:0] wb_ack;

	// Clocks / Reset
	wire clk_24m;
	wire clk_48m;
	wire clk_96m;
	wire rst;

	// Genvar
	genvar i;


	// SoC
	// ---

	// PicoRV32
	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),
		.STACKADDR(4 << RAM_AW),
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(1),
		.ENABLE_COUNTERS(0),
		.ENABLE_COUNTERS64(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (clk_48m),
		.resetn    (~rst),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);

	// Bridge
	soc_bridge #(
		.RAM_AW(RAM_AW),
		.WB_N(WB_N),
		.WB_DW(WB_DW),
		.WB_AW(WB_AW),
		.WB_AI(WB_AI)
	) pb_I (
		.pb_addr(mem_addr),
		.pb_rdata(mem_rdata),
		.pb_wdata(mem_wdata),
		.pb_wstrb(mem_wstrb),
		.pb_valid(mem_valid),
		.pb_ready(mem_ready),
		.bram_addr(bram_addr),
		.bram_rdata(bram_rdata),
		.bram_wdata(bram_wdata),
		.bram_wmsk(bram_wmsk),
		.bram_we(bram_we),
		.wb_addr(wb_addr),
		.wb_wdata(wb_wdata),
		.wb_wmsk(wb_wmsk),
		.wb_rdata(wb_rdata_flat),
		.wb_cyc(wb_cyc),
		.wb_we(wb_we),
		.wb_ack(wb_ack),
		.clk(clk_48m),
		.rst(rst)
	);

	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*WB_DW+:WB_DW] = wb_rdata[i];

	// RAM
	soc_bram #(
		.AW(RAM_AW),
		.INIT_FILE("boot.hex")
	) bram_I (
		.addr(bram_addr),
		.rdata(bram_rdata),
		.wdata(bram_wdata),
		.wmsk(bram_wmsk),
		.we(bram_we),
		.clk(clk_48m)
	);

	// Peripheral [0] : UART
	uart_wb #(
		.DIV_WIDTH(16),
		.DW(WB_DW)
	) uart_I (
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[0]),
		.bus_cyc(wb_cyc[0]),
		.bus_ack(wb_ack[0]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [1] : SPI core

	wire [15:0] spi_io_i;
	wire [15:0] spi_io_o;
	wire [ 7:0] spi_io_t;
	wire [1:0] spi_sck_o;
	wire spi_cs_o;

	wire qpi_do_read;
	wire qpi_do_write;
	wire [23:0] qpi_addr;
	wire qpi_is_idle;
	wire [31:0] qpi_wdata;
	wire [31:0] qpi_rdata;
	wire qpi_next_word;

	qpimem_iface_2x2w qpi_I (
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
		.bus_addr(wb_addr[3:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[1]),
		.bus_cyc(wb_cyc[1]),
		.bus_ack(wb_ack[1]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	qspi_phy_2x_ecp5 #(
		.N_CS(1)
	) spi_phy_psrama_I (
		.spi_io(psrama_sio),
		.spi_cs(psrama_nce),
		.spi_sck(psrama_sclk),
		.spi_io_i(spi_io_i[7:0]),
		.spi_io_o(spi_io_o[7:0]),
		.spi_io_t(spi_io_t[3:0]),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.clk_1x(clk_48m),
		.clk_2x(clk_96m),
		.rst(rst)
	);

	qspi_phy_2x_ecp5 #(
		.N_CS(1)
	) spi_phy_psramb_I (
		.spi_io(psramb_sio),
		.spi_cs(psramb_nce),
		.spi_sck(psramb_sclk),
		.spi_io_i(spi_io_i[15:8]),
		.spi_io_o(spi_io_o[15:8]),
		.spi_io_t(spi_io_t[7:4]),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.clk_1x(clk_48m),
		.clk_2x(clk_96m),
		.rst(rst)
	);

	// Peripheral [2] : QPI memory interface tester
	qpimem_test qpi_test_I (
		.qpi_do_read(qpi_do_read),
		.qpi_do_write(qpi_do_write),
		.qpi_addr(qpi_addr),
		.qpi_is_idle(qpi_is_idle),
		.qpi_wdata(qpi_wdata),
		.qpi_rdata(qpi_rdata),
		.qpi_next_word(qpi_next_word),
		.bus_addr(wb_addr[6:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[2]),
		.bus_cyc(wb_cyc[2]),
		.bus_ack(wb_ack[2]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [3] : Sound
	wire [15:0] audio_out_pdm;

	audio_wb synth_I (
		.audio_out_pdm(audio_out_pdm),
		.bus_addr(wb_addr[15:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[3]),
		.bus_cyc(wb_cyc[3]),
		.bus_ack(wb_ack[3]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	pdm #(
		.WIDTH(16),
		.DITHER("YES")
	) audio_pdm_I (
		.in(audio_out_pdm),
		.pdm(audio_pdm),
		.oe(1'b1),
		.clk(clk_48m),
		.rst(rst)
	);


	// Clock / Reset
	// -------------

	sysmgr sysmgr_I (
		.clk_in(clk),
		.rst_in(1'b0),
		.clk_24m(clk_24m),
		.clk_48m(clk_48m),
		.clk_96m(clk_96m),
		.rst_out(rst)
	);

//	assign led = 0;
//	assign programn = 1'b1;

endmodule // top
