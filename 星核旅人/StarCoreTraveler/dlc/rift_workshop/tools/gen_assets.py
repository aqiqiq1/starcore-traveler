"""Original asset generator for the 裂隙工坊 DLC chapter.

Everything written by this script is generated from code in this repository:
no third-party image, sprite, audio or font is downloaded, sampled, traced or
copied.  The shapes, gradients and tones below are authored here.

Outputs (all inside res://dlc/rift_workshop/assets):
  sprites/polarity_wisp_16x16_8f.png   8 frames = 4-frame float loop x gold/cyan
  rift_fog_640x360.png                 screen-space purple haze overlay
  audio/sfx_inversion.wav              16-bit 44.1 kHz mono
  audio/sfx_bridge.wav
  audio/sfx_wisp_hum.wav               exact 1.000 s loop
  audio/sfx_wisp_pop.wav
  audio/sfx_complete.wav

Run with:
  D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/gen_assets.py
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ASSETS = os.path.join(ROOT, "assets")
SPRITES = os.path.join(ASSETS, "sprites")
AUDIO = os.path.join(ASSETS, "audio")

# Project palette (shared with the three base levels / trial chapter).
GOLD = (244, 205, 99)
CYAN = (95, 225, 230)
PURPLE = (168, 116, 255)
NEAR_BLACK = (10, 18, 22)

GOLD_DARK = (86, 60, 16)
GOLD_MID = (201, 154, 58)
GOLD_LIGHT = (244, 205, 99)
GOLD_CORE = (255, 244, 205)

CYAN_DARK = (18, 78, 86)
CYAN_MID = (47, 169, 180)
CYAN_LIGHT = (95, 225, 230)
CYAN_CORE = (222, 255, 255)


# ---------------------------------------------------------------------------
# PolarityWisp sprite: 16x16, 4 animation frames, gold then cyan.
# ---------------------------------------------------------------------------

def _put(px, x, y, color):
    if 0 <= x < 16 and 0 <= y < 16:
        px[x, y] = color


def _wisp_frame(positive: bool, frame: int) -> Image.Image:
    """One 16x16 orb.

    Read order at native size: dark 1 px silhouette, a two-tone round body, a
    bright core, then three tail pixels that sway with the frame.  The gold and
    cyan variants share the same silhouette so the state reads as a recolour,
    never as a different creature.
    """
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = image.load()
    if positive:
        dark, mid, light, core = GOLD_DARK, GOLD_MID, GOLD_LIGHT, GOLD_CORE
    else:
        dark, mid, light, core = CYAN_DARK, CYAN_MID, CYAN_LIGHT, CYAN_CORE

    cx, cy = 7.5, 6.5
    # Body + silhouette. Radius 5 gives a 10 px orb with a 1 px outline.
    body = set()
    for y in range(16):
        for x in range(16):
            dx = (x - cx) / 5.0
            dy = (y - cy) / 5.0
            if dx * dx + dy * dy <= 1.0:
                body.add((x, y))
    # A two-pixel neck and a pointed tail make the round body read as a
    # floating spirit instead of a coin.
    tail = [(7, 11), (8, 11), (7, 12), (8, 12)]
    for (x, y) in tail:
        body.add((x, y))
    ring = set()
    for (x, y) in body:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + ox, y + oy) not in body:
                ring.add((x + ox, y + oy))
    for (x, y) in ring:
        _put(px, x, y, (*dark, 255))
    for (x, y) in body:
        dx = (x - cx) / 5.0
        dy = (y - cy) / 5.0
        shade = dx * dx + dy * dy
        _put(px, x, y, (*(light if shade < 0.42 else mid), 255))

    # One large eye: 4x4 pale sclera with a 2x2 dark pupil that tracks left /
    # right across the 4-frame loop.  It is the first read at 2x zoom.
    for ey in range(5, 9):
        for ex in range(6, 10):
            if (ex, ey) in body:
                _put(px, ex, ey, (*core, 255))
    pupil_shift = (-1, 0, 1, 0)[frame]
    pupil_x = 7 + pupil_shift
    for ey in range(6, 8):
        for ex in range(pupil_x, pupil_x + 2):
            _put(px, ex, ey, (*dark, 255))
    _put(px, 6, 5, (*core, 210))  # eye glint, fixed

    # Tapering tail below the body, swaying opposite the pupil.
    sway = (-1, 0, 1, 0)[frame]
    _put(px, 7 + sway, 13, (*mid, 255))
    _put(px, 7 + sway * 2, 14, (*mid, 210))
    _put(px, 8 + sway, 14, (*dark, 210))
    _put(px, 7 + sway * 2, 15, (*light, 165))

    # Two side fins: 1 px each, offset with the frame, never touching the eye.
    _put(px, 2, 7 + (frame % 2), (*mid, 220))
    _put(px, 13, 8 - (frame % 2), (*mid, 220))

    # One orbiting rim spark, 4 positions.
    spark = ((3, 3), (12, 5), (10, 11), (4, 10))[frame]
    _put(px, spark[0], spark[1], (*core, 235))

    # Two dim aura pixels outside the outline keep the orb from reading as a
    # hard-edged ball against the bright sky.
    aura = ((1, 6), (13, 2), (14, 9), (2, 11))[frame]
    _put(px, aura[0], aura[1], (*light, 90))
    return image


def build_wisp_strip() -> None:
    os.makedirs(SPRITES, exist_ok=True)
    strip = Image.new("RGBA", (16 * 8, 16), (0, 0, 0, 0))
    for frame in range(4):
        strip.alpha_composite(_wisp_frame(True, frame), (frame * 16, 0))
        strip.alpha_composite(_wisp_frame(False, frame), ((frame + 4) * 16, 0))
    path = os.path.join(SPRITES, "polarity_wisp_16x16_8f.png")
    strip.save(path)
    print("wrote", path, strip.size)


# ---------------------------------------------------------------------------
# Rift fog overlay: 640x360 screen-space purple haze.
# ---------------------------------------------------------------------------

def build_fog() -> None:
    os.makedirs(ASSETS, exist_ok=True)
    w, h = 640, 360
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = image.load()
    rng = random.Random(20261125)
    blobs = [
        (140.0, 292.0, 230.0, 118.0, 96.0),
        (360.0, 322.0, 280.0, 104.0, 88.0),
        (560.0, 300.0, 210.0, 100.0, 84.0),
        (250.0, 196.0, 190.0, 86.0, 58.0),
        (470.0, 214.0, 170.0, 78.0, 50.0),
    ]
    for y in range(h):
        # Vertical grade: clear at the crown, violet toward the sea line, so
        # the gold/cyan gameplay colours keep their contrast.
        base = 22.0 * (y / float(h)) ** 1.6
        for x in range(w):
            alpha = base
            for (bx, by, rx, ry, amp) in blobs:
                dx = (x - bx) / rx
                dy = (y - by) / ry
                falloff = 1.0 - (dx * dx + dy * dy)
                if falloff > 0.0:
                    alpha += amp * falloff * falloff
            a = int(max(0.0, min(alpha, 150.0)))
            if a <= 0:
                continue
            # Slight horizontal hue drift: deeper violet low, brighter lilac
            # near the top of each body, all within the same purple family.
            t = y / float(h)
            r = int(PURPLE[0] * (0.70 + 0.22 * t))
            g = int(PURPLE[1] * (0.58 + 0.20 * t))
            b = int(PURPLE[2] * (0.88 + 0.10 * t))
            px[x, y] = (r, g, b, a)
    # A thin static dust band: 1 px specks only, no dithering on the haze.
    draw = ImageDraw.Draw(image)
    for _ in range(300):
        x = rng.randrange(w)
        y = rng.randrange(70, h)
        a = rng.randrange(40, 90)
        draw.point((x, y), fill=(*PURPLE, a))
    path = os.path.join(ASSETS, "rift_fog_640x360.png")
    image.save(path)
    print("wrote", path, image.size)


# ---------------------------------------------------------------------------
# Audio: short original tones, 16-bit 44.1 kHz mono.
#
# Every file is peak-normalised on write, so regenerating it can never drift
# back to an inaudible level.  One-shots sit at -3 dBFS (comparable to the base
# levels' -3..-6 dBFS cues); the looping wisp hum is deliberately quieter at
# -9 dBFS because four of them can be audible at once.
# ---------------------------------------------------------------------------

RATE = 44100
ONE_SHOT_PEAK_DB = -3.0
HUM_PEAK_DB = -9.0


def db_to_peak(db: float) -> float:
    return math.pow(10.0, db / 20.0)


def _env(i: int, n: int, attack: float = 0.01, release: float = 0.05) -> float:
    t = i / float(RATE)
    total = n / float(RATE)
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, max(0.0, (total - t) / release)) if release > 0 else 1.0
    return a * r


def _write_wav(name: str, samples: list[float], peak_db: float) -> None:
    os.makedirs(AUDIO, exist_ok=True)
    top = max(1e-9, max(abs(s) for s in samples))
    scale = db_to_peak(peak_db) / top
    frames = bytearray()
    written_top = 0
    for s in samples:
        v = int(max(-1.0, min(1.0, s * scale)) * 32767.0)
        written_top = max(written_top, abs(v))
        frames += struct.pack("<h", v)
    path = os.path.join(AUDIO, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))
    actual_db = 20.0 * math.log10(max(written_top, 1) / 32767.0)
    print(
        "wrote", path,
        "%.3fs" % (len(samples) / float(RATE)),
        "peak=%.2f dBFS (target %.2f)" % (actual_db, peak_db),
    )


def build_inversion() -> None:
    n = int(RATE * 0.55)
    out = []
    for i in range(n):
        t = i / float(RATE)
        p = t / 0.55
        env = _env(i, n, 0.008, 0.16)
        # A falling fundamental crossed by a rising shimmer: reads as "the
        # phase just turned over", not as a UI click.
        f1 = 1180.0 * math.pow(0.24, p)
        f2 = 260.0 * math.pow(3.6, p)
        s = 0.55 * math.sin(2.0 * math.pi * f1 * t + 1.1 * math.sin(2.0 * math.pi * 7.0 * t))
        s += 0.30 * math.sin(2.0 * math.pi * f2 * t)
        s += 0.06 * math.sin(2.0 * math.pi * (f1 * 2.02) * t)
        out.append(s * env)
    _write_wav("sfx_inversion.wav", out, ONE_SHOT_PEAK_DB)


def build_bridge() -> None:
    n = int(RATE * 0.42)
    out = []
    for i in range(n):
        t = i / float(RATE)
        env = math.exp(-4.2 * t) * _env(i, n, 0.005, 0.10)
        rise = 1.0 + 0.06 * min(1.0, t / 0.08)
        s = 0.5 * math.sin(2.0 * math.pi * 523.25 * rise * t)
        s += 0.28 * math.sin(2.0 * math.pi * 784.0 * rise * t)
        s += 0.12 * math.sin(2.0 * math.pi * 1568.0 * rise * t)
        s += 0.05 * math.sin(2.0 * math.pi * 2093.0 * t)
        out.append(s * env)
    _write_wav("sfx_bridge.wav", out, ONE_SHOT_PEAK_DB)


def build_wisp_hum() -> None:
    # Exactly 1.000 s so the looped playback has no seam. 148 / 222 / 3 Hz are
    # all integer multiples of the 1 Hz loop frequency.
    n = RATE
    out = []
    for i in range(n):
        t = i / float(RATE)
        tremolo = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2.0 * math.pi * 3.0 * t))
        s = 0.55 * math.sin(2.0 * math.pi * 148.0 * t)
        s += 0.30 * math.sin(2.0 * math.pi * 222.0 * t + 0.7)
        s += 0.10 * math.sin(2.0 * math.pi * 296.0 * t + 1.9)
        out.append(s * tremolo)
    _write_wav("sfx_wisp_hum.wav", out, HUM_PEAK_DB)


def build_wisp_pop() -> None:
    n = int(RATE * 0.34)
    rng = random.Random(7717)
    out = []
    low = 0.0
    for i in range(n):
        t = i / float(RATE)
        env = math.exp(-9.0 * t) * _env(i, n, 0.002, 0.08)
        chirp_f = 780.0 * math.pow(0.22, t / 0.34)
        s = 0.55 * math.sin(2.0 * math.pi * chirp_f * t)
        # One-pole low-passed noise gives an airy puff instead of a click.
        low += 0.24 * (rng.uniform(-1.0, 1.0) - low)
        s += 0.75 * low
        out.append(s * env)
    _write_wav("sfx_wisp_pop.wav", out, ONE_SHOT_PEAK_DB)


def build_complete() -> None:
    n = int(RATE * 1.9)
    notes = [(392.00, 0.00), (523.25, 0.16), (659.25, 0.32), (783.99, 0.48)]
    out = []
    for i in range(n):
        t = i / float(RATE)
        s = 0.0
        for (freq, start) in notes:
            local = t - start
            if local < 0.0:
                continue
            env = math.exp(-2.3 * local) * min(1.0, local / 0.02)
            s += 0.30 * math.sin(2.0 * math.pi * freq * local)
            s += 0.10 * math.sin(2.0 * math.pi * freq * 2.0 * local)
        # Soft low pad under the arpeggio, fading with the tail.
        s += 0.12 * math.sin(2.0 * math.pi * 196.0 * t) * max(0.0, 1.0 - t / 1.9)
        s *= _env(i, n, 0.02, 0.30)
        out.append(s)
    _write_wav("sfx_complete.wav", out, ONE_SHOT_PEAK_DB)


def main() -> None:
    build_wisp_strip()
    build_fog()
    build_inversion()
    build_bridge()
    build_wisp_hum()
    build_wisp_pop()
    build_complete()


if __name__ == "__main__":
    main()
