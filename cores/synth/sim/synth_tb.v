/*
 * synth_tb.v
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

module synth_tb;

	// Signals
	reg rst = 1;
	reg clk = 1;

	reg [31:0] cb_data;
	reg [ 3:0] cb_voice;
	reg [ 2:0] cb_reg;
	reg cb_stb_v;
	reg cb_stb_g;


	// Setup recording
	initial begin
		$dumpfile("synth_tb.vcd");
		$dumpvars(0,synth_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 20000000 $finish;
	end

	// Clocks
	always #5 clk = !clk;

	// DUT
	synth_core #(
		.DIV_WIDTH(10)
	) dut_I (
		.cb_data(cb_data),
		.cb_voice(cb_voice),
		.cb_reg(cb_reg),
		.cb_stb_v(cb_stb_v),
		.cb_stb_g(cb_stb_g),
		.clk(clk),
		.rst(rst)
	);

	// Reg
	task cfg_global_write;
		input [ 2:0] addr;
		input [31:0] data;
		begin
			cb_data  <= data;
			cb_reg   <= addr;
			cb_voice <= 4'hx;
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b1;

			@(posedge clk);

			cb_data  <= 32'h00000000;
			cb_voice <= 4'h0;
			cb_reg   <= 3'h0;
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b0;
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b0;

			@(posedge clk);
		end
	endtask

	task cfg_voice_write;
		input [ 3:0] voice;
		input [ 2:0] addr;
		input [31:0] data;
		begin
			cb_data  <= data;
			cb_reg   <= addr;
			cb_voice <= voice;
			cb_stb_v <= 1'b1;
			cb_stb_g <= 1'b0;

			@(posedge clk);

			cb_data  <= 32'h00000000;
			cb_voice <= 4'h0;
			cb_reg   <= 3'h0;
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b0;
			cb_stb_v <= 1'b0;
			cb_stb_g <= 1'b0;

			@(posedge clk);
		end
	endtask

	reg integer i, j;

	initial
	begin
		// Reset
		cb_data  <= 32'h00000000;
		cb_voice <= 4'h0;
		cb_reg   <= 3'h0;
		cb_stb_v <= 1'b0;
		cb_stb_g <= 1'b0;

		@(negedge rst);
		@(posedge clk);

		for (i=0; i<16; i++)
			for (j=0; j<8; j++)
				cfg_voice_write(i, j, 32'h00000000);

		cfg_voice_write(0, 0, 32'h00000005);
		cfg_voice_write(0, 2, 32'h00008000);
		cfg_voice_write(0, 3, 32'h00001000);
		cfg_voice_write(0, 4, 32'h0000f0f0);
		cfg_voice_write(0, 5, 32'h00000040);
		cfg_voice_write(0, 6, 32'h00001040);
		cfg_voice_write(0, 7, 32'h00001040);

		cfg_global_write(0, 32'h0000001e);
		cfg_global_write(3, 32'h00000001);

	end

endmodule // synth_tb
