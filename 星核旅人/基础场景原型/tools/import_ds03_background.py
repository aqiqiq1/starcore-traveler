#!/usr/bin/env python3
"""Import the approved DS03 background into the Godot project.

This tool only reads the read-only DS03 source directory. It copies the 24 PNG
files byte-for-byte, copies the runtime config for traceability, and generates a
GDScript data file so the runtime does not parse JSON or rebuild pixels.

It never runs the DS03 generators and never rewrites the source.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = PROJECT_ROOT.parent
SOURCE_DIR = REPO_ROOT / "自制素材" / "云海遗迹背景动态修复_DS03"
DEST_DIR = PROJECT_ROOT / "assets" / "backgrounds" / "cloud_ruins_ds03"
DATA_PATH = PROJECT_ROOT / "scripts" / "backgrounds" / "cloud_ruins_ds03_data.gd"
RES_PREFIX = "res://assets/backgrounds/cloud_ruins_ds03/"

SECTIONS = ("base", "groups", "static", "sky", "sea", "shadows", "debris")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gd_value(value, indent: int = 0) -> str:
    pad = "\t" * indent
    child_pad = "\t" * (indent + 1)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        text = repr(value)
        if "e" in text or "E" in text:
            text = f"{value:.10f}".rstrip("0").rstrip(".")
        if "." not in text:
            text += ".0"
        return text
    if isinstance(value, (list, tuple)):
        if not value:
            return "[]"
        # Keep long sea-top arrays readable and parser-friendly.
        if all(isinstance(item, int) for item in value):
            lines = []
            for start in range(0, len(value), 16):
                chunk = ", ".join(str(item) for item in value[start:start + 16])
                lines.append(child_pad + chunk + ",")
            return "[\n" + "\n".join(lines) + "\n" + pad + "]"
        lines = []
        for item in value:
            lines.append(child_pad + gd_value(item, indent + 1) + ",")
        return "[\n" + "\n".join(lines) + "\n" + pad + "]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = []
        for key, item in value.items():
            lines.append(
                child_pad
                + json.dumps(str(key), ensure_ascii=False)
                + ": "
                + gd_value(item, indent + 1)
                + ","
            )
        return "{\n" + "\n".join(lines) + "\n" + pad + "}"
    raise TypeError(f"unsupported value: {type(value)!r}")


def reduced_item(item: dict, keep_top: bool) -> dict:
    result = {
        "file": item["file"],
        "sha256": item["sha256"],
        "size": item["size"],
    }
    if "id" in item:
        result["id"] = item["id"]
    if "name" in item:
        result["name"] = item["name"]
    if "float" in item:
        result["float"] = {
            "enabled": item["float"]["enabled"],
            "amp": item["float"]["amp"],
            "period": item["float"]["period"],
            "phase": item["float"]["phase"],
        }
    if keep_top:
        result["top"] = item["top"]
    if "offset" in item:
        result["offset"] = item["offset"]
    if "depth" in item:
        result["depth"] = item["depth"]
    if "order" in item:
        result["order"] = item["order"]
    if "x0" in item:
        result["x0"] = item["x0"]
    if "y0" in item:
        result["y0"] = item["y0"]
    if "speed" in item:
        result["speed"] = item["speed"]
    if "wrap_gap" in item:
        result["wrap_gap"] = item["wrap_gap"]
    if "period" in item:
        result["period"] = item["period"]
    if "phase0" in item:
        result["phase0"] = item["phase0"]
    if "amp_y" in item:
        result["amp_y"] = item["amp_y"]
    if "phase" in item:
        result["phase"] = item["phase"]
    if "kind" in item:
        result["kind"] = item["kind"]
    if "rock" in item:
        result["rock"] = item["rock"]
    if "dx" in item:
        result["dx"] = item["dx"]
    if "dy" in item:
        result["dy"] = item["dy"]
    if "surface" in item:
        result["surface"] = item["surface"]
    if "exclude_mask_rects" in item:
        result["exclude_mask_rects"] = item["exclude_mask_rects"]
    return result


def main() -> int:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"DS03 source directory not found: {SOURCE_DIR}")
    config_path = SOURCE_DIR / "runtime_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))

    (DEST_DIR / "art_assets").mkdir(parents=True, exist_ok=True)
    (DEST_DIR / "common").mkdir(parents=True, exist_ok=True)
    DATA_PATH.parent.mkdir(parents=True, exist_ok=True)

    copied = []
    for section in SECTIONS:
        items = config[section]
        if isinstance(items, dict):
            items = [items]
        for item in items:
            relative = item["file"]
            source = SOURCE_DIR / relative
            destination = DEST_DIR / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            source_hash = sha256(source)
            destination_hash = sha256(destination)
            if source_hash != destination_hash:
                raise RuntimeError(f"byte copy changed: {relative}")
            if source_hash.lower() != item["sha256"].lower():
                raise RuntimeError(f"source hash differs from config: {relative}")
            copied.append((relative, destination_hash))

    # Keep the exact runtime config next to the runtime assets so the Godot
    # acceptance test can compare hashes, layer order and motion parameters.
    shutil.copyfile(config_path, DEST_DIR / "runtime_config.json")
    if sha256(config_path) != sha256(DEST_DIR / "runtime_config.json"):
        raise RuntimeError("runtime_config.json copy changed")

    reduced = {
        "render_scale": config["render_scale"],
        "sea_period": config["sea_period"],
        "base": reduced_item(config["base"], False),
        "groups": [reduced_item(item, False) for item in config["groups"]],
        "static": [reduced_item(item, False) for item in config["static"]],
        "sky": [reduced_item(item, False) for item in config["sky"]],
        "sea": [reduced_item(item, True) for item in config["sea"]],
        "shadows": [reduced_item(item, False) for item in config["shadows"]],
        "debris": [reduced_item(item, False) for item in config["debris"]],
        "stack": config["stack"],
    }

    textures = {}
    for relative, _digest in copied:
        textures[relative] = f'preload("{RES_PREFIX}{relative}")'

    lines = [
        "extends RefCounted",
        "class_name CloudRuinsDS03Data",
        "",
        "## Generated by tools/import_ds03_background.py from the read-only DS03",
        "## runtime_config.json. Do not hand-edit; re-run the import tool instead.",
        "",
        "const CONFIG := " + gd_value(reduced) + "",
        "",
        "const TEXTURES := {",
    ]
    for relative, _digest in copied:
        lines.append(
            "\t" + json.dumps(relative) + ": " + textures[relative] + ","
        )
    lines.append("}")
    DATA_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    manifest = {
        "source": "自制素材/云海遗迹背景动态修复_DS03",
        "source_runtime_config_sha256": sha256(config_path),
        "runtime_prefix": RES_PREFIX,
        "canvas": config["canvas"],
        "render_scale": config["render_scale"],
        "sea_period": config["sea_period"],
        "png_count": len(copied),
        "pngs": {relative: digest for relative, digest in copied},
        "generated_data": "res://scripts/backgrounds/cloud_ruins_ds03_data.gd",
    }
    (DEST_DIR / "source_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"IMPORTED {len(copied)} PNG byte-for-byte")
    print(f"source_config_sha256 {manifest['source_runtime_config_sha256']}")
    print(f"data {DATA_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
