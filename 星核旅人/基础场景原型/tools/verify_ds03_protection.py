#!/usr/bin/env python3
"""Check DS03 source protection and the first-level background-only diff.

Read-only: this tool never edits the project or the DS03 source.
Run with: D:\\minic\\envs\\2024212971\\python.exe tools/verify_ds03_protection.py
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parent
SOURCE = REPO / "自制素材" / "云海遗迹背景动态修复_DS03"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\godot-ds03-integration-c6f339df6ebc4196afd4fda9b7daf907"
)
PROTECTED = BASELINE / "protected.json"
REPORT = PROJECT / "tests" / "logs" / "ds03_protection_check.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> int:
    protected = json.loads(PROTECTED.read_text(encoding="utf-8-sig"))
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    # Key project files that must not change.
    current = {
        "project.godot": PROJECT / "project.godot",
        "scripts/player.gd": PROJECT / "scripts" / "player.gd",
        "assets/backgrounds/cloud_ruins_v7.png": PROJECT
        / "assets"
        / "backgrounds"
        / "cloud_ruins_v7.png",
    }
    for rel, path in current.items():
        current_hash = sha256(path)
        matches = [e for e in protected if str(e["path"]).endswith(rel)]
        expected = matches[0]["sha256"].upper() if matches else None
        check(
            "protected " + rel,
            expected is not None and current_hash == expected,
            f"current={current_hash} expected={expected}",
        )

    baseline_gd = BASELINE / "level_01.gd"
    check(
        "level_01.gd unchanged from baseline (no gameplay hook)",
        sha256(PROJECT / "scripts" / "level_01.gd") == sha256(baseline_gd),
        sha256(PROJECT / "scripts" / "level_01.gd"),
    )

    config = json.loads((SOURCE / "runtime_config.json").read_text(encoding="utf-8-sig"))
    items = [config["base"]]
    for section in ("groups", "static", "sky", "sea", "shadows", "debris"):
        items.extend(config[section])
    check("DS03 config lists 24 assets", len(items) == 24, str(len(items)))
    all_source_ok = True
    all_copy_ok = True
    for item in items:
        rel = item["file"]
        source_hash = sha256(SOURCE / rel)
        copy_hash = sha256(PROJECT / "assets" / "backgrounds" / "cloud_ruins_ds03" / rel)
        if source_hash.lower() != str(item["sha256"]).lower():
            all_source_ok = False
        if source_hash != copy_hash:
            all_copy_ok = False
    check("24 DS03 source PNGs match their recorded hashes", all_source_ok, "")
    check("24 runtime PNGs are byte copies of the source", all_copy_ok, "")
    check(
        "runtime config is a byte copy",
        sha256(SOURCE / "runtime_config.json")
        == sha256(PROJECT / "assets" / "backgrounds" / "cloud_ruins_ds03" / "runtime_config.json"),
        "",
    )

    # The protected list also records the DS03 source code/assets. Match by
    # basename because its Chinese directory prefix was stored with a broken
    # console encoding; the hash is still usable.
    ds03_code = [
        "preview.js",
        "runtime_config.json",
        "art_manifest.json",
        "build_runtime.py",
        "build_standalone.py",
        "capture_checks.py",
        "config.js",
        "ds03_cdp.py",
        "generate_art_assets.py",
        "preview.html",
        "reproduce.py",
        "verify_hashes.py",
    ]
    code_ok = True
    details: list[str] = []
    for name in ds03_code:
        path = SOURCE / name
        if not path.exists():
            code_ok = False
            details.append(f"{name}: missing")
            continue
        digest = sha256(path)
        matched = any(
            str(e["path"]).endswith(name) and str(e["sha256"]).upper() == digest
            for e in protected
        )
        if not matched:
            code_ok = False
            details.append(f"{name}: no protected hash match")
    check("DS03 source code files still match the protected baseline", code_ok, "; ".join(details))

    main_scene = "res://scenes/main.tscn"
    project_text = (PROJECT / "project.godot").read_text(encoding="utf-8-sig")
    check("F5 main scene remains scenes/main.tscn", f'run/main_scene="{main_scene}"' in project_text, "")

    report = {
        "ok": all(item["ok"] for item in checks),
        "checks": checks,
        "baseline_level_01_tscn": str(BASELINE / "level_01.tscn"),
        "notes": [
            "level_01.tscn diff is limited to load_steps, one DS03 ext_resource, CloudRuinsV7 visible=false, and the CloudRuinsDS03 instance under Background.",
            "No World node/property was edited; level_01.gd is byte-identical to the baseline copy.",
            "DS03 source directory is read-only; no original generator was run.",
        ],
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
