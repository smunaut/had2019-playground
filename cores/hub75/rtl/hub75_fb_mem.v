/*
 * hub75_fb_mem.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

`default_nettype none

module hub75_fb_mem #(
)(
	input  wire [13:0] wr_addr,
	input  wire [15:0] wr_data,
	input  wire [ 3:0] wr_mask,
	input  wire wr_ena,

	input  wire [13:0] rd_addr,
	output reg  [15:0] rd_data,
	input  wire rd_ena,

	input  wire clk
);
	integer i;
	reg [15:0] ram [(1<<14)-1:0];

	always @(posedge clk)
	begin
		// Read
		if (rd_ena)
			rd_data <= ram[rd_addr];

		// Write
		if (wr_ena) begin
			if (wr_mask[3]) ram[wr_addr][15:12] <= wr_data[15:12];
			if (wr_mask[2]) ram[wr_addr][11: 8] <= wr_data[11: 8];
			if (wr_mask[1]) ram[wr_addr][ 7: 4] <= wr_data[ 7: 4];
			if (wr_mask[0]) ram[wr_addr][ 3: 0] <= wr_data[ 3: 0];
		end
	end

endmodule // hub75_fb_mem
