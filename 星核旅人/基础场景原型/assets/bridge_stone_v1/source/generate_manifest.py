"""Write atlas_manifest.json and source_manifest.json from the actual files."""
from __future__ import annotations

import glob
import hashlib
import json
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


def mod_role(name):
    if name.startswith("deck_top_"):
        return "路面板顶面；无竖缝，横向平铺后裁最后一块；最上行保持不透明"
    if name.startswith("deck_face_"):
        return "路面 7 px 前脸；无竖缝，横向平铺/裁切；底部由构建器加 1 px 倒角与檐下阴影"
    if name.startswith("beam_face_"):
        return "梁上部受光面 8 px；横向平铺/裁切；用于 deck kind"
    if name.startswith("beam_lower_"):
        return "梁下部较暗承重面 9 px；横向平铺，底部裁切；与上部之间加阴影缝"
    if name.startswith("soffit_"):
        return "梁底/檐下 2–3 px 实色阴影；横向平铺"
    if name.startswith("block_"):
        return "承重砌石 80×20；只拥有左侧+底部 1 px 灰缝；宽度从右侧裁，高度<20 从底部裁"
    if name.startswith("base_"):
        return "底缘承重层 10 px；拥有顶缝+左缝；横向平铺/裁切；最后一行水平接地"
    if name.startswith("pier_cap_"):
        return "8 px 支承顶帽 3 px；顶行满宽，底部 1 px 檐下阴影"
    if name.startswith("pier_drum_"):
        return "8 px 支承鼓石 12 px；左亮右暗、横向鼓石缝；竖向平铺，底部裁切"
    if name.startswith("pier_base_"):
        return "8 px 支承底座 6 px；顶凿边、底接触行"
    if name.startswith("break_core_"):
        return "24×40 实心断口内芯；竖向 40 px 平铺并轮换 a/b/c；构建器仅清外侧 1–4 px"
    if name.startswith(("damp_", "crack_", "chip_", "weather_")):
        return "透明风化贴片；不参与几何"
    return ""


def main():
    modules = []
    for name, (x, y, w, h) in L.MODULES.items():
        modules.append({
            "name": name,
            "rect": [x, y, w, h],
            "size": [w, h],
            "role": mod_role(name),
            "connection": (
                "tile horizontally; crop the last module; no scale"
                if name.startswith(("deck_", "beam_", "soffit_", "base_"))
                else ("tile vertically; crop the last drum; no scale"
                      if name.startswith(("pier_", "break_core_"))
                      else ("place transparent decal; no scale"
                            if name.startswith(("damp_", "crack_", "chip_", "weather_"))
                            else "place flush; crop from right/bottom; no scale"))
            ),
        })
    atlas = Image.open(os.path.join(HERE, "atlas.png")).convert("RGBA")
    atlas_manifest = {
        "version": "bridge_stone_v1_source_20261113",
        "status": "formal source; engineering integrates into generated/; no scenes/scripts changed here",
        "atlas": {
            "file": "atlas.png",
            "size": list(atlas.size),
            "pixel_filter": "nearest",
            "scale": "1 source px = 1 world unit",
            "sha256": sha(os.path.join(HERE, "atlas.png")),
        },
        "palette": {k: list(v) for k, v in L.PALETTE.items()},
        "modules": modules,
        "builder": {
            "file": "build_block.py",
            "cli": "python build_block.py --width W --height H --kind ground|deck|pier --left solid|broken --right solid|broken --output ABSOLUTE_PATH",
            "python": r"D:\minic\envs\2024212971\python.exe",
            "ranges": {
                "ground": "width >= 32, height >= 32",
                "deck": "width >= 8, 6 <= height <= 24",
                "pier": "width >= 8, height >= 24",
            },
            "output": "RGBA PNG exactly W x H; native pixels; no scaling; top row opaque across W",
        },
        "structure": {
            "ground": "12 px road deck + 2 px under-eave shadow + 20 px-ish bearing courses + 10 px base; high=6 courses, 64 px bank=2",
            "deck": "continuous stone beam; 6–24 px tall; top strip 2–3 px, lit face, darker lower beam body, 2–3 px soffit; not a squashed 15 px road",
            "pier": "vertical support; 3 px cap + drum stack + 6 px base; 8 px modules for W=8; wider piers use continuous same-palette sides in builder",
            "break": "top strip always full width; only below the strip retreats 1–4 px (ground 1–4, deck 1–2, pier 1); no interior holes, no fake steps. Atlas 24x40 cores serve ground; deck/pier fractures are builder-drawn from the same palette to fit their height range without stretching.",
        },
        "shadow_model": {
            "road": "TOP/TOPHI top, LIGHT/LIGHT2 face; bright but not white",
            "eave": "2 px explicit DEEP+DARK band under the deck",
            "bearing": "discrete course tones MID2 -> MID -> MIDD -> BEAR -> BEAR2, with local LIGHT/LIT stones",
            "base": "BEAR2/BEAR + DEEP contact row",
            "break": "MID2/MID/MIDD/BEAR core chunks, DEEP inner crack, 1–2 LIGHT catches; no uniform dark strip",
            "rule": "no linear transparent black overlay and no global modulate; all shadows are painted stone/joint/underside pixels",
        },
    }
    with open(os.path.join(HERE, "atlas_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(atlas_manifest, f, ensure_ascii=False, indent=2)

    files = {}
    for p in [os.path.join(HERE, "atlas.png"), os.path.join(HERE, "contact_sheet.png")] + \
             sorted(glob.glob(os.path.join(HERE, "examples", "*.png"))):
        im = Image.open(p).convert("RGBA")
        rel = os.path.relpath(p, HERE).replace("\\", "/")
        files[rel] = {
            "path": "assets/bridge_stone_v1/source/" + rel,
            "size": [im.width, im.height],
            "alpha_bbox": list(im.getbbox()),
            "sha256": sha(p),
        }

    cols = {}
    for name in ("doric_column_tall_basesquare.png", "doric_column_broken_basesquare.png", "doric_column_base_basesquare.png"):
        p = os.path.abspath(os.path.join(HERE, "..", "columns", name))
        im = Image.open(p).convert("RGBA")
        cols[name] = {
            "path": "assets/bridge_stone_v1/columns/" + name,
            "import_sidecar": (
                "assets/bridge_stone_v1/columns/" + name + ".import"
                if os.path.exists(p + ".import") else None
            ),
            "import_sidecar_sha256": (
                sha(p + ".import") if os.path.exists(p + ".import") else None
            ),
            "size": [im.width, im.height],
            "alpha_bbox": list(im.getbbox()),
            "sha256": sha(p),
            "modified_rows": (
                [99, 107] if "tall" in name else ([73, 81] if "broken" in name else [15, 23])
            ),
            "foot_anchor": [26, im.height],
            "bottom_contact": "flat x9..42, DEEP/DARK row, not black",
        }

    source_inputs = {}
    for n in ("doric_column_tall.png", "doric_column_broken.png", "doric_column_base.png", "doric_column_fallen.png"):
        p = os.path.join(ROOT, "assets", "doric_columns", n)
        im = Image.open(p).convert("RGBA")
        source_inputs[n] = {
            "path": "assets/doric_columns/" + n,
            "size": [im.width, im.height],
            "sha256": sha(p),
            "use": "derived base" if "fallen" not in n else "not touched",
        }

    source_manifest = {
        "version": "bridge_stone_v1_source_20261113",
        "status": "formal source only; engineering owns assets/bridge_stone_v1/generated/ and formal scenes/scripts",
        "ownership": {
            "this_round_writes": [
                "assets/bridge_stone_v1/source/",
                "assets/bridge_stone_v1/columns/",
            ],
            "read_only": [
                "previews/bridge_ground_sample_20261113/",
                "assets/doric_columns/",
                "scenes/", "scripts/", "docs/", "progress/", "credits", "project.godot",
            ],
        },
        "files": files,
        "code": {
            name: sha(os.path.join(HERE, name))
            for name in ("build_block.py", "layout.py", "generate_atlas.py",
                         "build_examples.py", "generate_contact_sheet.py",
                         "generate_manifest.py", "generate_all.py",
                         "validate_outputs.py")
        },
        "columns": cols,
        "source_inputs": source_inputs,
        "licensing": "All atlas/source art and code are project-original, drawn offline with Pillow. No downloads, paid image services, or external images. Column sources are project assets; only the bottom 9 rows of the derived copies differ.",
        "inspection": {
            "viewed_1x": "high 336x144, long 512x64, examples",
            "viewed_2x_4x": "high shadow/break, beam 56x8/56x24, pier 8x36, broken ends, min sizes",
            "columns": "2x full and 6x bottom crops",
            "godot": "not placed in a scene or run; no in-engine capture. The project editor may have generated .import sidecars for columns/; no scenes or scripts were edited.",
        },
        "known_limits": [
            "Break ends are deliberately conservative: 1–4 px retreat below a full-width top strip; they read as chipped/sheared edges, not large collapsed sections.",
            "Atlas 24x40 break cores are ground-specific; deck and pier fractures are drawn by the builder from the same palette so they fit 6–24 px beams and 8 px piers without stretching.",
            "HighPlatform left at world 864 and FarBank right at 1952 are off the fixed L1 camera. For later camera/level extension, generate the adjacent block with the same CLI; do not stretch the 336/496 examples.",
            "Coordinator correction: the dark shape left of the far bank belongs to the DS03 background, not an old foreground terrain wedge. Do not hide or modify DS03 to remove it; the formal terrain drawing stays inside its collision rectangles.",
            "The 336x144 example uses a broken right end; the 512x64 long foundation is solid both. Other sizes are generated by the same CLI.",
            "Pier widths >8 use continuous same-palette sides in the builder; the 8 px atlas modules are exact for W=8. No horizontal stretching.",
            "No slopes, arches, stairs, or a second biome in this source. DS03 background and all character art are untouched.",
            "Real Godot import, nearest filtering, z-order, camera framing, and foot placement at a broken edge remain unverified.",
            "The 8 px pier uses 3–4 horizontal drum joints at 36 px height; at 1x it reads as a stacked support. If a smoother monolith is wanted, reduce drum joints in a second approved pass.",
        ],
        "integration_contract": {
            "generated_dir": "assets/bridge_stone_v1/generated/ is engineering-owned; this source never writes there",
            "usage": "engineering reads source/atlas + manifest, or calls the CLI for exact collision PNGs; no scale/rotation/mirror",
            "top_edge": "row 0 is opaque across the full W; collision top edge is therefore visually supported",
            "columns": "replace the three doric_column textures with columns/*_basesquare.png; same canvas, foot_anchor and scene offsets",
        },
    }
    with open(os.path.join(HERE, "source_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(source_manifest, f, ensure_ascii=False, indent=2)
    print("wrote atlas_manifest.json, source_manifest.json; modules", len(L.MODULES))


if __name__ == "__main__":
    main()
