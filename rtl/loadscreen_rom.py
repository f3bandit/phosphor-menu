#!/usr/bin/env python3
# Makes the loading screen's lookup tables (rtl/loadscreen_x.hex, rtl/loadscreen_y.hex): what is at
# each column and on each line, so the core does no division. Layout: 640 x 240 shown at 16:9 (see
# loadscreen.sv). Run from anywhere: python3 rtl/loadscreen_rom.py
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# PHOSPHOR: 8 letters, each pixel 3 px by 2 lines, a letter every 32 px (8 px apart)
WORD_X, WORD_CELL, WORD_N = 196, 32, 8
# the scanner: 16 blocks, 13 px wide, 3 px apart
BLK_X, BLK_W, BLK_GAP, BLK_N = 194, 13, 3, 16
# NOW LOADING: 11 letters, 1 px by 1 line
TEXT_X, TEXT_N = 276, 11
# lines
WORD_Y, BLK_Y0, BLK_Y1, TEXT_Y = 89, 115, 123, 136

def xword(x):
    w = 0
    def put(v, lo, bits):
        nonlocal w
        w |= (v & ((1 << bits) - 1)) << lo
    o = x - WORD_X
    if 0 <= o < WORD_N * WORD_CELL and o % WORD_CELL < 24:
        put(1, 0, 1); put(o // WORD_CELL, 1, 3); put((o % WORD_CELL) // 3, 4, 3)
    o = x - BLK_X
    if 0 <= o < BLK_N * (BLK_W + BLK_GAP) and o % (BLK_W + BLK_GAP) < BLK_W:
        put(1, 7, 1); put(o // (BLK_W + BLK_GAP), 8, 4)
    o = x - TEXT_X
    if 0 <= o < TEXT_N * 8:
        put(1, 12, 1); put(o >> 3, 13, 4); put(o & 7, 17, 3)
    return w

def yword(y):
    w = 0
    def put(v, lo, bits):
        nonlocal w
        w |= (v & ((1 << bits) - 1)) << lo
    if WORD_Y <= y < WORD_Y + 16: put(1, 0, 1); put((y - WORD_Y) >> 1, 1, 3)
    put(BLK_Y0 <= y <= BLK_Y1, 4, 1)
    if TEXT_Y <= y < TEXT_Y + 8: put(1, 5, 1); put(y - TEXT_Y, 6, 3)
    return w

with open(os.path.join(HERE, "loadscreen_x.hex"), "w") as f:
    for x in range(640): f.write("%05x\n" % xword(x))
with open(os.path.join(HERE, "loadscreen_y.hex"), "w") as f:
    for y in range(256): f.write("%03x\n" % yword(y))
