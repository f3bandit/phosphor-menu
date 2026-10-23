// Renders the test card to PPM files: NTSC 240 lines, scandoubled 480, PAL 288 (run from the repo root:
// iverilog -g2012 -o sim/tb_testcard.vvp sim/tb_testcard.sv rtl/testcard.sv && vvp -n sim/tb_testcard.vvp).
`timescale 1ns/1ps
module tb_testcard;
	reg clk = 0;
	reg [9:0] hc, vc;
	reg pal, dbl;
	wire [23:0] rgb;
	testcard tc(.clk(clk), .hc(hc), .vc(vc), .pal(pal), .dbl(dbl), .rgb(rgb));
	integer f, lines, ln, px;
	task frame(input [127:0] name, input p, input d, input integer n);
		begin
			pal = p; dbl = d;
			f = $fopen(name, "w");
			$fwrite(f, "P3 640 %0d 255\n", n);
			for (ln = 0; ln < n; ln = ln + 1)
				for (px = 0; px < 640; px = px + 1) begin
					hc = px; vc = ln;
					repeat (4) begin #1 clk = 1; #1 clk = 0; end   // four stages
					$fwrite(f, "%0d %0d %0d\n", rgb[23:16], rgb[15:8], rgb[7:0]);
				end
			$fclose(f);
		end
	endtask
	initial begin
		frame("sim/tc_ntsc.ppm", 0, 0, 240);
		frame("sim/tc_dbl.ppm",  0, 1, 480);
		frame("sim/tc_pal.ppm",  1, 0, 288);
		$display("DONE");
		$finish;
	end
endmodule
