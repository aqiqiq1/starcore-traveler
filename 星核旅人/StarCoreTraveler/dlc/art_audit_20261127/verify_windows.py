"""Verify the three DLC3 window bays are the same pattern and have no black panes.

Reads the runtime city_v2 background.  Prints the glass mask SHA256 for each bay
and the count of pixels with max(R,G,B) < 32 inside the glass.  Exit 0 only when
all three glass hashes match and no near-black pixels exist.

Run:
    D:/minic/envs/2024212971/python.exe dlc/art_audit_20261127/verify_windows.py
"""

import hashlib
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "dlc", "star_loom", "assets", "city_v2", "city_back_960x360.png")
WINDOWS = (76, 264, 452)
TOP = 92
BOTTOM = TOP + 203
HALF_WIDTH = 125


def arch_spans(x0, y0, x1, y1):
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    spring = y0 + half
    for y in range(y0, y1 + 1):
        if y < spring:
            dy = spring - y
            h = math.sqrt(max(half * half - dy * dy, 0.0))
        else:
            h = half
        yield y, int(round(cx - h)), int(round(cx + h))


def main() -> int:
    image = Image.open(SRC).convert("RGBA")
    hashes = []
    dark_total = 0
    pixel_total = 0
    for wx in WINDOWS:
        data = []
        for y, left, right in arch_spans(wx, TOP, wx + HALF_WIDTH, BOTTOM):
            for x in range(left, right + 1):
                pixel = image.getpixel((x, y))
                data.extend(pixel)
                pixel_total += 1
                if max(pixel[:3]) < 32:
                    dark_total += 1
        digest = hashlib.sha256(bytes(data)).hexdigest()
        hashes.append(digest)
        print("window x=%d glass_sha256=%s" % (wx, digest))
    print("dark_pixels=%d / %d" % (dark_total, pixel_total))
    ok = len(set(hashes)) == 1 and dark_total == 0
    print("WINDOW_CHECK", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
