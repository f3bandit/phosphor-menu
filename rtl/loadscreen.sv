// Phosphor loading screen: the menu core's background (in place of MiSTer's static), in the style
// of a memory card loading screen. The PHOSPHOR wordmark, a row of 16 blocks with a scanner sweeping
// left to right through them (a lit block with a fading trail; it runs off the right end and starts
// again from the left), and NOW LOADING, on black. Laid out on a 640 x 240 picture shown at 16:9;
// PAL's 288 lines and the scandoubler's doubled lines map onto the same 240.
//
// Runs at CLK_VIDEO (100 MHz), so no division: what is at each column and on each line comes from two
// small tables (loadscreen_x.hex, loadscreen_y.hex, made by loadscreen_rom.py). Three clocks from
// position to colour. The scanner moves one block every 4 frames.
// Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core.

module loadscreen
(
	input             clk,
	input       [9:0] hc,      // 0-639 visible
	input       [9:0] vc,      // line (doubled when dbl)
	input             pal,
	input             dbl,
	output reg [23:0] rgb
);

// ---- the font: just the letters used (8 x 8, top row first, bit 7 on the left)
localparam C_SP = 4'd0, C_P = 4'd1, C_H = 4'd2, C_O = 4'd3, C_S = 4'd4, C_R = 4'd5, C_N = 4'd6, C_W = 4'd7,
           C_L = 4'd8, C_A = 4'd9, C_D = 4'd10, C_I = 4'd11, C_G = 4'd12;

function [7:0] glyph(input [3:0] ch, input [2:0] row);
	reg [63:0] g;
	begin
		case (ch)
			C_P: g = 64'hFC_C6_C6_FC_C0_C0_C0_00;
			C_H: g = 64'hC6_C6_C6_FE_C6_C6_C6_00;
			C_O: g = 64'h7C_C6_C6_C6_C6_C6_7C_00;
			C_S: g = 64'h7E_C0_C0_7C_06_06_FC_00;
			C_R: g = 64'hFC_C6_C6_FC_D8_CC_C6_00;
			C_N: g = 64'hC6_E6_F6_DE_CE_C6_C6_00;
			C_W: g = 64'hC6_C6_C6_D6_FE_EE_C6_00;
			C_L: g = 64'hC0_C0_C0_C0_C0_C0_FE_00;
			C_A: g = 64'h38_6C_C6_C6_FE_C6_C6_00;
			C_D: g = 64'hF8_CC_C6_C6_C6_CC_F8_00;
			C_I: g = 64'h7E_18_18_18_18_18_7E_00;
			C_G: g = 64'h7C_C6_C0_CE_C6_C6_7E_00;
			default: g = 64'h0;
		endcase
		glyph = g[63 - row*8 -: 8];
	end
endfunction

function [3:0] word(input [2:0] i);         // P H O S P H O R
	case (i)
		3'd0: word = C_P; 3'd1: word = C_H; 3'd2: word = C_O; 3'd3: word = C_S;
		3'd4: word = C_P; 3'd5: word = C_H; 3'd6: word = C_O; default: word = C_R;
	endcase
endfunction

function [3:0] loading(input [3:0] i);      // NOW LOADING
	case (i)
		4'd0: loading = C_N; 4'd1: loading = C_O; 4'd2: loading = C_W; 4'd3: loading = C_SP;
		4'd4: loading = C_L; 4'd5: loading = C_O; 4'd6: loading = C_A; 4'd7: loading = C_D;
		4'd8: loading = C_I; 4'd9: loading = C_N; default: loading = C_G;
	endcase
endfunction

localparam [23:0] BG = 24'h0E0E10, AMBER = 24'hFFB347, DIM = 24'h8D8A85, OFF = 24'h282016,
                  TRAIL1 = 24'h9E7131, TRAIL2 = 24'h684C25, TRAIL3 = 24'h48361D;   // the glow behind the lit block

// ---- the tables (see loadscreen_rom.py for the bits)
reg [19:0] XR [0:639];
reg [11:0] YR [0:255];
initial begin
	$readmemh("rtl/loadscreen_x.hex", XR);
	$readmemh("rtl/loadscreen_y.hex", YR);
end

// ---- the scanner: a frame counter (a new frame when the line count goes back to 0)
reg  [9:0] vc_old;
reg  [1:0] fdiv = 2'd0;
reg  [4:0] pos = 5'd0;                                         // the lit block: 0-15, then 16-18 while the trail runs off
always @(posedge clk) begin
	vc_old <= vc;
	if (vc == 10'd0 && vc_old != 10'd0) begin
		fdiv <= fdiv + 1'd1;
		if (fdiv == 2'd3) pos <= (pos == 5'd18) ? 5'd0 : pos + 1'd1;
	end
end

// ---- stage 1: the line in the 640 x 240 layout (PAL: 288 lines x 213/256)
reg  [9:0] x1, y1;
wire [9:0] y0 = dbl ? {1'b0, vc[9:1]} : vc;
always @(posedge clk) begin
	x1 <= hc;
	y1 <= pal ? 10'((y0 * 18'd213) >> 8) : y0;
end

// ---- stage 2: the tables
reg [19:0] xr2;
reg [11:0] yr2;
always @(posedge clk) begin
	xr2 <= XR[x1 < 10'd640 ? x1 : 10'd0];
	yr2 <= YR[y1 < 10'd256 ? y1[7:0] : 8'd0];
end

// ---- stage 3: the colour
wire [7:0] wrow = glyph(word(xr2[3:1]), yr2[3:1]);
wire [7:0] trow = glyph(loading(xr2[16:13]), yr2[8:6]);
wire [4:0] k    = pos - {1'b0, xr2[11:8]};               // how far behind the lit block this block is
always @(posedge clk) begin
	if (xr2[0] && yr2[0])          rgb <= wrow[3'd7 - xr2[6:4]] ? AMBER : BG;
	else if (xr2[7] && yr2[4])     rgb <= k == 5'd0 ? AMBER : k == 5'd1 ? TRAIL1 : k == 5'd2 ? TRAIL2 : k == 5'd3 ? TRAIL3 : OFF;
	else if (xr2[12] && yr2[5])    rgb <= trow[3'd7 - xr2[19:17]] ? DIM : BG;
	else                           rgb <= BG;
end

endmodule
