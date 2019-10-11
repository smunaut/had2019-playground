/*
 * qspi_phy_ecp5.v
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

module qspi_phy_ecp5 #(
	parameter integer N_CS = 1,
	parameter integer IS_SYS_CFG = 0	// If set, then CS/CLK is sys_config port
)(
	// SPI Pads
	inout  wire [3:0] spi_io,
	inout  wire [N_CS-1:0] spi_cs,	
	inout  wire spi_sck,

	// SPI PHY interface
	output wire [3:0] spi_io_i,
	input  wire [3:0] spi_io_o,
	input  wire [3:0] spi_io_t,

	input  wire spi_sck_o,
	input  wire [N_CS-1:0] spi_cs_o,

	// Clock
	input  wire clk,
	input  wire rst
);
	wire [3:0] spi_io_ir;
	wire [3:0] spi_io_or;
	wire [3:0] spi_io_tr;

	wire [N_CS-1:0] spi_cs_or;

	// IOs
	OFS1P3DX phy_io_rego_I[3:0] (
		.CD(rst),
		.D(spi_io_o),
		.SP(1'b1),
		.SCLK(clk),
		.Q(spi_io_or)
	);

	OFS1P3BX phy_io_regt_I[3:0] (
		.PD(rst),
		.D(spi_io_t),
		.SP(1'b1),
		.SCLK(clk),
		.Q(spi_io_tr)
	);

	TRELLIS_IO #(
		.DIR("BIDIR")
	) phy_io_I[3:0] (
		.B(spi_io),
		.I(spi_io_or),
		.T(spi_io_tr),
		.O(spi_io_ir)
	);

	IFS1P3DX phy_io_regi_I[3:0] (
		.CD(rst),
		.D(spi_io_ir),
		.SP(1'b1),
		.SCLK(clk),
		.Q(spi_io_i)
	);

	// Chip Selects
	OFS1P3DX phy_cs_reg_I[N_CS-1:0] (
		.CD(rst),
		.D(spi_cs_o),
		.SP(1'b1),
		.SCLK(clk),
		.Q(spi_cs_or)
	);

	TRELLIS_IO #(
		.DIR("OUTPUT")
	) phy_cs_I[N_CS-1:0] (
		.B(spi_cs),
		.I(spi_cs_or),
		.T(1'b0),
		.O()
	);

	// Clock
	generate
		if (IS_SYS_CFG) begin
			reg spi_sck_or;

			always @(posedge clk)
				if (rst)
					spi_sck_or <= 1'b0;
				else
					spi_sck_or <= spi_sck_o;

			USRMCLK usrmclk_inst (
				.USRMCLKI(spi_sck_or),
				.USRMCLKTS(rst)
			) /* synthesis syn_noprune=1 */;
		end else begin
			wire spi_sck_or;

			OFS1P3DX phy_clk_reg_I (
				.CD(rst),
				.D(spi_sck_o),
				.SP(1'b1),
				.SCLK(clk),
				.Q(spi_sck_or)
			);

			TRELLIS_IO #(
				.DIR("OUTPUT")
			) phy_clk_I (
				.B(spi_sck),
				.I(spi_sck_or),
				.T(1'b0),
				.O()
			);
		end
	endgenerate

endmodule // qspi_phy_ecp5
