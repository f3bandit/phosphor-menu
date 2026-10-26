// Testbench for phosphor_ext: Main's side of EXT_BUS (spi_w), and in the front ports a modelled
// controller with a memory card (port 1) and a digital controller with no card (port 2).
// Run: sh sim/run.sh
// Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core (see COPYING).
`timescale 1ns/1ns

module tb;
	reg clk = 0;
	always #5 clk = ~clk;   // 100 MHz, like the menu core

	reg reset = 1;

	reg        io_strobe = 0, io_enable = 0;
	reg [15:0] io_din = 0;
	wire [15:0] io_dout;
	wire        show_static;
	wire       dout_en, ports_on;
	wire       sel1_n, sel2_n, sclk, scmd;
	wire       dat1, ack1, dat2, ack2;

	phosphor_ext #(.GAP(40000)) dut
	(
		.clk(clk), .reset(reset),
		.io_strobe(io_strobe), .io_enable(io_enable), .io_din(io_din), .io_dout(io_dout), .dout_en(dout_en),
		.ports_on(ports_on), .show_static(show_static),
		.sio_sel1_n(sel1_n), .sio_sel2_n(sel2_n), .sio_clk(sclk), .sio_cmd(scmd),
		.sio_dat(dat1 & dat2), .sio_ack(ack1 & ack2)
	);

	card_model p1(.sel_n(sel1_n), .sclk(sclk), .cmd(scmd), .dat(dat1), .ack_n(ack1));
	card_model p2(.sel_n(sel2_n), .sclk(sclk), .cmd(scmd), .dat(dat2), .ack_n(ack2));

	// Main: spi_w(w) puts w on the bus, strobes, waits for the ack and then reads the bus: it gets the
	// core's answer to that same word (the command word returns the first reply word)
	reg [15:0] bus;   // what the HPS reads: the extension's answer when it has the command
	reg [15:0] r;
	task automatic w(input [15:0] v, output [15:0] got);
		begin
			@(negedge clk) io_din = v; io_strobe = 1;
			@(negedge clk) io_strobe = 0;
			repeat (20) @(negedge clk);
			got = dout_en ? io_dout : 16'h0000;   // stock hps_io answers 0 to these commands
		end
	endtask
	task automatic begin_cmd(input [15:0] c);
		begin
			@(negedge clk) io_enable = 1;
			repeat (4) @(negedge clk);
			w(c, r);
		end
	endtask
	task automatic end_cmd;
		begin
			@(negedge clk) io_enable = 0;
			repeat (4) @(negedge clk);
		end
	endtask

	integer errors = 0;
	task check(input [255:0] what, input [31:0] got, input [31:0] want);
		begin
			if (got !== want) begin $display("FAIL %0s: got %h want %h", what, got, want); errors = errors + 1; end
			else $display("ok   %0s", what);
		end
	endtask

	reg [15:0] id, ver, md, st;
	reg [15:0] pw[0:8];
	reg [15:0] data[0:63];
	integer i, n;

	initial begin
		// port 1: analog controller and a card; port 2: digital controller, no card
		p1.present = 1; p1.pad_present = 1; p1.pad_analog = 1;
		p1.pad_raw = 16'hBFEF; p1.pad_ana = 32'h11223344;
		for (i = 0; i < 131072; i = i + 1) p1.mem[i] = i[7:0] ^ (i >> 7);
		p2.present = 0; p2.pad_present = 1; p2.pad_analog = 0; p2.pad_raw = 16'hFFFE;

		repeat (10) @(negedge clk);
		reset = 0;
		repeat (10) @(negedge clk);

		// the port pins are those of the stock core until Main turns them on
		check("off: selects released", {sel1_n, sel2_n}, 2'b11);

		begin_cmd(16'h80); id = r; w(0, ver); w(0, md); end_cmd;
		check("PH_ID", id, 16'h5048);
		check("version", ver, 16'd1);
		check("mode off", md, 16'd0);

		// a command it doesn't own: no answer from the extension
		begin_cmd(16'h29); w(0, r); end_cmd;
		check("other command left to hps_io", r, 16'h0000);

		check("black behind the menu at power-up", show_static, 0);
		begin_cmd(16'h86); w(16'h0001, r); end_cmd;
		check("PH_LOOK: static on", show_static, 1);
		begin_cmd(16'h86); w(16'h0000, r); end_cmd;
		check("PH_LOOK: static off", show_static, 0);
		begin_cmd(16'h81); check("PH_MODE answers", r, 16'h5048); w(16'h0001, r); end_cmd;
		check("PH_MODE: the old mode", r, 16'h0000);
		check("ports on", ports_on, 1);

		// both ports are read in turn
		#(4_000_000);
		begin_cmd(16'h82);
		pw[0] = r;
		for (i = 1; i < 9; i = i + 1) w(0, pw[i]);
		end_cmd;
		check("pads: mode", pw[0], 16'd1);
		check("pad 1 answered, analog", pw[1], 16'h0173);
		check("pad 1 buttons", pw[2], 16'hBFEF);
		check("pad 1 RX RY", pw[3], 16'h3344);
		check("pad 1 LX LY", pw[4], 16'h1122);
		check("pad 2 answered, digital", pw[5], 16'h0141);
		check("pad 2 buttons", pw[6], 16'hFFFE);

		// read sector 5 of the card in port 1
		begin_cmd(16'h83); w(16'h0000, r); w(16'd5, r); end_cmd;
		begin_cmd(16'h84); st = r; end_cmd;
		check("card read: busy", st[15], 1);
		n = 0;
		do begin #(500_000); begin_cmd(16'h84); st = r; end_cmd; n = n + 1; end while (st[15] && n < 100);
		check("card read: done, OK", st, 16'h4000);
		begin_cmd(16'h84); st = r; for (i = 0; i < 64; i = i + 1) w(0, data[i]); end_cmd;
		n = 0;
		for (i = 0; i < 64; i = i + 1)
			if (data[i] !== {p1.mem[5*128 + 2*i + 1], p1.mem[5*128 + 2*i]}) n = n + 1;
		check("card read: data", n, 0);

		// a Sony card: the 7th byte's ACK comes ~1.7 ms late; the read still works
		p1.late_ack = 1_700_000;
		begin_cmd(16'h83); w(16'h0000, r); w(16'd9, r); end_cmd;
		n = 0;
		do begin #(500_000); begin_cmd(16'h84); st = r; end_cmd; n = n + 1; end while (st[15] && n < 100);
		check("late-ACK card read: done, OK", st, 16'h4000);
		begin_cmd(16'h84); st = r; for (i = 0; i < 64; i = i + 1) w(0, data[i]); end_cmd;
		n = 0;
		for (i = 0; i < 64; i = i + 1)
			if (data[i] !== {p1.mem[9*128 + 2*i + 1], p1.mem[9*128 + 2*i]}) n = n + 1;
		check("late-ACK card read: data", n, 0);
		p1.late_ack = 0;

		// write sector 7, read it back from the model
		begin_cmd(16'h83); w(16'h0001, r); w(16'd7, r);
		for (i = 0; i < 64; i = i + 1) w(16'hA500 + i * 3, r);
		end_cmd;
		n = 0;
		do begin #(500_000); begin_cmd(16'h84); st = r; end_cmd; n = n + 1; end while (st[15] && n < 100);
		check("card write: done, OK", st, 16'h4000);
		n = 0;
		for (i = 0; i < 64; i = i + 1)
			if ({p1.mem[7*128 + 2*i + 1], p1.mem[7*128 + 2*i]} !== 16'hA500 + i * 3) n = n + 1;
		check("card write: data on the card", n, 0);
		check("card write: one write", p1.writes, 1);

		// no card in port 2
		begin_cmd(16'h83); w(16'h0100, r); w(16'd0, r); end_cmd;
		n = 0;
		do begin #(500_000); begin_cmd(16'h84); st = r; end_cmd; n = n + 1; end while (st[15] && n < 100);
		check("port 2: no card", st, 16'h4001);

		// a sector past the end
		begin_cmd(16'h83); w(16'h0000, r); w(16'd1023, r); end_cmd;
		n = 0;
		do begin #(500_000); begin_cmd(16'h84); st = r; end_cmd; n = n + 1; end while (st[15] && n < 100);
		check("sector 1023 reads", st[1:0], 0);

		// switch the digital controller in port 2 to analog: 1, 2, 3
		p2.pad_analog = 0;
		for (i = 1; i <= 3; i = i + 1) begin
			begin_cmd(16'h85); w(16'h0100 | i, r); end_cmd;
			#(1_000_000);
		end
		check("port 2 switched", p2.pad_switches, 1);
		#(4_000_000);
		begin_cmd(16'h82); pw[0] = r; for (i = 1; i < 9; i = i + 1) w(0, pw[i]); end_cmd;
		check("pad 2 now analog", pw[5], 16'h0173);

		// controller unplugged
		p1.pad_present = 0; p1.present = 0;
		#(4_000_000);
		begin_cmd(16'h82); pw[0] = r; for (i = 1; i < 9; i = i + 1) w(0, pw[i]); end_cmd;
		check("pad 1 gone", pw[1][8], 0);

		// off again: pins back to the stock core
		begin_cmd(16'h81); w(16'h0000, r); end_cmd;
		repeat (10) @(negedge clk);
		check("ports off", ports_on, 0);
		check("off: selects released again", {sel1_n, sel2_n}, 2'b11);

		if (errors) $display("%0d FAILED", errors); else $display("ALL PASSED");
		$finish;
	end

	initial begin #(200_000_000); $display("TIMEOUT"); $finish; end
endmodule
