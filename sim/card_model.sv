// PlayStation controller + memory card model, from the SS1 Controller Tester (GPL-3.0, f3bandit).
// Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core (see COPYING).
`timescale 1ns/1ns
module card_model
(
	input        sel_n,
	input        sclk,
	input        cmd,
	output reg   dat,
	output reg   ack_n
);
	reg  [7:0] mem[0:131071];
	integer    present = 1;
	integer    flaky_sector = -1;   // returns a bad checksum this many times
	integer    flaky_count = 0;
	integer    dead_sector = -1;    // always bad
	integer    ack_delay = 150;     // ns after the byte
	integer    late_ack = 0;        // ns: a Sony card ACKs the 7th byte of a sector command ~1.7 ms late

	integer    idx;
	reg  [7:0] in_sh, out_sh, nxt;
	integer    bitn;
	reg  [9:0] addr;
	reg  [7:0] chk;
	reg        active;
	reg        wmode;
	reg        pmode;               // a controller is being read
	integer    pad_present = 1;
	reg [15:0] pad_raw = 16'hFFFF;    // active low
	reg [31:0] pad_ana = 32'h80808080;
	reg        pad_analog = 1;      // sends 73 (analog); 0: 41 (digital) until switched
	reg        pad_cfg = 0;         // in config mode (sends F3)
	reg  [7:0] pad_cmd;
	integer    pad_len;
	integer    pad_switches = 0;    // times it was put into analog mode
	integer    refuse = 0;          // ignores the analog command (a receiver with no controller yet)
	reg  [7:0] wbuf[0:127];
	reg  [7:0] wchk;
	integer    writes = 0;
	integer    bad_write_sector = -1;   // refuses the first write
	integer    bad_write_count = 0;

	initial begin dat = 1; ack_n = 1; active = 0; wmode = 0; end

	always @(negedge sel_n) begin idx = 0; bitn = 0; active = present | pad_present; out_sh = 8'hFF; wmode = 0; pmode = 0; end
	always @(posedge sel_n) begin active = 0; dat = 1; end

	// card drives DAT while CLK is low, the console samples on the rising edge
	always @(negedge sclk) if (!sel_n && active) dat = out_sh[bitn];

	always @(posedge sclk) if (!sel_n && active) begin
		in_sh = {cmd, in_sh[7:1]};
		bitn  = bitn + 1;
		if (bitn == 8) begin
			bitn = 0;
			respond();
		end
	end

	function [7:0] reply(input integer i);
		integer d;
		begin
			if (pmode) begin
				case (i)
					0: reply = pad_cfg ? 8'hF3 : pad_analog ? 8'h73 : 8'h41;
					1: reply = 8'h5A;
					2: reply = pad_raw[7:0];
					3: reply = pad_raw[15:8];
					default: reply = pad_ana[(i - 4) * 8 +: 8];
				endcase
			end
			else if (wmode && i >= 3) begin
				if (i == 134) reply = 8'h5C;
				else if (i == 135) reply = 8'h5D;
				else if (i == 136) reply = (wchk == 0) ? 8'h47 : 8'h4E;
				else reply = 8'h00;
			end
			else case (i)
				0: reply = 8'h08;       // FLAG, answered during byte 1
				1: reply = 8'h5A;
				2: reply = 8'h5D;
				3: reply = 8'h00;
				4: reply = addr[9:8];
				5: reply = 8'h5C;
				6: reply = 8'h5D;
				7: reply = addr[9:8];
				8: reply = addr[7:0];
				default: begin
					if (i >= 9 && i < 137) reply = mem[{addr, 7'd0} + i - 9];
					else if (i == 137) reply = chk;
					else reply = 8'h47;
				end
			endcase
		end
	endfunction

	task respond;
		integer i;
		begin
			// in_sh is the byte just received (index idx); out byte for idx+1 is prepared now
			if (idx == 0 && in_sh == 8'h01 && pad_present) pmode = 1;
			else if (idx == 0 && (in_sh != 8'h81 || !present)) begin active = 0; disable respond; end
			if (idx == 0 && pmode) pad_len = (!pad_cfg && !pad_analog) ? 5 : 9;
			if (idx == 1 && pmode) pad_cmd = in_sh;
			if (idx == 3 && pmode && pad_cmd == 8'h43) pad_cfg = in_sh[0];
			if (idx == 3 && pmode && pad_cmd == 8'h44 && pad_cfg && !refuse) begin pad_analog = in_sh[0]; pad_switches = pad_switches + 1; end
			if (idx == 1 && !pmode) begin
				if (in_sh == 8'h52) wmode = 0;
				else if (in_sh == 8'h57) wmode = 1;
				else begin active = 0; disable respond; end
			end
			if (wmode && idx == 4) addr[9:8] = in_sh[1:0];
			if (wmode && idx == 5) begin addr[7:0] = in_sh; wchk = addr[9:8] ^ addr[7:0]; end
			if (wmode && idx >= 6 && idx < 134) begin wbuf[idx-6] = in_sh; wchk = wchk ^ in_sh; end
			if (wmode && idx == 134) begin
				wchk = wchk ^ in_sh;   // 0 when the checksum was right
				if (addr == bad_write_sector && bad_write_count > 0) begin bad_write_count = bad_write_count - 1; end
				else if (wchk == 0) begin for (i = 0; i < 128; i = i + 1) mem[{addr, 7'd0} + i] = wbuf[i]; writes = writes + 1; end
			end
			if (!wmode && idx == 4) addr[9:8] = in_sh[1:0];
			if (!wmode && idx == 5) begin
				addr[7:0] = in_sh;
				chk = addr[9:8] ^ addr[7:0];
				for (i = 0; i < 128; i = i + 1) chk = chk ^ mem[{addr, 7'd0} + i];
				if (addr == flaky_sector && flaky_count > 0) begin chk = ~chk; flaky_count = flaky_count - 1; end
				if (addr == dead_sector) chk = ~chk;
			end
			out_sh = reply(idx);
			idx = idx + 1;
			if (idx < (pmode ? pad_len : wmode ? 138 : 140)) begin
				if (!pmode && idx == 7 && late_ack) #(late_ack) ack_n = 0;
				else #(ack_delay) ack_n = 0;
				#200 ack_n = 1;
			end
		end
	endtask
endmodule

