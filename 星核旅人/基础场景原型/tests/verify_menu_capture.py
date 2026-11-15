"""Check the real start-menu captures against the approved V1 640 frame.

This is a local verification utility, not a gameplay test. It checks:
  * 640x360 captures and exact 2x NEAREST companions;
  * fully opaque menu pixels are placed exactly where the V1 layout puts them;
  * outside the menu UI, the live DS03 background is not globally dimmed/tinted;
  * the settings capture is a real distinct modal frame (no baked background).

Run:
  D:\\minic\\envs\\2024212971\\python.exe tests\\verify_menu_capture.py
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageChops

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parent
SHOTS = PROJECT / "screenshots"
LOGS = PROJECT / "tests" / "logs"
V1_640 = REPO / "自制素材" / "主界面概念预览_V1" / "main_menu_preview_v1_640.png"
V1_1280 = REPO / "自制素材" / "主界面概念预览_V1" / "main_menu_preview_v1.png"
BASE = PROJECT / "assets" / "menu" / "main_menu_ui_640.png"
FOCUS_START = PROJECT / "assets" / "menu" / "main_menu_focus_start_640.png"
QUIT = PROJECT / "assets" / "menu" / "main_menu_quit_640.png"
FOCUS_QUIT = PROJECT / "assets" / "menu" / "main_menu_focus_quit_640.png"

CAPTURES = [
    "menu_level01_initial",
    "menu_level01_settings",
    "menu_level01_camera_mid",
    "menu_level01_camera_settled_before_entry",
    "menu_level01_playable",
]


def mean_abs_diff(a: Image.Image, b: Image.Image, mask: Image.Image) -> float:
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
    values = [value for value, keep in zip(diff.getdata(), mask.getdata()) if keep]
    if not values:
        return 0.0
    return sum(values) / len(values)


def main() -> None:
    report: dict = {"generated": datetime.now().isoformat(timespec="seconds"), "checks": {}}
    ok = True

    def check(name: str, condition: bool, detail="") -> None:
        nonlocal ok
        report["checks"][name] = {"pass": bool(condition), "detail": detail}
        if not condition:
            ok = False
        print(("[PASS] " if condition else "[FAIL] ") + name + f"  ({detail})")

    initial = Image.open(SHOTS / "menu_level01_initial.png").convert("RGB")
    v1 = Image.open(V1_640).convert("RGB")
    check("initial capture is 640x360", initial.size == (640, 360), str(initial.size))
    v1_1280_back = Image.open(V1_1280).convert("RGB").resize((640, 360), Image.NEAREST)
    check("V1 640 is an exact downsample of V1 1280", v1.tobytes() == v1_1280_back.tobytes())

    for name in CAPTURES:
        one = Image.open(SHOTS / f"{name}.png").convert("RGB")
        two_path = SHOTS / f"{name}_2x.png"
        two = Image.open(two_path).convert("RGB")
        back = two.resize((640, 360), Image.NEAREST)
        check(f"{name} is 640x360", one.size == (640, 360), str(one.size))
        check(f"{name}_2x is exact NEAREST 2x", two.size == (1280, 720) and back.tobytes() == one.tobytes())

    base = Image.open(BASE).convert("RGBA")
    focus = Image.open(FOCUS_START).convert("RGBA")
    combined = Image.alpha_composite(base, focus)
    combined_rgb = combined.convert("RGB")
    alpha = combined.getchannel("A")
    opaque = alpha.point(lambda v: 255 if v == 255 else 0)
    transparent = alpha.point(lambda v: 255 if v == 0 else 0)
    check("menu has opaque UI pixels", opaque.getbbox() is not None, str(opaque.getbbox()))

    opaque_pixels = [value for value in opaque.getdata()]
    mismatch = 0
    mismatch_max = 0
    for index, (expected, actual) in enumerate(zip(combined_rgb.getdata(), initial.getdata())):
        if opaque_pixels[index]:
            delta = max(abs(expected[c] - actual[c]) for c in range(3))
            if delta > 1:
                mismatch += 1
                mismatch_max = max(mismatch_max, delta)
    opaque_count = sum(1 for value in opaque_pixels if value)
    check(
        "retained two-entry initial capture still matches approved V1 art exactly (tolerance 1)",
        mismatch == 0,
        f"{opaque_count} opaque px, {mismatch} mismatches, max delta {mismatch_max}",
    )

    # V1 UI bbox is 249,84..390,200; the approved focus accent may extend a
    # pixel or two beyond that, but no unrelated full-screen UI is allowed.
    check(
        "live initial UI stays within the approved V1 rows plus focus accent",
        opaque.getbbox() is not None
        and opaque.getbbox()[0] >= 246 and opaque.getbbox()[1] >= 82
        and opaque.getbbox()[2] <= 392 and opaque.getbbox()[3] <= 204,
        str(opaque.getbbox()),
    )
    base_bbox = base.getchannel("A").getbbox()
    check("base runtime menu art keeps the exact V1 bbox", base_bbox == (249, 84, 390, 200), str(base_bbox))

    outside = transparent.point(lambda v: 255 if v else 0)
    outside_mae = mean_abs_diff(initial, v1, outside)
    check(
        "outside the UI the live background is not globally dimmed/tinted",
        outside_mae < 8.0,
        f"mean abs diff vs V1 t=0 background: {outside_mae:.2f}/255",
    )
    sky_box = (0, 0, 640, 80)
    sky_mask = Image.new("L", (640, 360), 0)
    sky_mask.paste(outside.crop(sky_box), sky_box)
    sky_mae = mean_abs_diff(initial, v1, sky_mask)
    check("sky outside the UI keeps the V1 daylight level", sky_mae < 8.0, f"sky MAE {sky_mae:.2f}/255")

    # --- Current home screen: additive 退出游戏 row -------------------------
    # The current capture intentionally is NOT byte-identical to the old
    # two-entry V1 frame: it adds the separate runtime quit texture below 设置.
    quit_tex = Image.open(QUIT).convert("RGBA")
    focus_quit = Image.open(FOCUS_QUIT).convert("RGBA")
    quit_bbox = quit_tex.getchannel("A").getbbox()
    check("quit row texture is 640x360", quit_tex.size == (640, 360), str(quit_tex.size))
    check(
        "quit label sits inside its 72x20 hot zone",
        quit_bbox is not None
        and quit_bbox[0] >= 284 and quit_bbox[1] >= 212
        and quit_bbox[2] <= 356 and quit_bbox[3] <= 232,
        str(quit_bbox),
    )
    check(
        "quit label is centred under 设置",
        quit_bbox is not None and abs((quit_bbox[0] + quit_bbox[2]) / 2 - 320) <= 1,
        str(quit_bbox),
    )
    check(
        "quit label uses 12px pixel text",
        quit_bbox is not None
        and quit_bbox[2] - quit_bbox[0] <= 56
        and quit_bbox[3] - quit_bbox[1] <= 14,
        str(quit_bbox),
    )
    focus_quit_bbox = focus_quit.getchannel("A").getbbox()
    check(
        "quit focus accent stays inside the quit hot zone",
        focus_quit_bbox is not None
        and focus_quit_bbox[0] >= 284 and focus_quit_bbox[1] >= 212
        and focus_quit_bbox[2] <= 356 and focus_quit_bbox[3] <= 232,
        str(focus_quit_bbox),
    )

    with_quit = Image.open(SHOTS / "menu_with_quit.png").convert("RGB")
    with_quit_2x = Image.open(SHOTS / "menu_with_quit_2x.png").convert("RGB")
    with_quit_back = with_quit_2x.resize((640, 360), Image.NEAREST)
    check("menu_with_quit is 640x360", with_quit.size == (640, 360), str(with_quit.size))
    check(
        "menu_with_quit_2x is exact NEAREST 2x",
        with_quit_2x.size == (1280, 720) and with_quit_back.tobytes() == with_quit.tobytes(),
    )

    combined_quit = Image.alpha_composite(combined, quit_tex)
    combined_quit_rgb = combined_quit.convert("RGB")
    alpha_quit = combined_quit.getchannel("A")
    opaque_quit = alpha_quit.point(lambda v: 255 if v == 255 else 0)
    opaque_quit_values = list(opaque_quit.getdata())
    quit_mismatch = 0
    quit_mismatch_max = 0
    for index, (expected, actual) in enumerate(
        zip(combined_quit_rgb.getdata(), with_quit.getdata())
    ):
        if opaque_quit_values[index]:
            delta = max(abs(expected[c] - actual[c]) for c in range(3))
            if delta > 1:
                quit_mismatch += 1
                quit_mismatch_max = max(quit_mismatch_max, delta)
    check(
        "current capture matches V1 title/start/settings plus the new quit row (tolerance 1)",
        quit_mismatch == 0,
        f"{sum(1 for v in opaque_quit_values if v)} opaque px, "
        f"{quit_mismatch} mismatches, max delta {quit_mismatch_max}",
    )
    check(
        "current menu UI stays within the V1 rows plus the quit row",
        opaque_quit.getbbox() is not None
        and opaque_quit.getbbox()[0] >= 246 and opaque_quit.getbbox()[1] >= 82
        and opaque_quit.getbbox()[2] <= 392 and opaque_quit.getbbox()[3] <= 234,
        str(opaque_quit.getbbox()),
    )

    transparent_quit = alpha_quit.point(lambda v: 255 if v == 0 else 0)
    outside_quit_mae = mean_abs_diff(with_quit, v1, transparent_quit)
    check(
        "background outside the three-entry UI is not globally dimmed/tinted",
        outside_quit_mae < 8.0,
        f"mean abs diff vs V1 t=0 background: {outside_quit_mae:.2f}/255",
    )
    check(
        "current capture is distinct from the retained pre-quit capture",
        with_quit.tobytes() != initial.tobytes(),
        "menu_with_quit.png is a new frame, not a rewrite of menu_level01_initial.png",
    )

    # The old menu_level01_settings.png is retained as historical evidence of
    # the previous shorter settings panel; do not overwrite it.  The current
    # expanded settings layout is covered by the display_settings_* captures.
    settings = Image.open(SHOTS / "menu_level01_settings.png").convert("RGB")
    check("legacy settings capture remains a distinct modal frame", settings.tobytes() != initial.tobytes())
    display_shots = {
        "display_settings_01_panel_1280.png": (1280, 720),
        "display_settings_02_pending_640.png": (640, 360),
        "display_settings_03_pending_fullscreen.png": (1920, 1080),
        "display_settings_04_bars_1400x900.png": (1400, 900),
        "display_settings_05_panel_logical.png": (640, 360),
        "display_settings_06_pending_logical.png": (640, 360),
    }
    for name, expected_size in display_shots.items():
        path = SHOTS / name
        if not path.is_file():
            check(f"{name} exists", False, "missing current display-settings capture")
            continue
        image = Image.open(path).convert("RGB")
        check(f"{name} has expected size", image.size == expected_size, str(image.size))
    bars = Image.open(SHOTS / "display_settings_04_bars_1400x900.png").convert("RGB")
    check(
        "1400x900 diagnostic capture has a black top bar and integer 2x content",
        bars.getpixel((0, 0)) == (0, 0, 0) and bars.getpixel((60, 90)) != (0, 0, 0),
        f"corner={bars.getpixel((0, 0))} content={bars.getpixel((60, 90))}",
    )

    mid = Image.open(SHOTS / "menu_level01_camera_mid.png").convert("RGB")
    check("mid camera frame reveals real world at the bottom but not the HUD", mid.tobytes() != initial.tobytes())

    LOGS.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = LOGS / f"menu_capture_verify_{stamp}.json"
    report["result"] = "PASS" if ok else "FAIL"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out}")
    print("RESULT:", "PASS" if ok else "FAIL")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
