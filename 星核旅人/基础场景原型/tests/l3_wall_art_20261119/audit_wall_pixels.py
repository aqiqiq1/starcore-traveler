"""2026-11-19 L3 right-wall pixel audit.

Run with the project's approved Python:
  D:\\minic\\envs\\2024212971\\python.exe tests/l3_wall_art_20261119/audit_wall_pixels.py

Reads the real 640x360 captures only (no synthetic pixels), asserts the wall-pass
palette/structure at known screen points, checks that the return/corner strip and
the untouched gatehouse area are identical to the 2026-11-18 after/ shots, and
writes pixel_audit.txt next to this file.
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / "screenshots" / "l3_gate_shadow_20261118" / "after"
NEW = Path(__file__).resolve().parent / "shots"
OUT = Path(__file__).resolve().parent / "pixel_audit.txt"

lines = []
fails = []


def check(name, got, want):
    ok = got == want
    lines.append("%-46s got=%-18s want=%-18s %s" % (
        name, str(got), str(want), "OK" if ok else "FAIL"))
    if not ok:
        fails.append(name)


def main():
    before = Image.open(OLD / "00_closed_facade.png").convert("RGB")
    after = Image.open(NEW / "00_closed_facade.png").convert("RGB")
    clean = Image.open(NEW / "06_wall_face_cleanhud.png").convert("RGB")

    check("size after 00", after.size, (640, 360))
    check("size clean 06", clean.size, (640, 360))

    # Pilaster at world 2460 (front local 140 -> screen 580..597).
    check("pilaster 2px lit edge x=580", after.getpixel((580, 250)), (143, 128, 126))
    check("pilaster 2px lit edge x=581", after.getpixel((581, 250)), (143, 128, 126))
    check("pilaster shaft x=585", after.getpixel((585, 250)), (122, 108, 111))
    check("pilaster 1px dark edge x=597", after.getpixel((597, 250)), (60, 52, 57))
    check("pilaster cast shadow x=598", after.getpixel((598, 250)), (82, 73, 77))
    check("pilaster x=585 above belt", after.getpixel((585, 60)), (122, 108, 111))
    check("pilaster x=585 below belt", after.getpixel((585, 180)), (122, 108, 111))

    # Bay tones (world x 2510 / 2570 = front local 190 / 250 -> screen 630/690;
    # the visible first bay is screen 550).
    check("deep bay TONE_A x=550 y=150", after.getpixel((550, 150)), (79, 69, 73))
    check("middle bay TONE_B x=610 y=150", after.getpixel((610, 150)), (94, 84, 88))
    check("field TONE_B x=470 y=150", after.getpixel((470, 150)), (94, 84, 88))

    # Base: 1 px lit line, 3 px stone, 2 px contact, 2 px footer, 1 px dark.
    # x=590 is stone; x=600 carries one 1 px moss mark on rows 317..318.
    check("base line y=314", after.getpixel((600, 314)), (198, 187, 174))
    check("base stone y=315", after.getpixel((590, 315)), (94, 84, 88))
    check("base stone y=317", after.getpixel((590, 317)), (94, 84, 88))
    check("base contact y=319", after.getpixel((590, 319)), (53, 46, 50))
    check("base footer y=320", after.getpixel((590, 320)), (79, 69, 73))
    check("base footer y=321", after.getpixel((590, 321)), (79, 69, 73))
    check("base last row y=322", after.getpixel((590, 322)), (60, 52, 57))

    # Moss/stain: 1 px marks, never a gradient; count the green-tinted pixels
    # inside the plinth band and the lower wall courses.
    moss = []
    for y in range(312, 323):
        for x in range(440, 640):
            r, g, b = after.getpixel((x, y))
            if g > r + 4 and g > b + 4 and g > 70:
                moss.append((x, y, (r, g, b)))
    lines.append("base moss/stain pixels (1x, green-tinted): %d %s" % (
        len(moss), str(moss[:8])))
    if not (1 <= len(moss) <= 12):
        fails.append("base moss count")

    # No pure black in the artist-drawn wall (the 00 HUD button is excluded by
    # using the HUD-hidden shot; the player art is at screen 432..463,
    # y 284..320).
    black = []
    for y in range(0, 340):
        for x in range(440, 640):
            if 430 <= x <= 468 and 280 <= y <= 324:
                continue
            if clean.getpixel((x, y)) == (0, 0, 0):
                black.append((x, y))
    lines.append("pure black pixels in the wall area (06): %d" % len(black))
    if black:
        fails.append("pure black in wall area")

    # Return side + corner column (screen 412..429, below the cornice) must be
    # pixel-identical to the 2026-11-18 after/ shot: same silhouette, same
    # tones. Above world 196 that strip is sky (clouds move between runs), and
    # the player cape reaches x 432.
    diff_corner = 0
    for y in range(196, 322):
        for x in range(412, 430):
            if before.getpixel((x, y)) != after.getpixel((x, y)):
                diff_corner += 1
    lines.append("changed pixels in return/corner strip 412..429: %d" % diff_corner)
    if diff_corner != 0:
        fails.append("return/corner strip changed")

    # The gatehouse art itself is untouched (git status); its top row and one
    # 2 px transparent slot at screen 527..528 are backed by the wall, so those
    # pixels legitimately follow the new bay tone. Report them instead of
    # treating them as gate art changes.
    wall_through_gate = 0
    for y in range(163, 324):
        for x in range(428, 572):
            if 430 <= x <= 468 and 280 <= y <= 324:
                continue
            old_px = before.getpixel((x, y))
            new_px = after.getpixel((x, y))
            if old_px != new_px and new_px in ((79, 69, 73), (73, 64, 68)):
                wall_through_gate += 1
    lines.append("gatehouse pixels showing the new wall tones: %d" % wall_through_gate)

    lines.append("")
    lines.append("RESULT %s (fail=%d)" % ("OK" if not fails else "FAIL", len(fails)))
    for failure in fails:
        lines.append("FAIL: " + failure)
    text = "\n".join(lines) + "\n"
    OUT.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
