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
	output wire [8:0] led,

	// Buttons
	input  wire [7:0] btn,

	// LCD
	inout  wire [17:0] lcd_db,
	output wire lcd_rd,
	output wire lcd_wr,
	output wire lcd_rs,
	output wire lcd_rst,
	output wire lcd_cs,
	input  wire lcd_id,
	input  wire lcd_fmark,
	output wire lcd_blen,

	// Debug UART
	input  wire uart_rx,
	output wire uart_tx,

	// SPI Flash
	inout  wire flash_mosi,
	inout  wire flash_miso,
	inout  wire flash_wp,
	inout  wire flash_hold,
//	inout  wire flash_sck,
	inout  wire flash_cs,

	// SPI PSRAM
	inout  wire [3:0] psrama_sio,
	inout  wire psrama_nce,
	inout  wire psrama_sclk,

	inout  wire [3:0] psramb_sio,
	inout  wire psramb_nce,
	inout  wire psramb_sclk,

	// USB
	inout  wire usb_dp,
	inout  wire usb_dm,
	output wire usb_pu,
	input  wire usb_vdet,

	// Boot
	output wire programn,

	// Generic IO
	inout  wire [29:0] genio,

	// Clock
	input  wire clk
);

	// Config
	// ------

	localparam RAM_AW = 13;	/* 8k x 32 = 32 kbytes */

	localparam WB_N  =  5;
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

	// GPIO
	wire  [7:0] btn_io;
	wire  [7:0] btn_r;
	wire  [7:0] btn_val;

	reg   [8:0] led_out;
	reg   [7:0] boot_key;

	reg         gpio_ack;
	wire        gpio_rdata_rst;
	reg  [31:0] gpio_rdata;

	// USB EP Buffer
	wire [ 8:0] ep_tx_addr_0;
	wire [31:0] ep_tx_data_0;
	wire ep_tx_we_0;

	wire [ 8:0] ep_rx_addr_0;
	wire [31:0] ep_rx_data_1;
	wire ep_rx_re_0;

	// Deal with non standard IOs
	wire flash_sck;
	wire flash_cs;

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

	// Peripheral [0] : Misc
	soc_had_misc had_misc_I (
		.led(led),
		.btn(btn),
		.lcd_db(lcd_db),
		.lcd_rd(lcd_rd),
		.lcd_wr(lcd_wr),
		.lcd_rs(lcd_rs),
		.lcd_rst(lcd_rst),
		.lcd_cs(lcd_cs),
		.lcd_id(lcd_id),
		.lcd_fmark(lcd_fmark),
		.lcd_blen(lcd_blen),
		.programn(programn),
		.genio(genio),
		.bus_addr(wb_addr[3:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[0]),
		.bus_cyc(wb_cyc[0]),
		.bus_ack(wb_ack[0]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [1] : UART
	uart_wb #(
		.DIV_WIDTH(16),
		.DW(WB_DW)
	) uart_I (
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[1]),
		.bus_cyc(wb_cyc[1]),
		.bus_ack(wb_ack[1]),
		.bus_we(wb_we),
		.clk(clk_48m),
		.rst(rst)
	);

	// Peripheral [2] : USB Core control
	usb #(
		.TARGET("ECP5"),
		.EPDW(32)
	) usb_I (
		.pad_dp(usb_dp),
		.pad_dn(usb_dm),
		.pad_pu(usb_pu),
		.ep_tx_addr_0(ep_tx_addr_0),
		.ep_tx_data_0(ep_tx_data_0),
		.ep_tx_we_0(ep_tx_we_0),
		.ep_rx_addr_0(ep_rx_addr_0),
		.ep_rx_data_1(ep_rx_data_1),
		.ep_rx_re_0(ep_rx_re_0),
		.ep_clk(clk_48m),
		.bus_addr(wb_addr[11:0]),
		.bus_din(wb_wdata[15:0]),
		.bus_dout(wb_rdata[2][15:0]),
		.bus_cyc(wb_cyc[2]),
		.bus_we(wb_we),
		.bus_ack(wb_ack[2]),
		.clk(clk_48m),
		.rst(rst)
	);

	assign wb_rdata[2][31:16] = 16'h0000;

	// Peripheral [3] : USB Core buffers
	reg wb_ack_ep;

	always @(posedge clk_48m)
		wb_ack_ep <= wb_cyc[3] & ~wb_ack_ep;

	assign wb_ack[3] = wb_ack_ep;

	assign ep_tx_addr_0 = wb_addr[8:0];
	assign ep_tx_data_0 = wb_wdata;
	assign ep_tx_we_0   = wb_cyc[3] & ~wb_ack[3] & wb_we;

	assign ep_rx_addr_0 = wb_addr[8:0];
	assign ep_rx_re_0   = 1'b1;

	assign wb_rdata[3] = wb_cyc[3] ? ep_rx_data_1 : 32'h00000000;

	// Peripheral [4] : SPI core
	wire [3:0] spi_io_i_flash;
	wire [3:0] spi_io_i_psrama;
	wire [3:0] spi_io_i_psramb;
	reg  [3:0] spi_io_i;
	wire [3:0] spi_io_o;
	wire [3:0] spi_io_t;
	wire       spi_sck_o;
	wire [2:0] spi_cs_o;

	qspi_master_wb #(
		.N_CS(3)
	) spi_master_I (
		.spi_io_i(spi_io_i),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_io_t),
		.spi_sck_o(spi_sck_o),
		.spi_cs_o(spi_cs_o),
		.bus_addr(wb_addr[1:0]),
		.bus_wdata(wb_wdata),
		.bus_rdata(wb_rdata[4]),
		.bus_cyc(wb_cyc[4]),
		.bus_we(wb_we),
		.bus_ack(wb_ack[4]),
		.clk(clk_48m),
		.rst(rst)
	);

		// PHY to Flash
	qspi_phy_ecp5 #(
		.N_CS(1),
		.IS_SYS_CFG(1)
	) spi_phy_flash_I (
		.spi_io({flash_hold, flash_wp, flash_miso, flash_mosi}),
		.spi_cs(flash_cs),
		.spi_sck(),		// Special via USRMCLK
		.spi_io_i(spi_io_i_flash),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_cs_o[0] ? 4'hf : spi_io_t),
		.spi_sck_o(spi_cs_o[0] ? 1'b0 : spi_sck_o),
		.spi_cs_o(spi_cs_o[0]),
		.clk(clk_48m),
		.rst(rst)
	);

		// PHY to PSRAM A
	qspi_phy_ecp5 #(
		.N_CS(1),
		.IS_SYS_CFG(0)
	) spi_phy_psrama_I (
		.spi_io(psrama_sio),
		.spi_cs(psrama_nce),
		.spi_sck(psrama_sclk),
		.spi_io_i(spi_io_i_psrama),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_cs_o[1] ? 4'hf : spi_io_t),
		.spi_sck_o(spi_cs_o[1] ? 1'b0 : spi_sck_o),
		.spi_cs_o(spi_cs_o[1]),
		.clk(clk_48m),
		.rst(rst)
	);

		// PHY to PSRAM B
	qspi_phy_ecp5 #(
		.N_CS(1),
		.IS_SYS_CFG(0)
	) spi_phy_psramb_I (
		.spi_io(psramb_sio),
		.spi_cs(psramb_nce),
		.spi_sck(psramb_sclk),
		.spi_io_i(spi_io_i_psramb),
		.spi_io_o(spi_io_o),
		.spi_io_t(spi_cs_o[2] ? 4'hf : spi_io_t),
		.spi_sck_o(spi_cs_o[2] ? 1'b0 : spi_sck_o),
		.spi_cs_o(spi_cs_o[2]),
		.clk(clk_48m),
		.rst(rst)
	);

		// MUX for read data
	always @(*)
	begin
		spi_io_i <= 4'h0;

		if (~spi_cs_o[0])
			spi_io_i <= spi_io_i_flash;
		else if (~spi_cs_o[1])
			spi_io_i <= spi_io_i_psrama;
		else if (~spi_cs_o[2])
			spi_io_i <= spi_io_i_psramb;
	end


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

endmodule // top
