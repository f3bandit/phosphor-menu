> **phosphor-menu**: Phosphor's fork of the MiSTer menu core, part of [Phosphor](https://github.com/f3bandit/phosphor_os)
> (unofficial custom firmware for the SuperStation One, built on mainline MiSTer). It adds the front ports
> (PlayStation controllers and memory cards over SNAC), off until Phosphor asks: see [PHOSPHOR.md](PHOSPHOR.md).
> Everything else below is the menu core's own README. GPL; not made or supported by MiSTer-devel.
>
> The menu core is the work of **Alexey Melnikov (Sorgelig)** and the
> [MiSTer-devel contributors](https://github.com/MiSTer-devel/Menu_MiSTer/graphs/contributors); their commits are kept
> in this repository's history. The front ports (from f3bandit's SS1 Controller Tester and SS1 Memory Card Tool
> cores) and Phosphor's other changes: **f3bandit**. CRT modes: the native video path from Retro Remake's
> [menu_ConsoleMode](https://github.com/Retro-Remake/menu_consolemode).

# Startup core for MiSTer

* **ESC** - Back/Options
* **Enter** - OK
* **F1** - Cycle Background/Wallpaper
* **F9** - Go to Linux terminal (F12 - back)
* **F11** - Bluetooth Pairing Script
* **F12** - Recent Cores

## Notes:
* Core supports sub-folders started with _ character.
* Regardless the place of RBF file, boot rom/vhd should be placed into either root of SD card or core's dedicated folder (should be created in root of SD card).
* Joystick (including emulation by keyboard) buttons defined in this core is default map for all cores unless defined in particalar core.

## Wallpaper
* Place menu.png or menu.jpg to the root of SD card to have it as background on HDMI (you can use vga_scaler=1 if you want it on VGA).
* Create "wallpapers" folder and place multiple .jpg or .png to it. Use **F1** to cycle between standard MiSTer backgrounds and wallpapers in folder.
