"""Make XCUIScreen landscape captures true landscape PNGs.

XCUIScreen saves landscape screenshots as portrait pixels plus an orientation tag
(EXIF chunk and XMP in iTXt). App Store Connect wants real pixels, so this drops both
chunks; rotate the landscape files afterwards with `sips -r 270 <file>`.

Usage: python3 -I fix_orientation.py file.png [file.png ...]
"""
import struct
import sys


def strip(path):
    data = open(path, "rb").read()
    out, i = data[:8], 8
    while i < len(data):
        length = struct.unpack(">I", data[i:i + 4])[0]
        kind = data[i + 4:i + 8]
        if kind not in (b"eXIf", b"iTXt"):
            out += data[i:i + 12 + length]
        i += 12 + length
    open(path, "wb").write(out)


for p in sys.argv[1:]:
    strip(p)
