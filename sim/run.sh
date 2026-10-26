#!/bin/sh
# Simulates the Phosphor extension against modelled controllers and a memory card (needs Icarus Verilog).
# Copyright (C) 2026 f3bandit. GPL-3.0 like the rest of the menu core (see COPYING).
cd "$(dirname "$0")/.." && iverilog -g2012 -o sim/tb_phosphor.vvp sim/tb_phosphor.sv sim/card_model.sv \
	rtl/phosphor/sio_byte.sv rtl/phosphor/card_sector.sv rtl/phosphor/phosphor_ext.sv && vvp -n sim/tb_phosphor.vvp
