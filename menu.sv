//============================================================================
//
//  Menu for MiSTer.
//  Copyright (C) 2017-2020 Sorgelig
//
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign DDRAM_CLK = clk_sys;
assign CE_PIXEL  = ce_timing;

assign VGA_SL = 0;
// the interlace field (480i/576i: Phosphor's CRT modes; always 0 progressive)
wire native_field;
assign VGA_F1 = native_field;
assign VIDEO_ARX = 0;
assign VIDEO_ARY = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;

assign AUDIO_MIX = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign LED_DISK = 0;
assign LED_POWER[1]= 1;
assign BUTTONS = 0;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = FB ? led[0] : act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

wire [26:0] act_cnt2 = {~act_cnt[26],act_cnt[25:0]};
assign LED_POWER[0]= FB ? led[2] : act_cnt2[26] ? act_cnt2[25:18] > act_cnt2[7:0] : act_cnt2[25:18] <= act_cnt2[7:0];


`include "build_id.v" 
localparam CONF_STR = {
	"MENU;UART31250,MIDI;",
	"-  ;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire [31:0] status;
wire [35:0] EXT_BUS;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.forced_scandoubler(forced_scandoubler),
	.status(status),
	.status_menumask(cfg),
	.EXT_BUS(EXT_BUS)
);

/////////////////////   PHOSPHOR   ///////////////////
// The SuperStation One's front ports (PlayStation controllers and memory cards over SNAC) for
// phosphor-main. Off until Main turns them on; the user port then stops being MT32-pi / MIDI.

wire        ph_on, ph_sel1_n, ph_sel2_n, ph_clk, ph_cmd, ph_static;

phosphor_ext phosphor_ext
(
	.clk(clk_sys),
	.reset(RESET),
	.io_strobe(EXT_BUS[33]),
	.io_enable(EXT_BUS[34]),
	.io_din(EXT_BUS[31:16]),
	.io_dout(EXT_BUS[15:0]),
	.dout_en(EXT_BUS[32]),
	.ports_on(ph_on),
	.show_static(ph_static),
	.sio_sel1_n(ph_sel1_n),
	.sio_sel2_n(ph_sel2_n),
	.sio_clk(ph_clk),
	.sio_cmd(ph_cmd),
	.sio_dat(USER_IN[4]),
	.sio_ack(USER_IN[3])
);

////////////////////   CLOCKS   ///////////////////
wire locked, clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.locked(locked)
);


/////////////////////   SDRAM   ///////////////////
//
// Helper functionality:
//    SDRAM and DDR3 RAM are being cleared while this core is working.
//    some cores behave incorrectly if started with non-clean RAM.

sdram sdr
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(sdram_addr),
	.wtbt(3),
	.dout(sdram_dout),
	.din(sdram_din),
	.rd(sdram_rd),
	.we(sdram_we),
	.ready(sdram_ready)
);

reg  [26:0] sdram_addr;
wire        sdram_ready;
wire [15:0] sdram_dout;
reg  [15:0] sdram_din;
reg         sdram_we;
reg         sdram_rd;
reg  [15:0] cfg = 0;

always @(posedge clk_sys) begin
	reg [4:0] state = 0;

	sdram_rd <= 0;
	sdram_we <= 0;

	if(RESET) begin
		state <= 0;
		cfg <= 0;
	end
	else begin
		case(state)
			0: if(sdram_ready) begin
					cfg <= 0;
					state      <= state+1'd1;
				end
			1: begin
					sdram_addr <= 'h4000000;
					sdram_din  <= 3128;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			2: state <= state+1'd1;
			3: if(sdram_ready) begin
					sdram_addr <= 'h2000000;
					sdram_din  <= 2064;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			4: state <= state+1'd1;
			5: if(sdram_ready) begin
					sdram_addr <= 'h0000000;
					sdram_din  <= 1032;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			6: state <= state+1'd1;
			7: if(sdram_ready) begin
					sdram_addr <= 'h1000000;
					sdram_din  <= 12345;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			8: state <= state+1'd1;
			9: if(sdram_ready) begin
					sdram_addr <= 'h4000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			10: state <= state+1'd1;
			11: if(sdram_ready) begin
					cfg[2]     <= (sdram_dout == 3128);
					sdram_addr <= 'h2000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			12: state <= state+1'd1;
			13: if(sdram_ready) begin
					cfg[1]     <= (sdram_dout == 2064);
					sdram_addr <= 'h0000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			14: state <= state+1'd1;
			15: if(sdram_ready) begin
					cfg[0]     <= (sdram_dout == 1032);
					cfg[15]    <= 1;
					state      <= state+1'd1;
				end
			16: begin
					sdram_addr <= addr[24:0];
					sdram_din  <= 0;
					sdram_we   <= we;
				end
		endcase
	end
end

reg         fb_own = 0;
// Phosphor's CRT modes (status[9]): the native video reader owns DDRAM, nothing else touches it.
// Ownership is handed over, never switched mid-burst: the reader gets it (nv_own) once the
// framebuffer reader and the clear writer are idle, and gives it back once it has stopped (nv_idle)
wire        native_sys = status[9];
reg         nv_own = 0;
wire        nv_idle;
wire        ddr_pause = FB | fb_own | native_sys | nv_own;
wire [28:0] clr_addr, fb_addr;
wire  [7:0] clr_burst, clr_be, fb_burst;
wire        clr_rd, clr_we, fb_rd, fb_idle;

ddram ddr
(
	.*,
	.reset(RESET),
	.DDRAM_BURSTCNT(clr_burst),
	.DDRAM_ADDR(clr_addr),
	.DDRAM_RD(clr_rd),
	.DDRAM_BE(clr_be),
	.DDRAM_WE(clr_we),
	.we(we & ~ddr_pause),
   .dout(),
   .din(0),
   .rd(0),
   .ready()
);

reg        we;
reg [28:0] addr = 0;

always @(posedge clk_sys) begin
	reg [4:0] cnt = 9;

	if(~RESET & cfg[15] & ~ddr_pause) begin
		cnt <= cnt + 1'b1;
		we <= &cnt & (addr[28:22] != 7'h68);     // (never the native buffers: 0x3A000000, 4 MB)
		if(cnt == 8) addr <= addr + 1'd1;
	end
end

always @(posedge clk_sys) begin
	reg fb_req;

	fb_req <= FB & ~native_sys & ~nv_own;
	if(fb_req & ~clr_we) fb_own <= 1;
	else if(~fb_req & fb_idle) fb_own <= 0;

	if(native_sys & ~nv_own & ~fb_own & ~fb_req & ~clr_we) nv_own <= 1;
	else if(~native_sys & nv_own & nv_idle) nv_own <= 0;
end

wire [28:0] nv_addr;
wire  [7:0] nv_burst, nv_be;
wire        nv_rd, nv_we;
wire [63:0] nv_din;
assign DDRAM_ADDR     = nv_own ? nv_addr  : fb_own ? fb_addr  : clr_addr;
assign DDRAM_BURSTCNT = nv_own ? nv_burst : fb_own ? fb_burst : clr_burst;
assign DDRAM_RD       = nv_own ? nv_rd    : fb_own ? fb_rd    : clr_rd;
assign DDRAM_WE       = nv_own ? 1'b0     : fb_own ? 1'b0     : clr_we;
assign DDRAM_BE       = nv_own ? 8'hFF    : fb_own ? 8'hFF    : clr_be;

////////////////////////////  MT32pi  ////////////////////////////////// 

//
// Pin | USB Name | Signal
// ----+----------+--------------
// 0   | D+       | I/O I2C_SDA / RX (midi in)
// 1   | D-       | O   TX (midi out)
// 2   | TX-      | I   I2S_WS (1 == right)
// 3   | GND_d    | I   I2C_SCL
// 4   | RX+      | I   I2S_BCLK
// 5   | RX-      | I   I2S_DAT
// 6   | TX+      | -   none
//

reg [15:0] mt32_i2s_r, mt32_i2s_l;
wire midi_rx;

assign AUDIO_L = ph_on ? 16'd0 : mt32_i2s_l;
assign AUDIO_R = ph_on ? 16'd0 : mt32_i2s_r;
assign AUDIO_S = 1;

// front ports (Phosphor): [1] select port 1, [0] select port 2, [2] CMD, [5] CLK; DAT on [4], ACK on [3]
assign USER_OUT      = ph_on ? {1'b1, ph_clk, 2'b11, ph_cmd, ph_sel1_n, ph_sel2_n} : {5'b11111, UART_RXD, 1'b1};
assign UART_TXD      = ph_on ? 1'b1 : midi_rx;


//
// crossed/straight cable selection
//

generate
genvar i;
for(i = 0; i<2; i++) begin : clk_rate
	wire clk_in = i ? USER_IN[6] : USER_IN[4];
	reg [4:0] cnt;
	always @(posedge CLK_AUDIO) begin : clkr
		reg       clk_sr, clk, old_clk;
		reg [4:0] cnt_tmp;

		clk_sr <= clk_in;
		if (clk_sr == clk_in) clk <= clk_sr;

		if(~&cnt_tmp) cnt_tmp <= cnt_tmp + 1'd1;
		else cnt <= '1;

		old_clk <= clk;
		if(~old_clk & clk) begin
			cnt <= cnt_tmp;
			cnt_tmp <= 0;
		end
	end
end

reg crossed;
always @(posedge CLK_AUDIO) crossed <= (clk_rate[0].cnt <= clk_rate[1].cnt);
endgenerate

wire   i2s_ws   = crossed ? USER_IN[2] : USER_IN[5];
wire   i2s_data = crossed ? USER_IN[5] : USER_IN[2];
wire   i2s_bclk = crossed ? USER_IN[4] : USER_IN[6];
assign midi_rx  = crossed ? USER_IN[6] : USER_IN[4];

always @(posedge CLK_AUDIO) begin : i2s_proc
	reg [15:0] i2s_buf = 0;
	reg  [4:0] i2s_cnt = 0;
	reg        clk_sr;
	reg        i2s_clk = 0;
	reg        old_clk, old_ws;
	reg        i2s_next = 0;

	// Debounce clock
	clk_sr <= i2s_bclk;
	if (clk_sr == i2s_bclk) i2s_clk <= clk_sr;

	// Latch data and ws on rising edge
	old_clk <= i2s_clk;
	if (i2s_clk && ~old_clk) begin

		if (~i2s_cnt[4]) begin
			i2s_cnt <= i2s_cnt + 1'd1;
			i2s_buf[~i2s_cnt[3:0]] <= i2s_data;
		end

		// Word Select will change 1 clock before the new word starts
		old_ws <= i2s_ws;
		if (old_ws != i2s_ws) i2s_next <= 1;
	end

	if (i2s_next) begin
		i2s_next <= 0;
		i2s_cnt <= 0;
		i2s_buf <= 0;

		if (i2s_ws) mt32_i2s_l <= i2s_buf;
		else        mt32_i2s_r <= i2s_buf;
	end
	
	if (RESET) begin
		i2s_buf    <= 0;
		mt32_i2s_l <= 0;
		mt32_i2s_r <= 0;
	end
end

/////////////////////   VIDEO   ///////////////////

localparam lfsr_n = 63;

wire PAL = status[4];
wire FB  = status[5];
wire [2:0] led = status[8:6];

/* Phosphor: every mode comes from the native timing (Retro-Remake's menu_ConsoleMode, rtl/native_video_*,
   GPL-3.0-or-later) on a 27 MHz video clock. Without CRT mode it runs the menu core's usual rasters
   (240p, 288p with menu_pal, 480p/576p with forced_scandoubler) for the loading screen, MiSTer's static
   and the framebuffer terminal. Phosphor's CRT mode (status[9], Main sets it) shows Phosphor's own
   frames instead, from the native buffer at 0x3A000000, in the mode Main picks:
   status[24:22] 0 NTSC 240p, 1 480i 640, 2 PAL 288p, 3 480i 720, 4 576i, 5 480p, 6 576p, 7 480p 640;
   status[15:10] / [21:16] the horizontal / vertical centering (signed) */
reg [2:0] native_mode_m = 3'd0, native_mode = 3'd0;
reg [5:0] native_hoff_m = 6'd0, native_hoff = 6'd0;
reg [5:0] native_voff_m = 6'd0, native_voff = 6'd0;
reg       native_fb_m   = 1'b0, native_fb_v = 1'b0;
reg       pal_m = 1'b0, pal_v = 1'b0, dbl_m = 1'b0, dbl_v = 1'b0;
always @(posedge CLK_VIDEO) begin
	native_mode_m <= status[24:22]; native_mode <= native_mode_m;
	native_hoff_m <= status[15:10]; native_hoff <= native_hoff_m;
	native_voff_m <= status[21:16]; native_voff <= native_voff_m;
	native_fb_m   <= status[9];     native_fb_v <= native_fb_m;
	pal_m <= PAL;                   pal_v <= pal_m;
	dbl_m <= forced_scandoubler;    dbl_v <= dbl_m;
end
// the menu core's usual rasters when Phosphor's CRT mode is off
wire [2:0] raster_mode = native_fb_v ? native_mode : pal_v ? (dbl_v ? 3'd6 : 3'd2) : (dbl_v ? 3'd7 : 3'd0);
wire       raster_dbl  = native_fb_v ? (native_mode >= 3'd5) : dbl_v;
wire       raster_pal  = native_fb_v ? (native_mode == 3'd2 || native_mode == 3'd4 || native_mode == 3'd6) : pal_v;

// a CLK_VIDEO/2 grid for the 15 kHz modes; 480p/576p every clock (the full 27 MHz)
wire ce_full_rate = (raster_mode >= 3'd5);
reg  ce_timing;
always @(posedge CLK_VIDEO) begin
	if(RESET) ce_timing <= 1'b0;
	else      ce_timing <= ce_full_rate ? 1'b1 : ~ce_timing;
end
wire ce_pix = ce_timing;

wire [7:0] native_r, native_g, native_b;
wire       native_hs, native_vs, native_de, native_new_frame, native_active;
wire [9:0] hc, vc;

native_video_top native_video
(
	.clk_sys        (clk_sys),
	.clk_vid        (CLK_VIDEO),
	.ce_timing      (ce_timing),
	.reset          (RESET),

	.ddr_busy       (DDRAM_BUSY),
	.ddr_burstcnt   (nv_burst),
	.ddr_addr       (nv_addr),
	.ddr_dout       (DDRAM_DOUT),
	.ddr_dout_ready (DDRAM_DOUT_READY & nv_own),    // (only its own beats)
	.ddr_rd         (nv_rd),
	.ddr_din        (nv_din),
	.ddr_be         (nv_be),
	.ddr_we         (nv_we),

	.vga_r          (native_r),
	.vga_g          (native_g),
	.vga_b          (native_b),
	.vga_hs         (native_hs),
	.vga_vs         (native_vs),
	.vga_de         (native_de),
	.vga_hblank     (),
	.vga_vblank     (),
	.vga_hcount     (hc),
	.vga_vcount     (vc),
	.vga_new_frame  (native_new_frame),
	.vga_field      (native_field),
	.enable         (native_fb_v),
	.reader_enable  (nv_own & native_sys),        // (off when CRT mode goes: it stops, then gives DDRAM back)
	.reader_idle    (nv_idle),
	.active         (native_active),

	.mode           (raster_mode),
	.h_offset       ($signed(native_fb_v ? native_hoff : 6'd0)),
	.v_offset       ($signed(native_fb_v ? native_voff : 6'd0))
);

// the terminal and the loading screen are 640 wide: centred on the 704 / 720-wide rasters
wire [9:0] raster_xoff = (raster_mode == 3'd2) ? 10'd32 : (raster_mode >= 3'd3 && raster_mode <= 3'd6) ? 10'd40 : 10'd0;
wire [9:0] hc640 = hc - raster_xoff;
reg  [9:0] vvc;
reg  [lfsr_n:0] rnd_reg;
wire [lfsr_n:0] rnd;
wire  [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};
lfsr #(lfsr_n) random(rnd);
always @(posedge CLK_VIDEO) begin
	if(native_new_frame & ce_timing) vvc <= vvc + 10'd6;   // (new_frame lasts a whole pixel: 2 clocks at 15 kHz)
	if(ce_timing) rnd_reg <= rnd;
end

reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc>>raster_dbl, 2'b00}, cos_out);

wire [7:0] comp_v = (cos_g >= rnd_c) ? {cos_g - rnd_c, 2'b00} : 8'd0;

wire [23:0] fb_rgb;
wire        fb_active;

console_out console_out
(
	.clk_sys(clk_sys),
	.ddr_grant(fb_own),
	.ddr_addr(fb_addr),
	.ddr_burst(fb_burst),
	.ddr_rd(fb_rd),
	.ddr_busy(DDRAM_BUSY),
	.ddr_dout(DDRAM_DOUT),
	.ddr_dout_ready(DDRAM_DOUT_READY & fb_own),
	.ddr_idle(fb_idle),

	.fb_fmt(LFB_FMT),
	.fb_base(LFB_BASE),
	.fb_width(LFB_WIDTH),
	.fb_height(LFB_HEIGHT),
	.fb_stride(LFB_STRIDE),

	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_pix),
	.show(FB),
	.hc(hc640),
	.vc(vc),
	.height(raster_pal ? (raster_dbl ? 10'd576 : 10'd288) : (raster_dbl ? 10'd480 : 10'd240)),
	.rgb(fb_rgb),
	.active(fb_active)
);

// the framebuffer terminal's picture comes 2 clocks after hc / vc (console_out's pipeline): the syncs
// and the blanking go with it then; Phosphor's own frames come with the timing's own (the reader's)
wire use_native = native_fb_v & native_active;
reg  [1:0] de_d, hs_d, vs_d;
always @(posedge CLK_VIDEO) begin
	de_d <= {de_d[0], native_de};
	hs_d <= {hs_d[0], native_hs};
	vs_d <= {vs_d[0], native_vs};
end
reg  [1:0] ph_static_s;                              // (clk_sys's: into CLK_VIDEO)
always @(posedge CLK_VIDEO) ph_static_s <= {ph_static_s[0], ph_static};
wire       out_de = use_native ? native_de : de_d[1];
assign VGA_DE  = out_de;
assign VGA_HS  = use_native ? native_hs : hs_d[1];
assign VGA_VS  = use_native ? native_vs : vs_d[1];
// Phosphor: the loading screen while Phosphor has (or is about to have) the screen: from power-on,
// between cores, after a script. Behind MiSTer's own menu (Main sets PH_LOOK then) MiSTer's own
// background again: its static, under any wallpaper Main draws on top.
wire [23:0] tc_rgb;
loadscreen loadscreen
(
	.clk(CLK_VIDEO),
	.hc(hc640),
	.vc(vc),
	.pal(raster_pal),
	.dbl(raster_dbl),
	.rgb(tc_rgb)
);
// Phosphor's CRT mode with a frame ready: its frames; else the framebuffer terminal, MiSTer's static, the
// loading screen (black outside the active area)
assign VGA_R   = use_native ? native_r : ~out_de ? 8'd0 : fb_active ? fb_rgb[23:16] : ph_static_s[1] ? comp_v : tc_rgb[23:16];
assign VGA_G   = use_native ? native_g : ~out_de ? 8'd0 : fb_active ? fb_rgb[15:8]  : ph_static_s[1] ? comp_v : tc_rgb[15:8];
assign VGA_B   = use_native ? native_b : ~out_de ? 8'd0 : fb_active ? fb_rgb[7:0]   : ph_static_s[1] ? comp_v : tc_rgb[7:0];

endmodule
