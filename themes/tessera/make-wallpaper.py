#!/usr/bin/env python3
"""Generate the Tessera wallpaper: charcoal with a faint dot grid fading in from one corner.

Standard library only. Usage: make-wallpaper.py [out.png] [width] [height]
"""
import struct
import sys
import zlib

out = sys.argv[1] if len(sys.argv) > 1 else "wallpaper.png"
W = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
H = int(sys.argv[3]) if len(sys.argv) > 3 else 1440

BG = (0x10, 0x10, 0x12)
STEP = 16  # dot pitch in pixels
REACH = 0.55  # how far the pattern reaches from the bottom-right corner


def level(x, y):
    """0..1 strength of the dot pattern at (x, y)."""
    dx = (W - x) / W
    dy = (H - y) / H
    d = (dx * dx + dy * dy) ** 0.5
    return max(0.0, 1.0 - d / REACH)


rows = bytearray()
for y in range(H):
    row = bytearray(BG * W)
    if y % STEP < 2:
        for x in range(0, W, STEP):
            s = level(x, y)
            if s <= 0:
                continue
            v = int(22 * s)
            px = bytes((BG[0] + v, BG[1] + v, BG[2] + v))
            row[x * 3:x * 3 + 6] = px * 2
    rows += b"\x00" + row


def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))


with open(out, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
    f.write(chunk(b"IDAT", zlib.compress(bytes(rows), 9)))
    f.write(chunk(b"IEND", b""))
