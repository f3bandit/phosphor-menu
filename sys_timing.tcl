# Phosphor CI: the worst paths between the menu core's two clocks (clk_sys 100 MHz, CLK_VIDEO 27 MHz)
project_open menu -revision menu
create_timing_netlist
read_sdc
update_timing_netlist
set c0 [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set c1 [get_clocks {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]
report_timing -setup -from_clock $c0 -to_clock $c1 -npaths 60 -detail summary -file output_files/cross_0to1.rpt
report_timing -setup -from_clock $c1 -to_clock $c0 -npaths 60 -detail summary -file output_files/cross_1to0.rpt
report_timing -setup -from_clock $c1 -to_clock $c1 -npaths 20 -detail summary -file output_files/vid_vid.rpt
report_timing -setup -from_clock $c0 -to_clock $c0 -npaths 20 -detail summary -file output_files/sys_sys.rpt
report_timing -recovery -npaths 30 -detail summary -file output_files/recovery.rpt
project_close
