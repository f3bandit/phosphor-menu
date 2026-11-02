# Additional permission for Retro Remake

Copyright (C) 2026 f3bandit. The controller tester and the memory card manager are f3bandit's idea
and design.

This core is licensed to everyone under the GNU General Public License, version 3 or later (COPYING).
In addition, f3bandit grants **Retro Remake** and **Taki Udon** (GitHub: Takiiiiiiii) the following,
for f3bandit's own code in this repository only:

- `rtl/phosphor/` (the front ports: PlayStation controllers and memory cards over SNAC)
- `rtl/loadscreen.sv`, `rtl/loadscreen_rom.py` and the loading screen's data files
- `sim/` (the test benches)
- f3bandit's changes to `menu.sv`

Permission to use, copy, modify, merge, publish, distribute, sublicense and sell that code, in whole
or in part, in any product of theirs (including closed-source software such as Console Mode, and their
hardware), without the GPL's conditions, free of charge. The only condition: a mention of f3bandit in
the credits of anything that uses it.

Not covered: MiSTer's Menu core itself and `sys/` (Alexey Melnikov (Sorgelig) and the MiSTer-devel
contributors, GPL-2.0-or-later), the native video path (`rtl/native_video_*`, from Retro Remake's own
menu_ConsoleMode) and the Quartus-generated PLL files. A core built from this repository as a whole
stays under the GPL.

This permission is personal to Retro Remake and Taki Udon and isn't transferable, except to people
working on Retro Remake products for them. Everyone else gets this code under the GPL only.

The code is provided "as is", without warranty of any kind.
