// Phosphor extension for the MiSTer menu core (phosphor-menu, a fork of MiSTer-devel/Menu_MiSTer).
// Copyright (C) 2026 f3bandit
//
// This program is free software: you can redistribute it and/or modify it under the terms of
// the GNU General Public License as published by the Free Software Foundation, either version 3
// of the License, or (at your option) any later version.
//
// Lets Main (phosphor-main) read PlayStation controllers and memory cards on the SuperStation
// One's front ports (SNAC) while the menu core is loaded. The ports stay off until Main turns
// them on: until then the user port works as in the stock menu core (MT32-pi, MIDI).
//
// Commands on hps_io's EXT_BUS (16-bit words; the first word is the command). Main reads the bus
// after each word's strobe, so each word returns the answer set at its own strobe: the command word
// returns the first reply word below, the k-th word after it the next (as with hps_io's own commands):
//   80 PH_ID           reply: 5048 ('PH'), version, mode
//   81 PH_MODE         write: mode (bit 0: front ports on).                  reply: 5048, old mode
//   82 PH_PADS         reply: mode, then per port (1, 2) four words:
//                        {7'0, answered, ID}, buttons (as sent: active low), {RY, RX}, {LY, LX}
//   83 PH_CARD         write: {7'0, port 2, 6'0, op (0 read, 1 write)}, sector (0..1023),
//                        then for a write 64 data words (byte 2n low, byte 2n+1 high)
//                        the operation starts after the sector (read) or the last data word (write)
//   84 PH_CARD_STATUS  reply: {busy, done, 12'0, result}, then 64 data words (after a read)
//                        result: 0 OK, 1 no card, 2 bad reply / refused, 3 sector out of range
//   86 PH_LOOK         write: bit 0 = show MiSTer's moving static behind the menu (default off: black, so the
//                        SS1 stays black from power-on until Phosphor is on screen; Main turns it on while
//                        MiSTer's own menu has the screen)
//   85 PH_PAD_CMD      write: {7'0, port 2, 6'0, pcmd}: 1 config mode, 2 analog on, 3 leave config
//                        (1, 2, 3 in turn switch a DualShock to analog)
// While a card operation or controller command is waiting or on the bus the controllers aren't
// read; Main waits for done (PH_CARD_STATUS) before the next one.

module phosphor_ext
#(
	parameter HALF    = 199,     // clk cycles per half bit: 250 kHz at 100 MHz
	parameter ACK_TO  = 20000,   // 200 us (controllers)
	parameter CARD_ACK_TO = 300000,  // 3 ms (memory cards: Sony cards ACK some bytes ~1.7 ms late)
	parameter SEL_DLY = 2000,    // 20 us
	parameter GAP     = 400000   // 4 ms between controller reads (each port every 8 ms)
)
(
	input             clk,
	input             reset,

	// hps_io EXT_BUS
	input             io_strobe,
	input             io_enable,
	input      [15:0] io_din,
	output reg [15:0] io_dout,
	output reg        dout_en,    // EXT_BUS[32]: this module answers the command

	output            ports_on,   // the user port belongs to the front ports
	output reg        show_static,       // PH_LOOK bit 0 (0 at power-up)

	output            sio_sel1_n,
	output            sio_sel2_n,
	output            sio_clk,
	output            sio_cmd,
	input             sio_dat,    // raw from the port
	input             sio_ack
);

localparam VERSION = 16'd1;
localparam PH_ID = 8'h80, PH_MODE = 8'h81, PH_PADS = 8'h82, PH_CARD = 8'h83, PH_CARD_STATUS = 8'h84, PH_PAD_CMD = 8'h85, PH_LOOK = 8'h86;
localparam R_OK = 2'd0;

reg [15:0] mode;
initial show_static = 0;
assign ports_on = mode[0];

///////////////////////////// the bus /////////////////////////////

reg  [2:0] dat_s = 3'b111;
reg  [5:0] ack_s = 6'b111111;
reg        ack_f = 1;
always @(posedge clk) begin
	dat_s <= {dat_s[1:0], sio_dat};
	ack_s <= {ack_s[4:0], sio_ack};
	// ACK is a pulse of a few microseconds: ignore glitches
	if (ack_s[5:1] == 5'b00000) ack_f <= 0;
	else if (ack_s[5:1] == 5'b11111) ack_f <= 1;
end

reg        cs_start, cs_pad, cs_port;
reg  [1:0] cs_pcmd, cs_mode;
reg  [9:0] cs_sector;
wire       cs_done, cs_busy, cs_sel_n;
wire [1:0] cs_result;
wire [7:0] cs_pid;
wire [15:0] cs_pbtn;
wire [31:0] cs_pana;
wire [16:0] cs_addr;
wire [7:0] cs_wdata;
wire       cs_we;
reg  [7:0] cs_rdata;

card_sector card_sector
(
	.clk(clk), .reset(reset | ~ports_on),
	.half_period(16'(HALF)), .ack_timeout(20'(ACK_TO)), .card_ack_timeout(20'(CARD_ACK_TO)), .sel_delay(16'(SEL_DLY)),
	.start(cs_start), .pad(cs_pad), .pcmd(cs_pcmd), .sector(cs_sector), .mode(cs_mode),
	.busy(cs_busy), .done(cs_done), .result(cs_result), .mismatch(),
	.hdr0(), .hdr1(), .pad_id(cs_pid), .pad_btn(cs_pbtn), .pad_ana(cs_pana),
	.mem_addr(cs_addr), .mem_wdata(cs_wdata), .mem_we(cs_we), .mem_rdata(cs_rdata),
	.sio_sel_n(cs_sel_n), .sio_clk(sio_clk), .sio_cmd(sio_cmd), .sio_dat(dat_s[2]), .sio_ack(ack_f)
);

assign sio_sel1_n = (ports_on && !cs_port) ? cs_sel_n : 1'b1;
assign sio_sel2_n = (ports_on &&  cs_port) ? cs_sel_n : 1'b1;

///////////////////////////// the sector buffer /////////////////////////////
// 128 bytes as 64 words: the card side works in bytes, Main in words

reg  [7:0] buf_lo[0:63];
reg  [7:0] buf_hi[0:63];
reg        h_we;
reg  [5:0] h_addr;
reg [15:0] h_data;
reg  [5:0] h_rd;
reg [15:0] h_q;

always @(posedge clk) begin
	if (cs_we) begin
		if (cs_addr[0]) buf_hi[cs_addr[6:1]] <= cs_wdata;
		else            buf_lo[cs_addr[6:1]] <= cs_wdata;
	end
	else if (h_we) begin
		buf_lo[h_addr] <= h_data[7:0];
		buf_hi[h_addr] <= h_data[15:8];
	end
	cs_rdata <= cs_addr[0] ? buf_hi[cs_addr[6:1]] : buf_lo[cs_addr[6:1]];
	h_q      <= {buf_hi[h_rd], buf_lo[h_rd]};
end

///////////////////////////// controllers, card operations /////////////////////////////

reg  [7:0] p_id[2];
reg  [1:0] p_ok;
reg [15:0] p_btn[2];
reg [31:0] p_ana[2];

reg        card_req, card_port, card_wr;
reg  [9:0] card_sec;
reg        card_busy, card_done;
reg  [1:0] card_res;
reg        pcmd_req, pcmd_port;
reg  [1:0] pcmd_cmd;

reg  [1:0] st;           // 0 idle, 1 controller read, 2 card operation, 3 controller command
reg [22:0] tmr;
reg        pp;           // the port read next

// from the command side
reg        set_card, set_pcmd;

always @(posedge clk) begin
	cs_start <= 0;

	if (set_card) begin
		card_req  <= 1;
		card_busy <= 1;
		card_done <= 0;
	end
	if (set_pcmd) pcmd_req <= 1;

	if (reset || !ports_on) begin
		st        <= 0;
		tmr       <= 0;
		p_ok      <= 0;
		card_req  <= 0;
		card_busy <= 0;
		pcmd_req  <= 0;
		cs_port   <= 0;
		pp        <= 0;
	end
	else case (st)
		0: begin
			if (tmr) tmr <= tmr - 1'd1;
			if (card_req) begin
				card_req  <= 0;
				cs_port   <= card_port;
				cs_pad    <= 0;
				cs_pcmd   <= 0;
				cs_mode   <= card_wr ? 2'd3 : 2'd0;
				cs_sector <= card_sec;
				cs_start  <= 1;
				st        <= 2;
			end
			else if (pcmd_req) begin
				pcmd_req  <= 0;
				cs_port   <= pcmd_port;
				cs_pad    <= 1;
				cs_pcmd   <= pcmd_cmd;
				cs_start  <= 1;
				st        <= 3;
			end
			else if (!tmr) begin
				cs_port   <= pp;
				cs_pad    <= 1;
				cs_pcmd   <= 0;
				cs_start  <= 1;
				st        <= 1;
			end
		end

		1: if (cs_done) begin
			p_ok[cs_port] <= (cs_result == R_OK);
			if (cs_result == R_OK) begin
				p_id[cs_port]  <= cs_pid;
				p_btn[cs_port] <= cs_pbtn;
				p_ana[cs_port] <= cs_pana;
			end
			pp  <= ~pp;
			tmr <= 23'(GAP);
			st  <= 0;
		end

		2: if (cs_done) begin
			card_res  <= cs_result;
			card_busy <= 0;
			card_done <= 1;
			tmr       <= 23'(SEL_DLY);  // a short gap before the next select
			st        <= 0;
		end

		3: if (cs_done) begin
			tmr <= 23'(SEL_DLY);
			st  <= 0;
		end
	endcase
end

///////////////////////////// hps_io commands /////////////////////////////

function [15:0] pads_word(input [3:0] n);   // PH_PADS reply word n (1..9)
	reg q;
	begin
		q = (n >= 6);
		case (n)
			1:       pads_word = mode;
			2, 6:    pads_word = {7'd0, p_ok[q], p_id[q]};
			3, 7:    pads_word = p_btn[q];
			4, 8:    pads_word = p_ana[q][15:0];
			5, 9:    pads_word = p_ana[q][31:16];
			default: pads_word = 16'd0;
		endcase
	end
endfunction

reg  [7:0] cmd;
reg  [6:0] wcnt;     // words after the command

always @(posedge clk) begin
	h_we     <= 0;
	set_card <= 0;
	set_pcmd <= 0;

	if (reset) mode <= 0;

	if (~io_enable) begin
		dout_en <= 0;
		cmd     <= 0;
		wcnt    <= 0;
	end
	else if (io_strobe) begin
		if (~&wcnt) wcnt <= wcnt + 1'd1;
		io_dout <= 0;
		if (!dout_en && wcnt == 0) begin
			// the command word
			cmd     <= io_din[7:0];
			dout_en <= (io_din[15:8] == 0 && io_din[7:0] >= PH_ID && io_din[7:0] <= PH_LOOK);
			case (io_din)
				PH_ID, PH_MODE:  io_dout <= 16'h5048;
				PH_PADS:         io_dout <= pads_word(1);
				PH_CARD_STATUS:  io_dout <= {card_busy, card_done, 12'd0, card_res};
				default: ;
			endcase
			h_rd <= 0;
		end
		else if (dout_en) case (cmd)
			PH_ID:   if (wcnt == 1) io_dout <= VERSION; else if (wcnt == 2) io_dout <= mode;
			PH_MODE: if (wcnt == 1) begin io_dout <= mode; mode <= io_din; end
			PH_PADS: io_dout <= pads_word(4'(wcnt + 1'd1));
			PH_CARD: if (!card_busy) begin
				if (wcnt == 1) begin card_port <= io_din[8]; card_wr <= io_din[0]; end
				if (wcnt == 2) begin
					card_sec <= io_din[9:0];
					if (!card_wr) set_card <= 1;
				end
				if (card_wr && wcnt >= 3 && wcnt <= 66) begin
					h_we   <= 1;
					h_addr <= 6'(wcnt - 7'd3);
					h_data <= io_din;
					if (wcnt == 66) set_card <= 1;
				end
			end
			PH_CARD_STATUS: if (wcnt <= 64) begin
				io_dout <= h_q;            // word wcnt - 1 of the buffer
				h_rd    <= 6'(wcnt);
			end
			PH_LOOK: if (wcnt == 1) show_static <= io_din[0];
			PH_PAD_CMD: if (wcnt == 1 && !pcmd_req) begin
				pcmd_port <= io_din[8];
				pcmd_cmd  <= io_din[1:0];
				set_pcmd  <= 1;
			end
			default: ;
		endcase
	end
end

endmodule
