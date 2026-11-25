"""Generate the original pixel art and sound effects for DLC chapter 3.

Everything here is drawn/written procedurally with Pillow + the standard
library; no external image, sprite, font or audio sample is read.  Run with:

    D:/minic/envs/2024212971/python.exe dlc/star_loom/tools/gen_assets.py

Outputs (all inside dlc/star_loom/assets/):
    sprites/loom_boss_96x96_2f.png    192x96  96x96 boss, 2 pulse frames
    sprites/loom_node_24x24_2f.png     48x24  24x24 polarity node, 2 frames
    sprites/loom_bullet_8x8_2f.png     16x8   8x8  homing bolt, 2 frames
    sprites/loom_wisp_16x16_4f.png     64x16  16x16 rift wisp, 4 frames
    loom_bg_overlay_960x360.png       960x360 translucent loom/thread overlay
    audio/*.wav                       44.1 kHz mono 16-bit, peak -3 dBFS
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
ASSETS = os.path.join(DLC, "assets")
SPRITES = os.path.join(ASSETS, "sprites")
AUDIO = os.path.join(ASSETS, "audio")

GOLD = (244, 205, 99, 255)
CYAN = (95, 225, 230, 255)
PURPLE = (168, 116, 255, 255)
PURPLE_DARK = (58, 28, 86, 255)
INK = (10, 8, 18, 255)
DARK = (26, 16, 38, 255)
WHITE = (255, 255, 255, 255)
GRAY = (216, 216, 216, 255)


def ensure_dirs() -> None:
    for path in (SPRITES, AUDIO):
        os.makedirs(path, exist_ok=True)


# ---------------------------------------------------------------------------
# pixel art
# ---------------------------------------------------------------------------


def px(draw: ImageDraw.ImageDraw, x: int, y: int, color) -> None:
    draw.point((x, y), fill=color)


def ring(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    radius: float,
    color,
    thickness: int = 1,
) -> None:
    """Hard 1 px (or n px) circle; no anti-aliasing."""
    outer = radius + (thickness - 1) * 0.5
    inner = radius - thickness * 0.5
    for y in range(int(cy - outer) - 1, int(cy + outer) + 2):
        for x in range(int(cx - outer) - 1, int(cx + outer) + 2):
            d = math.hypot(x - cx, y - cy)
            if inner <= d <= outer:
                draw.point((x, y), fill=color)


def disc(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, color) -> None:
    for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
        for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
            if math.hypot(x - cx, y - cy) <= radius:
                draw.point((x, y), fill=color)


def make_boss_frame(frame: int) -> Image.Image:
    image = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Outer loom frame: top/bottom beams and two uprights.
    draw.rectangle((6, 6, 90, 12), fill=DARK)
    draw.rectangle((6, 84, 90, 90), fill=DARK)
    draw.rectangle((6, 13, 12, 83), fill=DARK)
    draw.rectangle((84, 13, 90, 83), fill=DARK)
    # Warm edge lights, 1 px.
    draw.rectangle((8, 8, 88, 8), fill=(120, 92, 52, 255))
    draw.rectangle((8, 88, 88, 88), fill=(120, 92, 52, 255))
    draw.rectangle((8, 14, 8, 82), fill=(96, 76, 48, 255))
    draw.rectangle((88, 14, 88, 82), fill=(96, 76, 48, 255))

    # Main ring around the core.
    ring(draw, 48, 48, 34, INK, 4)
    ring(draw, 48, 48, 33, (86, 54, 122, 255), 2)
    # Alternating polarity studs on the ring.
    for index in range(8):
        angle = index * math.tau / 8.0 + math.pi / 8.0
        x = int(round(48 + math.cos(angle) * 34))
        y = int(round(48 + math.sin(angle) * 34))
        color = GOLD if index % 2 == 0 else CYAN
        draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=color)

    # Threads stretched across the open frame.
    thread_colors = [(120, 90, 52, 190), (44, 92, 96, 190), (74, 52, 104, 190)]
    for index, x in enumerate((20, 27, 34, 62, 69, 76)):
        color = thread_colors[index % 3]
        top = 16 + (index * 3) % 8
        draw.rectangle((x, top, x, 30), fill=color)
        draw.rectangle((x, 66, x, 82 - (index % 3) * 2), fill=color)

    # Core socket.  The live exposed core is drawn by loom_core.gd on top.
    draw.rectangle((31, 31, 65, 65), fill=INK)
    draw.rectangle((33, 33, 63, 63), fill=(20, 10, 30, 255))
    ring(draw, 48, 48, 17, (78, 46, 108, 255), 2)
    # A narrow slit, one pixel wider on the second frame.
    slit = 5 if frame == 0 else 6
    draw.rectangle((46, 38, 49, 58), fill=(60, 36, 86, 255))
    draw.rectangle((47, 39, 48, 39 + slit), fill=(126, 92, 170, 255))
    # Small thread knots at the four diagonal inner corners.
    for dx, dy in ((-14, -14), (14, -14), (-14, 14), (14, 14)):
        draw.rectangle((48 + dx - 1, 48 + dy - 1, 48 + dx + 1, 48 + dy + 1), fill=PURPLE_DARK)
    # Tiny dust caught on the frame.
    for dx, dy in ((-38, 26), (38, -30), (-26, 38), (30, 38)):
        draw.point((48 + dx, 48 + dy), fill=(150, 120, 190, 140))
    return image


def make_boss() -> None:
    frames = [make_boss_frame(0), make_boss_frame(1)]
    strip = Image.new("RGBA", (192, 96), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.paste(frame, (index * 96, 0))
    strip.save(os.path.join(SPRITES, "loom_boss_96x96_2f.png"))


def make_node_frame(frame: int) -> Image.Image:
    image = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    disc(draw, 12, 12, 10, INK)
    disc(draw, 12, 12, 9, GRAY)
    disc(draw, 12, 12, 6, WHITE)
    # Four sockets on the ring; the frame rotates them by one step.
    for index in range(4):
        angle = index * math.tau / 4.0 + (math.pi / 4.0 if frame else 0.0)
        x = int(round(12 + math.cos(angle) * 7.5))
        y = int(round(12 + math.sin(angle) * 7.5))
        draw.rectangle((x - 1, y - 1, x, y), fill=(64, 64, 64, 255))
    # Bright core cross, constant so the centre reads at 1x.
    draw.rectangle((10, 10, 13, 13), fill=WHITE)
    draw.rectangle((11, 9, 12, 14), fill=(245, 245, 245, 255))
    draw.rectangle((9, 11, 14, 12), fill=(245, 245, 245, 255))
    # One dark pixel in the middle keeps the bright core from blooming.
    draw.point((11, 11), fill=(40, 40, 40, 255))
    draw.point((12, 12), fill=(40, 40, 40, 255))
    return image


def make_nodes() -> None:
    strip = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    for index in range(2):
        strip.paste(make_node_frame(index), (index * 24, 0))
    strip.save(os.path.join(SPRITES, "loom_node_24x24_2f.png"))


def make_bullet_frame(frame: int) -> Image.Image:
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    disc(draw, 3.5, 3.5, 3.6, INK)
    disc(draw, 3.5, 3.5, 2.8, PURPLE)
    draw.rectangle((3, 3, 4, 4), fill=WHITE)
    if frame == 0:
        draw.point((3, 3), fill=(200, 170, 255, 255))
    else:
        draw.rectangle((2, 3, 3, 4), fill=(232, 220, 255, 255))
        draw.rectangle((4, 2, 5, 3), fill=(232, 220, 255, 255))
    draw.point((2, 2), fill=(90, 50, 140, 255))
    return image


def make_bullets() -> None:
    strip = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
    for index in range(2):
        strip.paste(make_bullet_frame(index), (index * 8, 0))
    strip.save(os.path.join(SPRITES, "loom_bullet_8x8_2f.png"))


def make_wisp_frame(frame: int) -> Image.Image:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Body: a rounded purple mass with a big readable eye.
    disc(draw, 8, 8, 6.2, INK)
    disc(draw, 8, 8, 5.4, (112, 58, 170, 255))
    disc(draw, 7, 7, 4.4, (150, 84, 214, 255))
    # Three trailing tendrils, phase-shifted per frame.
    sway = (0, 1, 2, 1)[frame]
    for index, bx in enumerate((4, 8, 12)):
        x = bx
        for step in range(4):
            y = 12 + step
            if y > 15:
                break
            xx = x + (sway if (step + index) % 2 == 0 else -sway) // 2
            draw.point((max(0, min(15, xx)), y), fill=(94, 46, 148, 210))
    # Eye: white 5x5 with a 2x2 dark pupil; the single strongest read point.
    draw.rectangle((5, 4, 10, 9), fill=WHITE)
    draw.rectangle((6, 5, 9, 8), fill=(238, 238, 250, 255))
    draw.rectangle((7, 6, 8, 7), fill=(26, 10, 40, 255))
    draw.point((6, 5), fill=(200, 200, 220, 255))
    # Small purple spark above the body.
    spark_y = 1 if frame % 2 == 0 else 2
    draw.rectangle((8, spark_y, 9, spark_y + 1), fill=(196, 150, 255, 220))
    return image


def make_wisps() -> None:
    strip = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for index in range(4):
        strip.paste(make_wisp_frame(index), (index * 16, 0))
    strip.save(os.path.join(SPRITES, "loom_wisp_16x16_4f.png"))


def make_overlay() -> None:
    width, height = 960, 360
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    core_x, core_y = 700, 258

    # Soft vertical curtain at the top, built from hard 1 px rows.
    for y in range(0, 76):
        alpha = int(round(86.0 * (1.0 - y / 76.0)))
        if alpha > 0:
            draw.rectangle((0, y, width - 1, y), fill=(22, 10, 34, alpha))
    # Floor shadow.
    for y in range(294, height):
        alpha = int(round(46.0 + 52.0 * (y - 294) / 66.0))
        draw.rectangle((0, y, width - 1, y), fill=(12, 6, 20, alpha))
    # Side vignette, 1 px columns.
    for x in range(0, 88):
        alpha = int(round(70.0 * (1.0 - x / 88.0)))
        draw.rectangle((x, 0, x, height - 1), fill=(16, 8, 26, alpha))
    for x in range(width - 88, width):
        alpha = int(round(70.0 * (88.0 - (width - x)) / 88.0))
        draw.rectangle((x, 0, x, height - 1), fill=(16, 8, 26, alpha))

    # Big loom silhouette behind the boss: hard 1 px circles and a frame.
    ring(draw, core_x, core_y, 132, (26, 13, 42, 74), 2)
    ring(draw, core_x, core_y, 112, (46, 24, 70, 58), 1)
    draw.rectangle((core_x - 154, 92, core_x + 154, 94), fill=(24, 12, 38, 76))
    draw.rectangle((core_x - 154, 302, core_x + 154, 304), fill=(24, 12, 38, 76))
    draw.rectangle((core_x - 156, 92, core_x - 153, 304), fill=(24, 12, 38, 64))
    draw.rectangle((core_x + 153, 92, core_x + 156, 304), fill=(24, 12, 38, 64))
    # Two inner rails of the loom bay.
    draw.rectangle((core_x - 120, 108, core_x - 119, 300), fill=(34, 18, 50, 46))
    draw.rectangle((core_x + 119, 108, core_x + 120, 300), fill=(34, 18, 50, 46))

    # Warp threads: quiet vertical lines, a few polarity-coloured ones.
    random.seed(13)
    for index, x in enumerate(range(core_x - 144, core_x + 145, 12)):
        alpha = random.randint(16, 28)
        draw.rectangle((x, 40, x, 300), fill=(34, 18, 54, alpha))
        if index % 6 == 2:
            draw.rectangle((x, 116, x, 292), fill=(74, 50, 104, 34))
        if index % 9 == 4:
            draw.rectangle((x, 128, x, 286), fill=(52, 112, 112, 32))
            draw.rectangle((x, 176, x, 284), fill=(112, 92, 52, 26))
    # Diagonal weft, very low contrast, only across the loom bay.
    for y in range(112, 300, 8):
        for x in range(core_x - 144, core_x + 145, 3):
            if (x + y) % 2 == 0:
                draw.point((x, y), fill=(32, 17, 52, 14))
    # A handful of caught motes, not a glow field.
    for _ in range(26):
        x = random.randint(core_x - 130, core_x + 130)
        y = random.randint(70, 300)
        color = random.choice([(126, 98, 168, 50), (72, 116, 116, 46), (120, 94, 54, 44)])
        draw.point((x, y), fill=color)
    image.save(os.path.join(ASSETS, "loom_bg_overlay_960x360.png"))


# ---------------------------------------------------------------------------
# audio
# ---------------------------------------------------------------------------

SAMPLE_RATE = 44100


def envelope(t: float, duration: float, attack: float, release: float) -> float:
    if t < attack:
        return t / max(attack, 1e-6)
    if t > duration - release:
        return max(0.0, (duration - t) / max(release, 1e-6))
    return 1.0


def tone(
    freq: float,
    duration: float,
    volume: float = 0.5,
    attack: float = 0.005,
    release: float = 0.08,
    shape: str = "sine",
    sweep_to: float | None = None,
    wobble: float = 0.0,
) -> list[float]:
    count = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    phase = 0.0
    for index in range(count):
        t = index / SAMPLE_RATE
        f = freq
        if sweep_to is not None:
            f = freq + (sweep_to - freq) * (t / max(duration, 1e-6))
        if wobble:
            f += math.sin(t * 37.0) * wobble
        phase += math.tau * f / SAMPLE_RATE
        if shape == "square":
            value = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif shape == "saw":
            value = 2.0 * ((phase / math.tau) % 1.0) - 1.0
        elif shape == "triangle":
            value = 2.0 * abs(2.0 * ((phase / math.tau) % 1.0) - 1.0) - 1.0
        else:
            value = math.sin(phase)
        samples.append(value * volume * envelope(t, duration, attack, release))
    return samples


def noise(
    duration: float,
    volume: float = 0.25,
    attack: float = 0.002,
    release: float = 0.1,
    seed: int = 7,
    brightness: float = 0.0,
) -> list[float]:
    rng = random.Random(seed)
    count = int(SAMPLE_RATE * duration)
    samples: list[float] = []
    previous = 0.0
    for index in range(count):
        t = index / SAMPLE_RATE
        value = rng.uniform(-1.0, 1.0)
        # A simple 1-pole low-pass: brightness 0 = dark, 1 = raw.
        previous = previous * (0.92 - brightness * 0.6) + value * (0.08 + brightness * 0.6)
        samples.append(previous * volume * envelope(t, duration, attack, release))
    return samples


def mix(*tracks: tuple[list[float], float]) -> list[float]:
    length = max((len(track) for track, _ in tracks), default=0)
    output = [0.0] * length
    for track, gain in tracks:
        for index, value in enumerate(track):
            output[index] += value * gain
    return output


def normalize(samples: list[float], peak_db: float = -3.0) -> list[float]:
    peak = max((abs(value) for value in samples), default=0.0)
    if peak <= 1e-9:
        return samples
    target = 10.0 ** (peak_db / 20.0)
    scale = target / peak
    return [value * scale for value in samples]


def write_wav(name: str, samples: list[float], peak_db: float = -3.0) -> None:
    samples = normalize(samples, peak_db)
    path = os.path.join(AUDIO, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for value in samples:
            clipped = max(-1.0, min(1.0, value))
            frames += struct.pack("<h", int(round(clipped * 32767.0)))
        handle.writeframes(bytes(frames))
    print("wav", name, "%.3fs" % (len(samples) / SAMPLE_RATE))


def make_audio() -> None:
    write_wav(
        "sfx_node_hit.wav",
        mix(
            (tone(880, 0.18, 0.6, shape="square", sweep_to=520), 0.7),
            (noise(0.12, 0.5, brightness=0.5, seed=2), 0.5),
        ),
    )
    write_wav(
        "sfx_node_break.wav",
        mix(
            (tone(330, 0.52, 0.5, shape="triangle", sweep_to=90), 0.8),
            (noise(0.46, 0.55, brightness=0.3, seed=5, release=0.38), 0.7),
            (tone(1240, 0.16, 0.25, shape="square", sweep_to=620), 0.3),
        ),
    )
    write_wav(
        "sfx_core_hit.wav",
        mix(
            (tone(196, 0.3, 0.7, shape="saw", sweep_to=98), 0.7),
            (tone(392, 0.22, 0.4, shape="triangle", sweep_to=196), 0.4),
            (noise(0.2, 0.4, brightness=0.25, seed=9), 0.4),
        ),
    )
    write_wav(
        "sfx_core_exposed.wav",
        mix(
            (tone(220, 0.75, 0.5, shape="sine", sweep_to=660), 0.8),
            (tone(330, 0.75, 0.35, shape="triangle", sweep_to=990), 0.5),
            (noise(0.7, 0.22, brightness=0.1, seed=11, release=0.5), 0.3),
        ),
    )
    write_wav(
        "sfx_deny.wav",
        mix(
            (tone(150, 0.16, 0.5, shape="square", sweep_to=110), 0.6),
            (noise(0.1, 0.3, brightness=0.2, seed=4), 0.3),
        ),
    )
    write_wav(
        "sfx_telegraph.wav",
        mix(
            (tone(300, 0.5, 0.35, shape="triangle", sweep_to=600, release=0.12), 0.6),
            (tone(450, 0.5, 0.18, shape="sine", sweep_to=900, release=0.12), 0.4),
        ),
    )
    write_wav(
        "sfx_sweep.wav",
        mix(
            (tone(140, 0.6, 0.4, shape="saw", sweep_to=70), 0.6),
            (noise(0.55, 0.45, brightness=0.55, seed=15, release=0.35), 0.6),
        ),
    )
    write_wav(
        "sfx_summon.wav",
        mix(
            (tone(180, 0.5, 0.35, shape="sine", sweep_to=520, wobble=24.0), 0.6),
            (tone(270, 0.45, 0.2, shape="triangle", sweep_to=780, wobble=18.0), 0.4),
            (noise(0.35, 0.18, brightness=0.05, seed=21), 0.3),
        ),
    )
    write_wav(
        "sfx_stage.wav",
        mix(
            (tone(110, 0.85, 0.5, shape="triangle", sweep_to=220), 0.7),
            (tone(220, 0.85, 0.3, shape="sine", sweep_to=440), 0.5),
            (noise(0.8, 0.3, brightness=0.2, seed=33, release=0.6), 0.4),
        ),
    )
    write_wav(
        "sfx_complete.wav",
        mix(
            (tone(523.25, 1.8, 0.4, shape="sine", release=0.7), 0.5),
            (tone(659.25, 1.8, 0.32, shape="sine", release=0.7), 0.4),
            (tone(783.99, 1.8, 0.26, shape="sine", release=0.7), 0.35),
            (tone(1046.5, 1.8, 0.16, shape="triangle", release=0.9), 0.2),
        ),
    )


def main() -> None:
    ensure_dirs()
    make_boss()
    make_nodes()
    make_bullets()
    make_wisps()
    make_overlay()
    make_audio()
    print("STAR_LOOM_ASSETS_DONE", ASSETS)


if __name__ == "__main__":
    main()
