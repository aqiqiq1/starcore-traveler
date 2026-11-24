"""Generate the main-menu conceptual preview for 星核旅人.

Read-only inputs:
  基础场景原型/screenshots/ds03_godot_background_only.png  (actual Godot t=0 frame)
  基础场景原型/assets/fonts/tutorial_zh.ttf               (Fusion Pixel 12px Prop zh-Hans)

Outputs (this folder):
  main_menu_preview_v1.png          1280x720, 640x360 logical frame x2 NEAREST
  main_menu_preview_v1_640.png      640x360 check image
  main_menu_overlay_1280.png        1280x720 transparent UI-only overlay (proposal only)

No gameplay code, no scene files, no background repaint.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
BG_PATH = PROJECT / "基础场景原型" / "screenshots" / "ds03_godot_background_only.png"
FONT_PATH = PROJECT / "基础场景原型" / "assets" / "fonts" / "tutorial_zh.ttf"

W, H = 640, 360
OUT_SCALE = 2

# Palette (cold daylight cloud sea + weathered ruin; gold used only as the
# selected-entry accent, pale cyan for quiet secondary marks).
IVORY = (240, 245, 236)
IVORY_SOFT = (222, 236, 230)
PALE_CYAN = (182, 214, 210)
DARK_TEAL = (20, 52, 62)
GOLD = (203, 164, 94)

FONT_SIZE = 12  # native pixel size of Fusion Pixel

# Layout at 640x360 logical resolution. Every element is centred on x=320.
TITLE_TOP = 84
TITLE_SCALE = 3          # 36px tall temporary wordmark
RULE_Y = 127
RULE_W = 48
BTN_X, BTN_Y, BTN_W, BTN_H = 256, 138, 128, 36
START_TEXT_SCALE = 2     # 24px
SETTINGS_Y = 188


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def native_text(text: str, spacing: int = 0) -> Image.Image:
    """Render text at the font's native 12 px, threshold to 1-bit, crop to ink.

    Per-glyph placement avoids any system fallback and keeps the advance exact.
    """
    font = ImageFont.truetype(str(FONT_PATH), FONT_SIZE)
    advances = [int(round(font.getlength(ch))) for ch in text]
    width = sum(advances) + spacing * (len(text) - 1)
    raw = Image.new("L", (width, 20), 0)
    draw = ImageDraw.Draw(raw)
    x = 0
    for ch, adv in zip(text, advances):
        draw.text((x, 0), ch, font=font, fill=255)
        x += adv + spacing
    # The font rasterises without grey edge pixels at 12 px; thresholding is a
    # hard guarantee that no antialiased fringe enters the pixel art.
    raw = raw.point(lambda v: 255 if v >= 128 else 0, mode="L")
    bbox = raw.getbbox()
    if bbox is None:
        raise RuntimeError(f"font produced no ink for: {text!r}")
    return raw.crop(bbox)


def colored(mask: Image.Image, color: tuple[int, int, int], alpha: int = 255) -> Image.Image:
    layer = Image.new("RGBA", mask.size, color + (alpha,))
    layer.putalpha(mask)
    return layer


def draw_text(
    base: Image.Image,
    text: str,
    xy: tuple[int, int],
    scale: int,
    color: tuple[int, int, int],
    alpha: int = 255,
    spacing: int = 0,
    shadow: tuple[tuple[int, int], tuple[int, int, int], int] | None = None,
) -> None:
    mask = native_text(text, spacing)
    if scale != 1:
        mask = mask.resize((mask.width * scale, mask.height * scale), Image.NEAREST)
    if shadow is not None:
        (dx, dy), scol, salpha = shadow
        sh = colored(mask, scol, salpha)
        base.alpha_composite(sh, (xy[0] + dx * scale, xy[1] + dy * scale))
    base.alpha_composite(colored(mask, color, alpha), xy)


def chamfer_mask(w: int, h: int, cut: int) -> Image.Image:
    """Hard-edged rectangle with pixel-cut corners (no rounded/anti-aliased arcs)."""
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    pts = [
        (cut, 0), (w - 1 - cut, 0), (w - 1, cut),
        (w - 1, h - 1 - cut), (w - 1 - cut, h - 1),
        (cut, h - 1), (0, h - 1 - cut), (0, cut),
    ]
    d.polygon(pts, fill=255)
    return mask


def chamfer_ring(w: int, h: int, cut: int) -> Image.Image:
    outer = chamfer_mask(w, h, cut)
    inner = chamfer_mask(w - 2, h - 2, max(0, cut - 1))
    ring = outer.copy()
    ring.paste(0, (1, 1), inner)
    return ring


def stone_button() -> Image.Image:
    w, h = BTN_W, BTN_H
    btn = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # 1 px pale stone rim
    rim = Image.new("RGBA", (w, h), IVORY + (185,))
    btn.paste(rim, (0, 0), chamfer_mask(w, h, 4))

    # dark weathered stone face
    face = Image.new("RGBA", (w - 2, h - 2), DARK_TEAL + (224,))
    btn.paste(face, (1, 1), chamfer_mask(w - 2, h - 2, 3))

    # thin gold inner line: the only gold in the menu (selected entry accent)
    ring_mask = chamfer_ring(w - 8, h - 8, 2)
    ring = Image.new("RGBA", ring_mask.size, GOLD + (190,))
    btn.paste(ring, (4, 4), ring_mask)
    return btn


def make_ui() -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Temporary wordmark: plain project pixel type, not a final logo.
    title_mask = native_text("星核旅人")
    tw = title_mask.width * TITLE_SCALE
    draw_text(ui, "星核旅人", ((W - tw) // 2, TITLE_TOP), TITLE_SCALE, IVORY)

    # Quiet rule under the title.
    rule = Image.new("RGBA", (RULE_W, 1), PALE_CYAN + (145,))
    ui.alpha_composite(rule, ((W - RULE_W) // 2, RULE_Y))

    # Primary entry.
    btn = stone_button()
    ui.alpha_composite(btn, (BTN_X, BTN_Y))
    start_mask = native_text("开始游戏")
    stw = start_mask.width * START_TEXT_SCALE
    sth = start_mask.height * START_TEXT_SCALE
    draw_text(
        ui,
        "开始游戏",
        (BTN_X + (BTN_W - stw) // 2, BTN_Y + (BTN_H - sth) // 2),
        START_TEXT_SCALE,
        IVORY,
    )

    # Secondary entry: small three-bar volume mark + quiet text, no panel.
    icon_x, icon_bottom = 302, 198
    bars = [(0, 4), (3, 7), (6, 10)]  # (dx, height)
    icon = Image.new("RGBA", (8, 10), (0, 0, 0, 0))
    for dx, bh in bars:
        for yy in range(10 - bh, 10):
            icon.putpixel((dx, yy), PALE_CYAN + (225,))
            icon.putpixel((dx + 1, yy), PALE_CYAN + (225,))
    ui.alpha_composite(icon, (icon_x, icon_bottom - 9))

    draw_text(
        ui,
        "设置",
        (315, SETTINGS_Y),
        1,
        IVORY_SOFT,
        245,
        shadow=((0, 1), (20, 45, 55), 120),
    )
    return ui


def main() -> None:
    bg = Image.open(BG_PATH).convert("RGB")
    if bg.size != (W, H):
        raise SystemExit(f"unexpected background size {bg.size}, expected {(W, H)}")
    if not FONT_PATH.exists():
        raise SystemExit(f"missing font: {FONT_PATH}")

    ui = make_ui()
    frame640 = bg.convert("RGBA")
    frame640.alpha_composite(ui)
    frame640_rgb = frame640.convert("RGB")

    main1280 = frame640_rgb.resize((W * OUT_SCALE, H * OUT_SCALE), Image.NEAREST)
    overlay1280 = ui.resize((W * OUT_SCALE, H * OUT_SCALE), Image.NEAREST)

    main_path = HERE / "main_menu_preview_v1.png"
    check640_path = HERE / "main_menu_preview_v1_640.png"
    overlay_path = HERE / "main_menu_overlay_1280.png"
    main1280.save(main_path)
    frame640_rgb.save(check640_path)
    overlay1280.save(overlay_path)

    # --- verification -----------------------------------------------------
    # 1. Every pixel outside the UI layer is byte-identical to the Godot frame.
    alpha = ui.getchannel("A")
    untouched = alpha.point(lambda v: 255 if v == 0 else 0)
    outside_cmp = Image.composite(frame640_rgb, Image.new("RGB", (W, H), (0, 0, 0)), untouched)
    bg_cmp = Image.composite(bg, Image.new("RGB", (W, H), (0, 0, 0)), untouched)
    if outside_cmp.tobytes() != bg_cmp.tobytes():
        raise SystemExit("background changed outside the UI layer")

    # 2. 1280 output is an exact NEAREST x2 of the 640 composite.
    back = main1280.resize((W, H), Image.NEAREST)
    if back.tobytes() != frame640_rgb.tobytes():
        raise SystemExit("1280 preview is not an exact 2x NEAREST of the 640 frame")

    print(f"background : {BG_PATH}")
    print(f"  sha256   : {sha256(BG_PATH)}")
    print(f"font       : {FONT_PATH}")
    print(f"  sha256   : {sha256(FONT_PATH)}")
    print(f"wrote      : {main_path}")
    print(f"wrote      : {check640_path}")
    print(f"wrote      : {overlay_path}")
    print(f"sizes      : {main1280.size}, {frame640_rgb.size}, {overlay1280.size}")
    print("verified   : background untouched outside UI; 1280 == exact 2x NEAREST of 640")


if __name__ == "__main__":
    main()
