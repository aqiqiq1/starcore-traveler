"""Build the runtime start-menu UI textures for level 01.

Input (read-only):
  ../../自制素材/主界面概念预览_V1/main_menu_overlay_1280.png

Output (assets/menu/):
  main_menu_ui_640.png           640x360 transparent title / start / settings art
  main_menu_focus_start_640.png  focus-or-hover accent for the start entry
  main_menu_focus_settings_640.png
  settings_panel_640.png         modal shade + panel + static labels + return art
  settings_return_focus_640.png  focus-or-hover accent for the return entry

The main-menu base is the approved V1 overlay downsampled 2x with NEAREST; the
preview itself is not modified.  All text is rasterised from the project's
Fusion Pixel 12 px font at native size and integer-scaled with NEAREST, so no
system-font fallback is involved.  No background is baked into any output.

Run with the project Python environment:
  D:\\minic\\envs\\2024212971\\python.exe tools\\build_main_menu_ui.py
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parent
SOURCE = REPO / "自制素材" / "主界面概念预览_V1" / "main_menu_overlay_1280.png"
FONT_PATH = PROJECT / "assets" / "fonts" / "tutorial_zh.ttf"
OUT_DIR = PROJECT / "assets" / "menu"

W, H = 640, 360

IVORY = (240, 245, 236)
IVORY_SOFT = (222, 236, 230)
PALE_CYAN = (182, 214, 210)
DARK_TEAL = (20, 52, 62)
GOLD = (203, 164, 94)
SHADE = (6, 14, 18, 76)

FONT_SIZE = 12

# Approved V1 geometry (640x360 logical).
TITLE_BOX = (249, 84, 390, 117)
RULE_BOX = (296, 127, 344, 128)
START_BOX = (256, 138, 384, 174)
SETTINGS_BOX = (302, 188, 338, 200)

# Settings modal geometry, centred on x=320.  The panel was made taller to
# hold the window/fullscreen and resolution controls without a popup that could
# be clipped by other rows.
PANEL = (150, 26, 490, 334)
RETURN_BOX = (324, 262, 468, 286)

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


def draw_text(
    base: Image.Image,
    text: str,
    xy: tuple[int, int],
    scale: int,
    color: tuple[int, int, int],
    alpha: int = 255,
    shadow: tuple[tuple[int, int], tuple[int, int, int], int] | None = None,
) -> None:
    mask = native_text(text)
    if scale != 1:
        mask = mask.resize((mask.width * scale, mask.height * scale), Image.NEAREST)
    if shadow is not None:
        (dx, dy), scol, salpha = shadow
        base.alpha_composite(colored(mask, scol, salpha), (xy[0] + dx * scale, xy[1] + dy * scale))
    base.alpha_composite(colored(mask, color, alpha), xy)


def chamfer_mask(w: int, h: int, cut: int) -> Image.Image:
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


def stone_button(w: int, h: int, cut: int = 4) -> Image.Image:
    btn = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rim = Image.new("RGBA", (w, h), IVORY + (185,))
    btn.paste(rim, (0, 0), chamfer_mask(w, h, cut))
    face = Image.new("RGBA", (w - 2, h - 2), DARK_TEAL + (224,))
    btn.paste(face, (1, 1), chamfer_mask(w - 2, h - 2, max(0, cut - 1)))
    ring_mask = chamfer_ring(w - 8, h - 8, max(0, cut - 2))
    ring = Image.new("RGBA", ring_mask.size, GOLD + (190,))
    btn.paste(ring, (4, 4), ring_mask)
    return btn


def build_base() -> Image.Image:
    overlay = Image.open(SOURCE).convert("RGBA")
    if overlay.size != (W * 2, H * 2):
        raise SystemExit(f"unexpected overlay size {overlay.size}")
    base = overlay.resize((W, H), Image.NEAREST)
    # The preview must be an exact 2x NEAREST of its logical frame.
    back = base.resize((W * 2, H * 2), Image.NEAREST)
    if back.tobytes() != overlay.tobytes():
        raise SystemExit("V1 overlay is not an exact 2x NEAREST of the 640 frame")
    return base


def focus_caret(ui: Image.Image, x: int, y: int) -> None:
    for yy in range(y, y + 7):
        for xx in range(x, x + 2):
            ui.putpixel((xx, yy), PALE_CYAN + (235,))


def build_focus_start(base: Image.Image) -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Brighten the approved gold inner line without changing its geometry.
    ring_mask = chamfer_ring(128 - 8, 36 - 8, 2)
    ring = Image.new("RGBA", ring_mask.size, GOLD + (255,))
    ui.paste(ring, (START_BOX[0] + 4, START_BOX[1] + 4), ring_mask)
    focus_caret(ui, 248, 151)
    return ui


def build_focus_settings(base: Image.Image) -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    help_x, help_y = 302, 188
    draw_text(ui, "设置", (315, help_y), 1, IVORY, 255, shadow=((0, 1), (20, 45, 55), 120))
    bars = [(0, 4), (3, 7), (6, 10)]
    icon = Image.new("RGBA", (8, 10), (0, 0, 0, 0))
    for dx, bh in bars:
        for yy in range(10 - bh, 10):
            icon.putpixel((dx, yy), PALE_CYAN + (255,))
            icon.putpixel((dx + 1, yy), PALE_CYAN + (255,))
    ui.alpha_composite(icon, (help_x, 189))
    # Quiet underline closes the focus state, still inside the V1 row.
    for xx in range(help_x, help_x + 36):
        ui.putpixel((xx, 201), PALE_CYAN + (190,))
    focus_caret(ui, 293, 193)
    return ui


def build_settings_panel() -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade = Image.new("RGBA", (W, H), SHADE)
    ui.alpha_composite(shade)

    x0, y0, x1, y1 = PANEL
    w, h = x1 - x0, y1 - y0
    rim = Image.new("RGBA", (w, h), IVORY + (170,))
    ui.paste(rim, (x0, y0), chamfer_mask(w, h, 5))
    face = Image.new("RGBA", (w - 2, h - 2), DARK_TEAL + (240,))
    ui.paste(face, (x0 + 1, y0 + 1), chamfer_mask(w - 2, h - 2, 4))
    inner = chamfer_ring(w - 8, h - 8, 3)
    inner_layer = Image.new("RGBA", inner.size, GOLD + (120,))
    ui.paste(inner_layer, (x0 + 4, y0 + 4), inner)

    title = native_text("设置")
    title = title.resize((title.width * 2, title.height * 2), Image.NEAREST)
    ui.alpha_composite(colored(title, IVORY), ((W - title.width) // 2, 36))

    # Section dividers and static row labels.  Interactive buttons, the percent
    # value, the display note and status are drawn by the game at runtime.
    for divider_y in (64, 118, 252):
        for xx in range(172, 469):
            ui.putpixel((xx, divider_y), PALE_CYAN + (105,))

    draw_text(ui, "主音量", (172, 74), 1, IVORY_SOFT, 245)
    draw_text(ui, "显示模式", (172, 128), 1, IVORY_SOFT, 245)
    draw_text(ui, "窗口分辨率", (172, 156), 1, IVORY_SOFT, 245)

    # Return keeps the approved stone-slab language and is a real Button hot
    # zone with the generated focus texture on top.
    bx0, by0, bx1, by1 = RETURN_BOX
    bw, bh = bx1 - bx0, by1 - by0
    btn = stone_button(bw, bh, 3)
    ui.alpha_composite(btn, (bx0, by0))
    label = native_text("返回")
    ui.alpha_composite(
        colored(label, IVORY_SOFT, 245),
        (bx0 + (bw - label.width) // 2, by0 + (bh - label.height) // 2 + 1),
    )
    return ui


def build_return_focus() -> Image.Image:
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bx0, by0, bx1, by1 = RETURN_BOX
    bw, bh = bx1 - bx0, by1 - by0
    ring_mask = chamfer_ring(bw + 4, bh + 4, 4)
    ring = Image.new("RGBA", ring_mask.size, PALE_CYAN + (215,))
    ui.paste(ring, (bx0 - 2, by0 - 2), ring_mask)
    label = native_text("返回")
    ui.alpha_composite(
        colored(label, IVORY, 255),
        (bx0 + (bw - label.width) // 2, by0 + (bh - label.height) // 2 + 1),
    )
    return ui


def alpha_bbox_inside(base: Image.Image, box: tuple[int, int, int, int]) -> bool:
    a = base.getchannel("A")
    bbox = a.getbbox()
    return bbox is not None and bbox == box


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    base = build_base()
    focus_start = build_focus_start(base)
    focus_settings = build_focus_settings(base)
    settings = build_settings_panel()
    return_focus = build_return_focus()

    if not alpha_bbox_inside(base, (249, 84, 390, 200)):
        raise SystemExit(f"unexpected V1 UI bbox {base.getchannel('A').getbbox()}")

    # The main-menu base must be fully transparent outside the approved rows.
    a = base.getchannel("A")
    allowed = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(allowed)
    for box in (TITLE_BOX, RULE_BOX, START_BOX, SETTINGS_BOX):
        d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=255)
    outside = Image.new("L", (W, H), 0)
    outside.paste(a, (0, 0))
    outside = Image.composite(Image.new("L", (W, H), 0), outside, allowed)
    if outside.getbbox() is not None:
        raise SystemExit("main-menu base has pixels outside the approved V1 UI rows")

    outputs = {
        "main_menu_ui_640.png": base,
        "main_menu_focus_start_640.png": focus_start,
        "main_menu_focus_settings_640.png": focus_settings,
        "settings_panel_640.png": settings,
        "settings_return_focus_640.png": return_focus,
    }
    for name, image in outputs.items():
        path = OUT_DIR / name
        image.save(path)
        print(f"wrote {path}  {image.size}  sha256={sha256(path)}")

    # Rerunning this tool must never change the approved title/start/settings
    # button bytes just because the settings panel was extended.
    for name, expected in PROTECTED_OUTPUTS.items():
        actual = sha256(OUT_DIR / name)
        if actual.lower() != expected.lower():
            raise SystemExit(f"protected UI output changed: {name} {actual} != {expected}")

    print(f"source overlay: {SOURCE}")
    print(f"  sha256: {sha256(SOURCE)}")
    print(f"font: {FONT_PATH}")
    print(f"  sha256: {sha256(FONT_PATH)}")


if __name__ == "__main__":
    main()
