/*
 * soc_oc_r02_misc.v
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

module soc_oc_r02_misc (
	// LEDs
	output wire [2:0] led,

	// Button
	input  wire btn,

	// Reboot command
	output wire programn,

	// Wishbone interface
	input  wire  [3:0] bus_addr,
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

	genvar i;

	// Bus interface
	wire ack_nxt;
	reg  ack;

	reg  we_ctrl;
	reg  we_led_pwm;

	wire rd_rst;

	// Buttons
	reg  [15:0] btn_sample_cnt;
	wire        btn_io;
	wire        btn_r;
	wire        btn_val;

	// LEDs (including LCD backlight)
	reg   [2:0] led_ena;
	reg   [8:0] led_pwm;
	reg   [2:0] led_out;

	// Boot
	reg   [7:0] boot_key;


	// Bus interface
	// -------------

	// Ack
	assign ack_nxt = ~ack & bus_cyc;

	always @(posedge clk)
		ack <= ack_nxt;

	assign bus_ack = ack;

	// Write enable
	always @(posedge clk)
	begin
		we_ctrl     <= ack_nxt & bus_we & (bus_addr[1:0] == 2'b00);
		we_led_pwm  <= ack_nxt & bus_we & (bus_addr[1:0] == 2'b01);
	end

	// Write
	always @(posedge clk)
		if (rst) begin
			boot_key  <=  8'h00;
			led_ena   <= 10'h000;
			led_pwm   <= 30'h3fffffff;
		end else begin
			if (we_ctrl) begin
				boot_key  <= bus_wdata[31:24];
				led_ena   <= bus_wdata[2:0];
			end

			if (we_led_pwm) begin
				led_pwm <= bus_wdata[8:0];
			end
		end

	// Read
	assign rd_rst = ~bus_cyc | bus_we | ack;

	always @(posedge clk)
		if (rd_rst)
			bus_rdata <= 32'h00000000;
		else
			bus_rdata <= bus_addr[0] ?
				{ 23'd0, led_pwm } :
				{ boot_key, 7'd0, btn_val, 13'd0, led_ena };


	// Buttons
	// -------

	// IO register
	TRELLIS_IO #(
		.DIR("INPUT")
	) btn_io_I (
		.B(btn),
		.I(1'b0),
		.T(1'b0),
		.O(btn_io)
	);

	IFS1P3BX btn_ireg (
		.PD(1'b0),
		.D(btn_io),
		.SP(1'b1),
		.SCLK(clk),
		.Q(btn_r)
	);

	// Glitch filter on all buttons
	always @(posedge clk)
		if (rst)
			btn_sample_cnt <= 0;
		else
			btn_sample_cnt <= btn_sample_cnt[15] ? 16'd0 : (btn_sample_cnt + 1);

	glitch_filter #(
		.L(3),
		.WITH_CE(1)
	) btn_flt_I (
		.pin_iob_reg(btn_r),
		.cond(1'b1),
		.ce(btn_sample_cnt[15]),
		.val(btn_val),
		.rise(),
		.fall(),
		.clk(clk),
		.rst(rst),
	);


	// LEDs
	// ----
		// Each LED has an enable / disable and a 3 bit brightness

	reg [5:0] pwm_cnt;
	reg [2:0] pwm_map;

	// PWM counter
	always @(posedge clk)
		pwm_cnt <= pwm_cnt + 1;

	// Map PWM counter to threshold value
	always @(posedge clk)
	begin
		if (pwm_cnt >= 6'h00) pwm_map <= 3'd0;
		if (pwm_cnt >= 6'h01) pwm_map <= 3'd1;
		if (pwm_cnt >= 6'h05) pwm_map <= 3'd2;
		if (pwm_cnt >= 6'h0c) pwm_map <= 3'd3;
		if (pwm_cnt >= 6'h15) pwm_map <= 3'd4;
		if (pwm_cnt >= 6'h20) pwm_map <= 3'd5;
		if (pwm_cnt >= 6'h2e) pwm_map <= 3'd6;
		if (pwm_cnt >= 6'h3f) pwm_map <= 3'd7;
	end

	for (i=0; i<3; i++)
		always @(posedge clk)
			led_out[i] <= led_ena[i] & (led_pwm[3*i+:3] >= pwm_map);

	// Led output
	assign led = led_out[2:0];


	// Reboot key
	// ----------

	assign programn = (boot_key == 8'ha5) ? 1'b0 : 1'b1;

endmodule // soc_oc_r02_misc
