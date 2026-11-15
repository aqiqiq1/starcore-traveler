"""Build the optional 退出游戏 row for the level 01 start menu.

This is a separate, additive generator.  It does not read or rewrite the
approved two-entry V1 overlay assets, so their bytes stay untouched.  Both
outputs are fully transparent 640x360 runtime textures that are layered into
the existing StartMenu fade group at runtime.

Input (read-only):
  assets/fonts/tutorial_zh.ttf   Fusion Pixel 12px Prop zh-Hans (OFL-1.1)

Output (assets/menu/):
  main_menu_quit_640.png         muted 退出游戏 label, centred under 设置
  main_menu_focus_quit_640.png   brighter label + caret/underline focus accent

Run with the project Python environment:
  D:\\minic\\envs\\2024212971\\python.exe tools\\build_main_menu_quit.py
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[1]
FONT_PATH = PROJECT / "assets" / "fonts" / "tutorial_zh.ttf"
OUT_DIR = PROJECT / "assets" / "menu"

W, H = 640, 360
FONT_SIZE = 12

IVORY = (240, 245, 236)
PALE_CYAN = (182, 214, 210)

# Centred under the approved 设置 row.  The hot zone is intentionally smaller
# than 开始游戏 so the new entry stays visually secondary.
QUIT_BOX = (284, 212, 356, 232)
QUIT_TEXT = "退出游戏"
QUIT_TEXT_Y = 216

# The approved runtime textures must not change when this tool runs.
PROTECTED_OUTPUTS = {
    "main_menu_ui_640.png": "7c85d1f5bdfd3bb268cb653496ca1c6482b5bf278250095923c0dc3af5e0262b",
    "main_menu_focus_start_640.png": "f8493fb05ce3525c95181d744c6228ff209c41c3125c575df5b5184befed66a4",
    "main_menu_focus_settings_640.png": "36d3ec59b8ab4061d1d7a61d8e752254c0f8879c0a37214fde5f2dc54a6d36f3",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def native_text(text: str, spacing: int = 0) -> Image.Image:
    font = ImageFont.truetype(str(FONT_PATH), FONT_SIZE)
    advances = [int(round(font.getlength(ch))) for ch in text]
    width = sum(advances) + spacing * (len(text) - 1)
    raw = Image.new("L", (width, 20), 0)
    draw = ImageDraw.Draw(raw)
    x = 0
    for ch, adv in zip(text, advances):
        draw.text((x, 0), ch, font=font, fill=255)
        x += adv + spacing
    raw = raw.point(lambda v: 255 if v >= 128 else 0, mode="L")
    bbox = raw.getbbox()
    if bbox is None:
        raise RuntimeError(f"font produced no ink for: {text!r}")
    return raw.crop(bbox)


def colored(mask: Image.Image, color: tuple[int, int, int], alpha: int = 255) -> Image.Image:
    layer = Image.new("RGBA", mask.size, color + (alpha,))
    layer.putalpha(mask)
    return layer


def text_origin(mask: Image.Image) -> tuple[int, int]:
    return ((W - mask.width) // 2, QUIT_TEXT_Y)


def build_quit() -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = native_text(QUIT_TEXT)
    ui.alpha_composite(colored(mask, PALE_CYAN, 255), text_origin(mask))
    return ui


def build_focus_quit() -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = native_text(QUIT_TEXT)
    x, y = text_origin(mask)
    ui.alpha_composite(colored(mask, IVORY, 255), (x, y))
    # 2x7 caret on the left, matching the other menu focus rows.
    for yy in range(y + 3, y + 10):
        for xx in range(x - 8, x - 6):
            ui.putpixel((xx, yy), PALE_CYAN + (255,))
    # Quiet 1px underline closes the focus state inside the 20px hot zone.
    for xx in range(x, x + mask.width):
        ui.putpixel((xx, y + 13), PALE_CYAN + (205,))
    return ui


def main() -> None:
    if not FONT_PATH.is_file():
        raise SystemExit(f"missing font: {FONT_PATH}")

    quit_row = build_quit()
    focus_quit = build_focus_quit()

    for name, image in (
        ("main_menu_quit_640.png", quit_row),
        ("main_menu_focus_quit_640.png", focus_quit),
    ):
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"{name} has no ink")
        if (
            bbox[0] < QUIT_BOX[0] or bbox[1] < QUIT_BOX[1]
            or bbox[2] > QUIT_BOX[2] or bbox[3] > QUIT_BOX[3]
        ):
            raise SystemExit(f"{name} ink {bbox} escapes the quit hot zone {QUIT_BOX}")
        path = OUT_DIR / name
        image.save(path)
        print(f"wrote {path}  {image.size}  bbox={bbox}  sha256={sha256(path)}")

    label_bbox = quit_row.getchannel("A").getbbox()
    centre = (label_bbox[0] + label_bbox[2]) / 2.0
    if abs(centre - W / 2.0) > 1.0:
        raise SystemExit(f"quit label is not centred: {label_bbox}")
    if label_bbox[2] - label_bbox[0] > 56 or label_bbox[3] - label_bbox[1] > 14:
        raise SystemExit(f"quit label is not 12px pixel text: {label_bbox}")

    for name, expected in PROTECTED_OUTPUTS.items():
        actual = sha256(OUT_DIR / name)
        if actual.lower() != expected.lower():
            raise SystemExit(f"protected UI output changed: {name} {actual} != {expected}")

    print(f"font: {FONT_PATH}")
    print(f"  sha256: {sha256(FONT_PATH)}")
    print("approved two-entry menu PNGs are unchanged")


if __name__ == "__main__":
    main()
