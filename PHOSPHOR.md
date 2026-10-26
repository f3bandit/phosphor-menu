# phosphor-menu

The MiSTer menu core (a fork of [MiSTer-devel/Menu_MiSTer](https://github.com/MiSTer-devel/Menu_MiSTer))
with one addition for Phosphor OS on the SuperStation One: Main can read PlayStation controllers
and memory cards on the front ports (SNAC) while the menu core is loaded, so Phosphor's
Controllers and Memory Cards screens work without loading another core.

Phosphor's Main ([phosphor-main](https://github.com/f3bandit/phosphor-main)) loads this core wherever it
would load `menu.rbf` when it's installed (`/media/fat/phosphor/cores/menu_phosphor.rbf`); `menu.rbf`
itself is never replaced. The front ports stay off until Main turns them on. Until then the user port works exactly as in the stock menu core (MT32-pi, MIDI).
While they are on, MT32-pi audio and MIDI are off.

## What's added

- `rtl/phosphor/phosphor_ext.sv`: the commands below on hps_io's `EXT_BUS`, a reader that reads
  both controllers in turn (each every 8 ms), and a 128-byte sector buffer.
- `rtl/phosphor/card_sector.sv`, `rtl/phosphor/sio_byte.sv`: the controller and memory card bus,
  from the SS1 Controller Tester core.
- `menu.sv`: the extension on `EXT_BUS` and the user port switched between the stock use and the
  front ports.

## The loading screen

The background (between cores, after a script, behind MiSTer's own menu) is Phosphor's loading
screen instead of MiSTer's static: the PHOSPHOR wordmark, a row of blocks with a scanner sweeping
left to right through them, and NOW LOADING. `rtl/loadscreen.sv` draws it from the beam position
with no memory beyond two small tables (`rtl/loadscreen_x.hex`, `rtl/loadscreen_y.hex`, made by
`rtl/loadscreen_rom.py`). To see it: `iverilog -g2012 -o sim/tb_loadscreen.vvp sim/tb_loadscreen.sv
rtl/loadscreen.sv && vvp -n sim/tb_loadscreen.vvp` writes a frame (`sim/ls_full.ppm`) and the
scanner over 40 frames (`sim/ls_anim.ppm`).

## Commands

16-bit words; the first word is the command. The reply to a word is read with the next one.

| Code | Name | Words |
|---|---|---|
| 0x80 | PH_ID | reply: `5048` ('PH'), version, mode |
| 0x81 | PH_MODE | write: mode (bit 0: front ports on); reply: `5048`, old mode |
| 0x82 | PH_PADS | reply: mode, then per port (1, 2): `{answered, ID}`, buttons (active low), `{RY,RX}`, `{LY,LX}` |
| 0x83 | PH_CARD | write: `{port 2 (bit 8), op (0 read, 1 write)}`, sector, then 64 data words for a write |
| 0x84 | PH_CARD_STATUS | reply: `{busy, done, …, result}`, then the 64 data words of the last read |
| 0x85 | PH_PAD_CMD | write: `{port 2 (bit 8), command}`: 1 config mode, 2 analog on, 3 leave config |

Results: 0 OK, 1 no card, 2 bad reply or refused, 3 sector out of range. A stock menu core
answers 0 to all of these, so Main knows which one is loaded from PH_ID.

## Testing

`sh sim/run.sh` (Icarus Verilog) runs the extension against a modelled controller with a memory
card and a second, digital controller. GitHub Actions runs the simulation and builds the core
with Quartus 17.0.2 Lite on every push to the `phosphor` branch.

GPL-3.0 for the Phosphor files; the menu core itself is GPL-2.0-or-later.

## Licence

MiSTer's Menu core is free software under the GNU General Public License, version 2 or (at your
option) any later version. Phosphor's additions (rtl/phosphor/, rtl/loadscreen*, the changes to
menu.sv, sim/ and the build workflow) are Copyright (C) 2026 f3bandit under GPL-3.0 or later, so this
core as a whole is distributed under the GNU General Public License version 3 (COPYING).
