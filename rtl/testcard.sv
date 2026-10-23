// Phosphor test card: the menu core's background (in place of MiSTer's static), drawn from the beam
// position: a grid, a centre circle with a colour strip, the PHOSPHOR ident, a grey scale and
// resolution wedges, and four corner circles. Laid out on a 640 x 240 picture shown at 16:9 (a line
// is 1.5 pixels tall there, so circles test (2*dx)^2 + (3*dy)^2); PAL's 288 lines and the
// scandoubler's doubled lines map onto the same 240.
//
// Runs at CLK_VIDEO (100 MHz), so no division: what depends only on the column or only on the line
// comes from two small tables (testcard_x.hex, testcard_y.hex, made by testcard_rom.py), and the
// circles are pipelined. Four clocks from position to colour (one pixel at most).
// Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core.

module testcard
(
	input             clk,
	input       [9:0] hc,      // 0-639 visible
	input       [9:0] vc,      // line (doubled when dbl)
	input             pal,
	input             dbl,
	output reg [23:0] rgb
);

// ---- the font: just the letters used (8 x 8, top row first, bit 7 on the left)
localparam C_SP = 4'd0, C_P = 4'd1, C_H = 4'd2, C_O = 4'd3, C_S = 4'd4, C_R = 4'd5, C_L = 4'd6, C_E = 4'd7,
           C_A = 4'd8, C_T = 4'd9, C_N = 4'd10, C_D = 4'd11, C_B = 4'd12, C_Y = 4'd13;

function [7:0] glyph(input [3:0] ch, input [2:0] row);
	reg [63:0] g;
	begin
		case (ch)
			C_P: g = 64'hFC_C6_C6_FC_C0_C0_C0_00;
			C_H: g = 64'hC6_C6_C6_FE_C6_C6_C6_00;
			C_O: g = 64'h7C_C6_C6_C6_C6_C6_7C_00;
			C_S: g = 64'h7E_C0_C0_7C_06_06_FC_00;
			C_R: g = 64'hFC_C6_C6_FC_D8_CC_C6_00;
			C_L: g = 64'hC0_C0_C0_C0_C0_C0_FE_00;
			C_E: g = 64'hFE_C0_C0_FC_C0_C0_FE_00;
			C_A: g = 64'h38_6C_C6_C6_FE_C6_C6_00;
			C_T: g = 64'hFE_38_38_38_38_38_38_00;
			C_N: g = 64'hC6_E6_F6_DE_CE_C6_C6_00;
			C_D: g = 64'hF8_CC_C6_C6_C6_CC_F8_00;
			C_B: g = 64'hFC_C6_C6_FC_C6_C6_FC_00;
			C_Y: g = 64'hC6_C6_6C_38_38_38_38_00;
			default: g = 64'h0;
		endcase
		glyph = g[63 - row*8 -: 8];
	end
endfunction

function [3:0] ident(input [2:0] i);        // P H O S P H O R
	case (i)
		3'd0: ident = C_P; 3'd1: ident = C_H; 3'd2: ident = C_O; 3'd3: ident = C_S;
		3'd4: ident = C_P; 3'd5: ident = C_H; 3'd6: ident = C_O; default: ident = C_R;
	endcase
endfunction

function [3:0] standby(input [3:0] i);      // PLEASE STAND BY
	case (i)
		4'd0: standby = C_P; 4'd1: standby = C_L; 4'd2: standby = C_E; 4'd3: standby = C_A; 4'd4: standby = C_S;
		4'd5: standby = C_E; 4'd6: standby = C_SP; 4'd7: standby = C_S; 4'd8: standby = C_T; 4'd9: standby = C_A;
		4'd10: standby = C_N; 4'd11: standby = C_D; 4'd12: standby = C_SP; 4'd13: standby = C_B; default: standby = C_Y;
	endcase
endfunction

function [7:0] grey(input [3:0] s);         // 10 steps, black to white
	case (s)
		4'd0: grey = 8'd0;   4'd1: grey = 8'd28;  4'd2: grey = 8'd56;  4'd3: grey = 8'd85;  4'd4: grey = 8'd113;
		4'd5: grey = 8'd141; 4'd6: grey = 8'd170; 4'd7: grey = 8'd198; 4'd8: grey = 8'd226; default: grey = 8'd255;
	endcase
endfunction

function [23:0] bar(input [2:0] i);         // 75% colour bars, then black
	case (i)
		3'd0: bar = 24'hBFBFBF; 3'd1: bar = 24'hBFBF00; 3'd2: bar = 24'h00BFBF; 3'd3: bar = 24'h00BF00;
		3'd4: bar = 24'hBF00BF; 3'd5: bar = 24'hBF0000; 3'd6: bar = 24'h0000BF; default: bar = 24'h000000;
	endcase
endfunction

localparam [23:0] BG = 24'h464648, GRID = 24'hBEBEBE, LINE = 24'hEBEBEB, DISC = 24'h0E0E10,
                  AMBER = 24'hFFB347, TEXT = 24'hC8C8C8;

// ---- the tables (see testcard_rom.py for the bits)
reg [31:0] XR [0:639];
reg [15:0] YR [0:255];
initial begin
	$readmemh("rtl/testcard_x.hex", XR);
	$readmemh("rtl/testcard_y.hex", YR);
end

// ---- stage 1: the line in the 640 x 240 layout (PAL: 288 lines x 213/256)
reg  [9:0] x1, y1;
wire [9:0] y0 = dbl ? {1'b0, vc[9:1]} : vc;
always @(posedge clk) begin
	x1 <= hc;
	y1 <= pal ? 10'((y0 * 18'd213) >> 8) : y0;
end

// ---- stage 2: the tables; the squares for the circles
reg [31:0] xr2;
reg [15:0] yr2;
reg [21:0] dx2, dy2, cx2, cy2;
reg        cvx2, chy2;
wire signed [11:0] dx  = $signed({2'b0, x1}) - 12'sd320;
wire signed [11:0] dy  = $signed({2'b0, y1}) - 12'sd120;
wire signed [11:0] cdx = $signed({2'b0, x1}) - (x1 < 10'd320 ? 12'sd55 : 12'sd585);
wire signed [11:0] cdy = $signed({2'b0, y1}) - (y1 < 10'd120 ? 12'sd37 : 12'sd203);
wire signed [13:0] ax = dx * 14'sd2, ay = dy * 14'sd3, acx = cdx * 14'sd2, acy = cdy * 14'sd3;
always @(posedge clk) begin
	xr2  <= XR[x1 < 10'd640 ? x1 : 10'd0];
	yr2  <= YR[y1[7:0]];
	dx2  <= 22'(ax * ax);
	dy2  <= 22'(ay * ay);
	cx2  <= 22'(acx * acx);
	cy2  <= 22'(acy * acy);
	cvx2 <= cdx == 0;
	chy2 <= cdy == 0;
end

// ---- stage 3: inside or on which circle; the letters
reg        in_disc, on_ring, in_corner, on_cring, cross3;
reg [31:0] xr3;
reg [15:0] yr3;
reg        ident_px, sb_px;
wire [21:0] dsq = dx2 + dy2, csq = cx2 + cy2;
wire  [7:0] irow = glyph(ident(xr2[8:6]), yr2[5:3]);
wire  [7:0] srow = glyph(standby(xr2[16:13]), yr2[9:7]);
always @(posedge clk) begin
	in_disc   <= dsq <= 22'd90000;                       // radius 150 px (100 lines)
	on_ring   <= dsq >= 22'd86436 && dsq <= 22'd90000;   // (294..300)^2
	in_corner <= csq <= 22'd3600;                        // radius 30 px (20 lines)
	on_cring  <= csq >= 22'd3136 && csq <= 22'd3600;
	cross3    <= cvx2 | chy2;
	xr3       <= xr2;
	yr3       <= yr2;
	ident_px  <= irow[3'd7 - xr2[11:9]];
	sb_px     <= srow[3'd7 - xr2[19:17]];
end

// ---- stage 4: the colour
wire in_bars  = xr3[4]  & yr3[1];
wire in_ident = xr3[5]  & yr3[2];
wire in_sb    = xr3[12] & yr3[6];
wire in_grey  = xr3[20] & yr3[10];
wire in_wedge = xr3[25] & yr3[11];
wire on_vline = xr3[27] & yr3[12];
wire [7:0] g  = grey(xr3[24:21]);
always @(posedge clk) begin
	if (on_ring)                           rgb <= LINE;
	else if (in_disc) begin
		if (in_bars)                       rgb <= bar(xr3[3:1]);
		else if (in_ident)                 rgb <= ident_px ? AMBER : DISC;
		else if (in_sb)                    rgb <= sb_px ? TEXT : DISC;
		else if (in_grey)                  rgb <= {g, g, g};
		else if (in_wedge)                 rgb <= xr3[26] ? LINE : DISC;
		else if (on_vline)                 rgb <= LINE;
		else                               rgb <= DISC;
	end
	else if (on_cring || (in_corner && cross3)) rgb <= LINE;
	else if (xr3[0] || yr3[0])             rgb <= GRID;
	else                                   rgb <= BG;
end

endmodule
