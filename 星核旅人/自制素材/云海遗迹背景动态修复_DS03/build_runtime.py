#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build DS03 runtime configuration and byte-identical common asset copies.

Read-only inputs:
  * this directory's art_manifest.json / art_assets (art ownership files)
  * ../云海遗迹背景动态重制_DS02/layers (DS02 dynamic layers)
  * the 108-item protected baseline in the temp audit directory

Writes only:
  * common/*.png (byte copies of the 16 DS02 layers)
  * runtime_config.json
  * config.js
  * checks/build_runtime_report.json

No art-owned file is modified.  The only output in art_assets/art_checks is
never touched.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent.parent  # 星核旅人; baseline has 5 relative Godot paths
ASSETS = ROOT / "art_assets"
MANIFEST = ROOT / "art_manifest.json"
DS02 = ROOT.parent / "云海遗迹背景动态重制_DS02"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\background-ds03-baseline-a410495bf65545a093322abb90b2645c\hashes.json"
)
CHECKS = ROOT / "checks"

# 7 sky banks/wisps + 2 sea shelves + 3 projected shadows + 4 free rocks.
# These names are also the runtime keys in config.js.
COMMON_NAMES = [
    "sky_bank_left",
    "sky_bank_right",
    "sky_mid_wisp",
    "sky_low_wisp_r",
    "sky_left_wisp",
    "sky_low_wisp_l",
    "sky_high_chip",
    "sea_main",
    "sea_near",
    "shadow_central",
    "shadow_cluster",
    "shadow_low",
    "debris_central",
    "debris_cluster",
    "debris_tiny",
    "debris_low",
]

# Runtime motion after the small-ruins-only adjustment (2026-11-03).
# phase is in seconds:
#   dy = amp * sin(2*pi*(t + phase) / period)
# Positive dy is down in canvas coordinates.
#
# G1/G2 are both complete bridge bodies.  enabled=False is a real runtime
# early-out in preview.js, so neither normal playback nor force/worst debug
# modes can move them; they sit exactly at the art offset.  Their old amp
# values are retained as the art-manifest upper bound, not as active motion.
# G3/G4/G5 use the new light/slow values.  Their phases keep the old offsets.
# The 2x device canvas plus 0.5 logical px quantization renders these as
# -0.5/0/+0.5 logical px (1 device px steps), never a larger visible shift.
GROUP_FLOAT = {
    "G1": {"enabled": False, "amp": 1.5, "period": 9.5, "phase": 0.0},
    "G2": {"enabled": False, "amp": 1.0, "period": 9.5, "phase": 0.2},
    "G3": {"enabled": True, "amp": 0.35, "period": 18.0, "phase": 0.8},
    "G4": {"enabled": True, "amp": 0.30, "period": 22.0, "phase": 1.1},
    "G5": {"enabled": True, "amp": 0.45, "period": 20.0, "phase": 0.15},
}

# The 5 px component at local (41,155)-(45,157) is the small old shadow/blade
# under debris_low.  It is filtered at runtime; the source PNG is untouched.
ROCK_EXCLUDE_RECTS = [[41, 155, 45, 157]]

# Times used by the review controls / capture script.  All are real time values
# of the runtime formula, not a separate demo mode.
INSPECTION = {
    # Legacy bridge up/down times are kept as two static-bridge review samples.
    "bridge_static_t1": 7.125,
    "bridge_static_t2": 2.375,
    "bridge_joint_t": 64.47,       # static bridges + low sea top at G1 foot 282
    "island_min_t": 26.683,        # G5 quantized +0.5, G2 static; actual gap sampled
    "g3_g1_min_t": 2.375,          # G3 quantized +0.5, G1 static; actual gap sampled
    # Both seam markers visible: main ~250.8, near ~430 at this time.
    "seam_t": 430.0 / 7.2,
    "seam_offsets": [-0.8, 0.0, 0.8],
    # A true texture-cycle crossing (main phase wraps 1278 -> 0).
    "cycle_t": 1278.0 / 4.2,
    "sky_wrap_t": (640.0 + 8.0 - 376.0) / 6.2,
}


def fail(message: str) -> "NoReturn":
    raise SystemExit("BUILD RUNTIME FAILED: " + message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def verify_baseline() -> list[dict]:
    items = read_json(BASELINE)
    if len(items) != 108:
        fail(f"baseline has {len(items)} entries, expected 108")
    bad = []
    rows = []
    for item in items:
        path = Path(item["path"])
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        if not path.is_file():
            bad.append({"path": str(path), "problem": "missing"})
            continue
        got = sha256(path).upper()
        expected = item["sha256"].upper()
        rows.append({"path": str(path), "sha256": got, "ok": got == expected})
        if got != expected:
            bad.append({"path": str(path), "expected": expected, "got": got})
    if bad:
        fail("protected baseline changed before build: " + json.dumps(bad[:3], ensure_ascii=False))
    return rows


def verify_art() -> list[dict]:
    manifest = read_json(MANIFEST)
    rows = []
    seen = set()
    for layer in manifest["layers"]:
        path = ROOT / layer["file"]
        if not path.is_file():
            fail(f"missing art layer: {layer['file']}")
        digest = sha256(path)
        if digest.lower() != layer["sha256"].lower():
            fail(f"art layer hash changed: {layer['file']}")
        if layer["id"] in seen:
            fail(f"duplicate art layer id: {layer['id']}")
        seen.add(layer["id"])
        rows.append(
            {
                "id": layer["id"],
                "file": layer["file"],
                "sha256": digest,
                "ok": True,
            }
        )
    if len(rows) != 8:
        fail(f"expected 8 art layers, got {len(rows)}")
    return rows


def copy_common() -> list[dict]:
    (ROOT / "common").mkdir(parents=True, exist_ok=True)
    rows = []
    for name in COMMON_NAMES:
        src = DS02 / "layers" / f"{name}.png"
        dst = ROOT / "common" / f"{name}.png"
        if not src.is_file():
            fail(f"missing DS02 source: {src}")
        before = sha256(src)
        shutil.copyfile(src, dst)
        after_src = sha256(src)
        after_dst = sha256(dst)
        if before != after_src:
            fail(f"DS02 source changed during copy: {src}")
        if after_dst != before:
            fail(f"byte copy mismatch: {dst}")
        rows.append(
            {
                "name": name,
                "source": str(src),
                "destination": "common/" + dst.name,
                "sha256": after_dst,
                "bytes": dst.stat().st_size,
                "ok": True,
            }
        )
    if len(rows) != 16:
        fail(f"expected 16 common assets, got {len(rows)}")
    return rows


def load_ds02_config() -> dict:
    path = DS02 / "config.json"
    cfg = read_json(path)
    for key in ("sky", "sea", "debris", "shadows"):
        if key not in cfg or not isinstance(cfg[key], list):
            fail(f"DS02 config missing list: {key}")
    return cfg


def prefixed(items: list[dict]) -> list[dict]:
    out = []
    for item in items:
        copied = dict(item)
        copied["file"] = "common/" + Path(item["file"]).name
        out.append(copied)
    return out


def build_config(ds02: dict, manifest: dict, common_rows: list[dict]) -> dict:
    by_id = {layer["id"]: layer for layer in manifest["layers"]}
    if set(by_id) != {
        "base_sky",
        "G1_left_bridge",
        "G2_right_bridge",
        "G3_left_hall_island",
        "G4_far_courtyard",
        "G5_right_temple_island",
        "arch_stone",
        "rock_remnants_static",
    }:
        fail("unexpected art layer id set")

    base = dict(by_id["base_sky"])
    base.pop("abs_path", None)
    base["role"] = "opaque background"
    group_ids = {
        "G1": "G1_left_bridge",
        "G2": "G2_right_bridge",
        "G3": "G3_left_hall_island",
        "G4": "G4_far_courtyard",
        "G5": "G5_right_temple_island",
    }
    groups = []
    for gid, layer_id in group_ids.items():
        layer = dict(by_id[layer_id])
        layer.pop("abs_path", None)
        layer["id"] = gid
        layer["art_id"] = layer_id
        layer["float"] = dict(GROUP_FLOAT[gid])
        groups.append(layer)

    static = []
    for layer_id in ("arch_stone", "rock_remnants_static"):
        layer = dict(by_id[layer_id])
        layer.pop("abs_path", None)
        layer["id"] = layer_id
        if layer_id == "rock_remnants_static":
            layer["exclude_mask_rects"] = [list(r) for r in ROCK_EXCLUDE_RECTS]
            layer["filter_note"] = (
                "skip the isolated 5 px component at local (41,155)-(45,157), "
                "which sits under debris_low and reads as an old shadow/blade; "
                "all other static rocks are kept. Source PNG is unchanged."
            )
        static.append(layer)

    common_hash = {row["name"]: row["sha256"] for row in common_rows}
    sky = prefixed(ds02["sky"])
    sea = prefixed(ds02["sea"])
    shadows = prefixed(ds02["shadows"])
    debris = prefixed(ds02["debris"])
    for section in (sky, sea, shadows, debris):
        for item in section:
            name = Path(item["file"]).stem
            item["sha256"] = common_hash[name]

    cfg = {
        "name": "云海遗迹背景动态修复_DS03",
        "canvas": [640, 360],
        "render_scale": 2,
        "sea_period": ds02["sea_period"],
        "phase_convention": (
            "phase=(speed*t)%P; texture column u is drawn at screen x=u+phase; "
            "the periodic copy is drawn at x=phase-P; cloud top is sampled at "
            "u=(world_x-phase)%P. phase increasing means the cloud moves right."
        ),
        "quantization": {
            "logical_quantum": 0.5,
            "device": "640x360 logical, 1280x720 nearest-neighbour device canvas",
            "note": "positions are rounded to 0.5 logical px (=1 device px at 2x)",
        },
        "base": base,
        "groups": groups,
        "static": static,
        "sky": sky,
        "sea": sea,
        "shadows": shadows,
        "debris": debris,
        "stack": [
            {"depth": 0, "items": ["base"]},
            {"depth": 10, "items": ["sky"]},
            {"depth": 20, "items": ["G3", "G4", "G5"]},
            {"depth": 30, "items": ["G1", "G2"]},
            {"depth": 40, "items": ["sea_main", "shadow_central", "shadow_cluster"]},
            {"depth": 45, "items": ["arch_stone"]},
            {"depth": 50, "items": ["sea_near", "shadow_low"]},
            {"depth": 60, "items": ["rock_remnants_static"]},
            {"depth": 70, "items": ["debris_central", "debris_cluster", "debris_tiny", "debris_low"]},
        ],
        "inspection": dict(INSPECTION),
        "rois": {
            "left_foot": [30, 250, 120, 283],
            "right_foot": [455, 250, 560, 283],
            "sky_band": [0, 35, 640, 125],
            "sea_band": [0, 330, 640, 360],
            "g5_g2_column": [474, 138, 483, 205],
        },
        "source": {
            "art_manifest": "art_manifest.json",
            "art_layers": "art_assets/",
            "common_copies": "common/ (byte copies from DS02 layers)",
            "old_layers_used": [],
        },
    }
    return cfg


def main() -> int:
    baseline_rows = verify_baseline()
    art_rows = verify_art()
    common_rows = copy_common()
    ds02 = load_ds02_config()
    manifest = read_json(MANIFEST)
    cfg = build_config(ds02, manifest, common_rows)

    config_json = json.dumps(cfg, ensure_ascii=False, indent=2) + "\n"
    (ROOT / "runtime_config.json").write_text(config_json, encoding="utf-8")
    (ROOT / "config.js").write_text(
        "window.DS03_CONFIG = " + config_json.rstrip() + ";\n", encoding="utf-8"
    )

    # Guard the exact defect this task is fixing: no legacy whole-canvas overlay,
    # no static plate, no right-foot re-cover branch in the runtime.
    banned = ("base_static", "island_overlay", "arch_overlay")
    joined = config_json
    found = [name for name in banned if name in joined]
    if found:
        fail("runtime config references banned legacy layer(s): " + ", ".join(found))

    CHECKS.mkdir(parents=True, exist_ok=True)
    report = {
        "ok": True,
        "baseline": {"checked": len(baseline_rows), "ok": len(baseline_rows), "rows": baseline_rows},
        "art_layers": {"checked": len(art_rows), "ok": len(art_rows), "rows": art_rows},
        "common_copies": {"checked": len(common_rows), "ok": len(common_rows), "rows": common_rows},
        "config": {
            "file": "runtime_config.json",
            "sha256": sha256(ROOT / "runtime_config.json"),
            "config_js_sha256": sha256(ROOT / "config.js"),
            "common_asset_count": len(common_rows),
            "art_asset_count": len(art_rows),
            "inspection": cfg["inspection"],
            "rois": cfg["rois"],
        },
    }
    (CHECKS / "build_runtime_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("OK runtime_config.json / config.js")
    print(f"baseline {len(baseline_rows)} / art {len(art_rows)} / common {len(common_rows)}")
    print(f"sea period {cfg['sea_period']} inspection {cfg['inspection']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
