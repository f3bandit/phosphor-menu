# Phosphor's menu core: clk_sys (100 MHz) and CLK_VIDEO (27.027 MHz, the native video timing) come from
# the same PLL but aren't in step (37 / 10 of the VCO), so sys_top.sdc's one group for them makes the
# timer check them as if they were. Every crossing between them is synchronised in the logic: the
# native reader's dcfifo and two-flop synchronisers (rtl/native_video_reader.sv), console_out's toggle,
# line buffer and cols (synchronised), ph_static (synchronised in menu.sv), hps_io's video_calc, the OSD's
# settings (static while shown), status bits (synchronised in menu.sv).
# Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core (see COPYING).
set_clock_groups -asynchronous \
   -group [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
   -group [get_clocks {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]
