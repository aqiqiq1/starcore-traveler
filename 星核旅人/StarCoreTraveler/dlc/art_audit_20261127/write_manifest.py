"""Write ASSET_MANIFEST_20261127.json for the DLC3 city_v2 + icon pass."""

import hashlib
import json
import os
from datetime import date

ROOT = r"D:\godot game\星核旅人\StarCoreTraveler"
OUT = os.path.join(ROOT, "dlc", "art_audit_20261127", "ASSET_MANIFEST_20261127.json")


def info(rel):
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    with open(path, "rb") as handle:
        data = handle.read()
    return {
        "path": rel,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def main():
    data = {
        "schema": "starcore-traveler/art-audit/1",
        "date": "2026-11-27",
        "scope": "Six-chapter background/foreground/terrain/window/column/brazier audit; DLC3 city interior v2; standalone UI icon set.",
        "generator": {
            "city": "dlc/star_loom/tools/gen_city_assets_v2.py",
            "method": "Pillow procedural pixel art; no external image, palette, sprite or remote service is read.",
            "command": "D:/minic/envs/2024212971/python.exe dlc/star_loom/tools/gen_city_assets_v2.py",
        },
        "runtime_outputs": [
            {**info("dlc/star_loom/assets/city_v2/city_back_960x360.png"),
             "size": "960x360", "usage": "DLC3 StarLoom CityBack (z=-10); wall, three 126x204 windows, apse, pilasters, banners, chains."},
            {**info("dlc/star_loom/assets/city_v2/city_fore_960x360.png"),
             "size": "960x360", "usage": "DLC3 CityFore (z=12); side piers + front lip, centre transparent."},
            {**info("dlc/star_loom/assets/city_v2/city_floor_960x40.png"),
             "size": "960x40", "usage": "DLC3 CityFloor; 40 px floor matching l3_terrain collision strip at y=320."},
            {**info("assets/ui/icons/affinity_sun_20.png"),
             "size": "20x20", "usage": "Standalone 辉相 badge; HUD code not changed."},
            {**info("assets/ui/icons/affinity_moon_20.png"),
             "size": "20x20", "usage": "Standalone 澜相 badge; HUD code not changed."},
            {**info("assets/ui/icons/heart_10.png"),
             "size": "10x10", "usage": "Standalone life/heart icon; HUD code not changed."},
        ],
        "preserved_sources": [
            {**info("dlc/star_loom/assets/city/city_back_960x360.png"), "note": "Original approved background, untouched."},
            {**info("dlc/star_loom/assets/city/city_fore_960x360.png"), "note": "Original approved foreground, untouched."},
            {**info("dlc/star_loom/assets/city/city_floor_960x40.png"), "note": "Original approved floor, untouched."},
            {**info("dlc/star_loom/assets/city/vent_28x12_2f.png"), "note": "Still referenced by star_loom.tscn; untouched."},
            {**info("dlc/star_loom/assets/city/brazier_28x44_2f.png"), "note": "Still referenced by loom_brazier.gd; untouched."},
        ],
        "scene_references": [
            "dlc/star_loom/star_loom.tscn: CityBack/CityFore/CityFloor -> city_v2; BrazierLeft (236,320), BrazierRight (860,320).",
            "scenes/level_03.tscn: CityGround tint Color(0.99,0.96,0.9,1) -> Color(1,0.99,0.98,1) to remove the yellow cast at the city approach.",
        ],
        "measurements": {
            "old_window_black_ratio": "17,168 / 48,526 arch-mask pixels with max(R,G,B) < 32 = 35.4%",
            "new_window_black_ratio": "0 / 71,880 arch-mask pixels with max(R,G,B) < 32 = 0.0%",
            "new_window_glass_sha256": "24536120b8b021a509a783fc8f07e02a5af81db0e6225508d8b4527ce896b76a for all three bays",
            "window_geometry": "126x204 each; x=76/264/452; 6 px stone frame; 1 px gold sill line",
            "wall_coursing": "48 px brick x 24 px course, 1 px mortar",
            "floor_layers": "8 px top slab + 4 px light joint + 4 px deep seam + 8 px channel + 16 px front face",
            "pilaster": "40 px shaft, 44 px cap/base, 262 px tall; Doric reference 52x108",
            "brazier": "28x44, bowl 24 px wide; unchanged art, positions aligned to pilaster centres",
        },
        "verification": {
            "import_log": "dlc/art_audit_20261127/logs/import.log (0 ERROR lines)",
            "smoke_log": "dlc/art_audit_20261127/logs/smoke_90f.log (6/6 SMOKE_OK, 90 process frames, 0 ERROR lines; test entry)",
            "smoke_normal_log": "dlc/art_audit_20261127/logs/smoke_90f_normal.log (6/6 SMOKE_OK, 90 process frames with intro cinematics enabled, 0 ERROR lines)",
            "capture_log": "dlc/art_audit_20261127/logs/capture_after.log (6 shots 640x360, error=0)",
            "screenshots_before": "screenshots/art_audit_20261127/before/",
            "screenshots_after": "screenshots/art_audit_20261127/after/",
        },
        "boundaries": [
            "No HUD/gameplay/cinematic code changed by this pass.",
            "No Git commit, push or export.",
            "No third-party pixels were copied into runtime assets; references/ are study-only and .gdignore'd.",
            "DLC1/DLC2 art and base-level backgrounds were audited but intentionally left unchanged; their runtime palette already matches the approved DS03/bridge_stone set.",
            "L3 gate facade was inspected at 2x: L3GateDepthWall already draws courses/joints/pilasters/niches and uses ART_FIELD (94,84,88), close to the new city stone (94,82,87). Its gameplay depth/occlusion code was not changed.",
        ],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
    print("MANIFEST", OUT)


if __name__ == "__main__":
    main()
