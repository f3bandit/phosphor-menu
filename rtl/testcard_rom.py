#!/usr/bin/env python3
# Makes the test card's lookup tables (rtl/testcard_x.hex, rtl/testcard_y.hex): everything that
# depends only on the column or only on the line, worked out here so the core does no division.
# Layout: 640 x 240 shown at 16:9 (see testcard.sv). Run from anywhere: python3 rtl/testcard_rom.py
import os

HERE = os.path.dirname(os.path.abspath(__file__))

def xword(x):
    w = 0
    def put(v, lo, bits):
        nonlocal w
        w |= (v & ((1 << bits) - 1)) << lo
    put(x % 20 == 0, 0, 1)                                   # grid line
    if 192 <= x < 448: put(1, 4, 1); put((x - 192) >> 5, 1, 3)   # colour bar and which
    if 224 <= x < 416:                                       # PHOSPHOR: 24 px a letter, 3 px a column
        o = x - 224; put(1, 5, 1); put(o // 24, 6, 3); put((o % 24) // 3, 9, 3)
    if 260 <= x < 380:                                       # PLEASE STAND BY: 8 px a letter
        o = x - 260; put(1, 12, 1); put(o >> 3, 13, 4); put(o & 7, 17, 3)
    if 195 <= x < 445: put(1, 20, 1); put((x - 195) // 25, 21, 4)   # grey scale step
    if 192 <= x < 447:                                       # resolution wedges
        o = x - 192; z = o // 51; wo = o - z * 51
        stripe = [5, 4, 3, 2, 1][min(z, 4)]
        on = (wo % (2 * stripe)) < stripe and 3 <= wo <= 47
        put(1, 25, 1); put(on, 26, 1)
    put(x in (319, 320), 27, 1)                              # centre line
    return w

def yword(y):
    w = 0
    def put(v, lo, bits):
        nonlocal w
        w |= (v & ((1 << bits) - 1)) << lo
    put((y * 3) % 40 < 3, 0, 1)                              # grid line (cells 20 px by 13.3 lines)
    put(63 <= y <= 92, 1, 1)                                 # colour bars
    if 107 <= y < 123: put(1, 2, 1); put((y - 107) >> 1, 3, 3)   # PHOSPHOR: 2 lines a row
    if 131 <= y < 139: put(1, 6, 1); put(y - 131, 7, 3)          # PLEASE STAND BY
    put(147 <= y <= 170, 10, 1)                              # grey scale
    put(175 <= y <= 188, 11, 1)                              # wedges
    put(20 <= y < 63 or 188 < y <= 220, 12, 1)               # centre line
    return w

with open(os.path.join(HERE, "testcard_x.hex"), "w") as f:
    for x in range(640): f.write("%08x\n" % xword(x))
with open(os.path.join(HERE, "testcard_y.hex"), "w") as f:
    for y in range(256): f.write("%04x\n" % yword(y))
