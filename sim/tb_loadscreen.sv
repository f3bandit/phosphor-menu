// The loading screen: a full frame (sim/ls_full.ppm), then the scanner's band of lines over 40 frames
// (sim/ls_anim.ppm, the frames one under another). Run from the repo root:
// iverilog -g2012 -o sim/tb_loadscreen.vvp sim/tb_loadscreen.sv rtl/loadscreen.sv && vvp -n sim/tb_loadscreen.vvp
`timescale 1ns/1ps
module tb_loadscreen;
	reg clk = 0;
	reg [9:0] hc = 0, vc = 5;
	reg pal = 0, dbl = 0;
	wire [23:0] rgb;
	loadscreen ls(.clk(clk), .hc(hc), .vc(vc), .pal(pal), .dbl(dbl), .rgb(rgb));
	integer f, ln, px, fr;
	task tick; begin #1 clk = 1; #1 clk = 0; end endtask
	task pixel(input integer x, input integer y); begin hc = x; vc = y; repeat (3) tick; $fwrite(f, "%0d %0d %0d\n", rgb[23:16], rgb[15:8], rgb[7:0]); end endtask
	task new_frame; begin vc = 1; tick; vc = 0; tick; tick; vc = 1; tick; end endtask
	initial begin
		f = $fopen("sim/ls_full.ppm", "w");
		$fwrite(f, "P3 640 240 255\n");
		for (ln = 0; ln < 240; ln = ln + 1) for (px = 0; px < 640; px = px + 1) pixel(px, ln);
		$fclose(f);
		f = $fopen("sim/ls_anim.ppm", "w");
		$fwrite(f, "P3 640 %0d 255\n", 40 * 12);
		for (fr = 0; fr < 40; fr = fr + 1) begin
			for (ln = 113; ln < 125; ln = ln + 1) for (px = 0; px < 640; px = px + 1) pixel(px, ln);
			repeat (4) new_frame;               // the scanner moves every 4 frames
		end
		$fclose(f);
		$display("DONE");
		$finish;
	end
endmodule
