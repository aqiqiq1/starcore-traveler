"""Generate the review examples through the public CLI, not through internals."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, "examples")
os.makedirs(EX, exist_ok=True)

CASES = [
    ("high_336x144.png", 336, 144, "ground", "solid", "broken"),
    ("high_336x144_both.png", 336, 144, "ground", "broken", "broken"),
    ("long_512x64.png", 512, 64, "ground", "solid", "solid"),
    ("long_1024x64.png", 1024, 64, "ground", "solid", "solid"),
    ("level02_ground_640x40.png", 640, 40, "ground", "solid", "solid"),
    ("min_ground_32x32.png", 32, 32, "ground", "broken", "broken"),
    ("beam_56x8.png", 56, 8, "deck", "solid", "solid"),
    ("beam_56x8_broken.png", 56, 8, "deck", "solid", "broken"),
    ("beam_16x6.png", 16, 6, "deck", "solid", "solid"),
    ("beam_24x6.png", 24, 6, "deck", "solid", "solid"),
    ("beam_56x24.png", 56, 24, "deck", "solid", "solid"),
    ("beam_56x24_broken.png", 56, 24, "deck", "solid", "broken"),
    ("step_56x14.png", 56, 14, "deck", "solid", "solid"),
    ("min_beam_8x6.png", 8, 6, "deck", "broken", "broken"),
    ("pier_8x36.png", 8, 36, "pier", "solid", "solid"),
    ("pier_8x36_broken.png", 8, 36, "pier", "solid", "broken"),
    ("pier_8x24.png", 8, 24, "pier", "solid", "solid"),
    ("pier_16x36.png", 16, 36, "pier", "solid", "solid"),
]

for name, w, h, kind, left, right in CASES:
    out = os.path.join(EX, name)
    cmd = [sys.executable, os.path.join(HERE, "build_block.py"),
           "--width", str(w), "--height", str(h), "--kind", kind,
           "--left", left, "--right", right, "--output", out]
    print(" ".join(cmd))
    subprocess.check_call(cmd, cwd=HERE)
print("examples done")
