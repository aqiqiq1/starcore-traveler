"""Derive the 章节 title-menu plates from the approved V1 menu art.

Source assets (never modified):
  assets/menu/main_menu_ui_640.png
  assets/menu/main_menu_focus_settings_640.png
  assets/menu/main_menu_quit_640.png
  assets/menu/main_menu_focus_quit_640.png

Outputs (only the pixels needed for the reflowed title menu):
  assets/menu/main_menu_chapters_ui_640.png
  assets/menu/main_menu_chapters_focus_chapter_640.png
  assets/menu/main_menu_chapters_focus_settings_640.png
  assets/menu/main_menu_chapters_quit_640.png
  assets/menu/main_menu_chapters_focus_quit_640.png

Layout, in the 640x360 title space:
  title / underline / 开始游戏  unchanged
  章节     text 179..190, hit rect 175..195
  设置     text 198..211 (source +11), hit rect 195..215
  退出游戏 text 219..229 (source +3),  hit rect 215..235
  DLC rows unchanged at y=238 / 262 / 286

The chapter text is rasterised from the same tutorial_zh.ttf, size 12, with
the same 1 px lower-right shadow colour (20,45,55) used by the baked 设置 row.
Run with D:/minic/envs/2024212971/python.exe from the project root.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
MENU = ROOT / "assets" / "menu"
FONT = ROOT / "assets" / "fonts" / "tutorial_zh.ttf"

IVORY_SOFT = (222, 236, 230, 255)
SHADOW = (20, 45, 55, 255)


def shifted(image: Image.Image, dy: int) -> Image.Image:
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.alpha_composite(image, (0, dy))
    return out


def pixel_text(text: str, x: int, y: int, fill=IVORY_SOFT) -> Image.Image:
    """1-bit CJK text in the V1 menu's fill + lower-right shadow style.

    ``x, y`` name the visible top-left of the fill pixels (as measured from the
    baked 设置 row), not the FreeType baseline origin.
    """
    layer = Image.new("RGBA", (640, 360), (0, 0, 0, 0))
    font = ImageFont.truetype(str(FONT), 12)
    drawn = Image.new("L", (128, 48), 0)
    ImageDraw.Draw(drawn).text((0, 0), text, font=font, fill=255)
    box = drawn.getbbox()
    if box is None:
        return layer
    mask = drawn.crop(box).point(lambda value: 255 if value > 127 else 0)
    shadow = Image.new("RGBA", mask.size, SHADOW)
    ink = Image.new("RGBA", mask.size, fill)
    layer.paste(shadow, (x + 1, y + 1), mask)
    layer.paste(ink, (x, y), mask)
    return layer


def chapter_focus() -> Image.Image:
    """Caret + brighter text + cyan underline, matching the 设置 focus row."""
    layer = pixel_text("章节", 308, 179, (240, 245, 236, 255))
    draw = ImageDraw.Draw(layer)
    draw.rectangle((293, 184, 294, 190), fill=(182, 214, 210, 255))
    draw.rectangle((302, 192, 337, 192), fill=(182, 214, 210, 255))
    return layer


def main() -> None:
    base = Image.open(MENU / "main_menu_ui_640.png").convert("RGBA")
    focus_settings = Image.open(MENU / "main_menu_focus_settings_640.png").convert("RGBA")
    quit_row = Image.open(MENU / "main_menu_quit_640.png").convert("RGBA")
    focus_quit = Image.open(MENU / "main_menu_focus_quit_640.png").convert("RGBA")

    new_base = base.copy()
    # Remove the old 设置 icon + text, then re-place it 11 px lower.
    draw = ImageDraw.Draw(new_base)
    draw.rectangle((300, 183, 341, 203), fill=(0, 0, 0, 0))
    settings_crop = base.crop((300, 183, 342, 204))
    new_base.alpha_composite(settings_crop, (300, 194))
    # 章节 sits in the freed slot; no icon, centred on x=320.
    new_base.alpha_composite(pixel_text("章节", 308, 179))

    new_base.save(MENU / "main_menu_chapters_ui_640.png")
    shifted(focus_settings, 11).save(MENU / "main_menu_chapters_focus_settings_640.png")
    shifted(quit_row, 3).save(MENU / "main_menu_chapters_quit_640.png")
    shifted(focus_quit, 3).save(MENU / "main_menu_chapters_focus_quit_640.png")
    chapter_focus().save(MENU / "main_menu_chapters_focus_chapter_640.png")

    for name in (
        "main_menu_chapters_ui_640.png",
        "main_menu_chapters_focus_chapter_640.png",
        "main_menu_chapters_focus_settings_640.png",
        "main_menu_chapters_quit_640.png",
        "main_menu_chapters_focus_quit_640.png",
    ):
        with Image.open(MENU / name) as check:
            print(name, check.size, check.mode)


if __name__ == "__main__":
    main()
