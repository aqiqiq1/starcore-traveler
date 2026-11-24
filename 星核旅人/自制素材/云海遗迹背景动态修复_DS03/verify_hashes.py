#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Final read-only hash/protection check for DS03.

Verifies:
  * 108-item protected baseline (UTF-8 BOM path list, original absolute paths)
  * 8 art layers against art_manifest.json
  * 16 common PNG copies byte-identical to DS02 layers
  * the runtime references exactly the expected assets and no legacy overlay
Writes checks/final_hashes_check.json only.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent.parent
DS02 = ROOT.parent / "云海遗迹背景动态重制_DS02"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\background-ds03-baseline-a410495bf65545a093322abb90b2645c\hashes.json"
)
CHECKS = ROOT / "checks"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    baseline = json.loads(BASELINE.read_text(encoding="utf-8-sig"))
    base_bad = []
    for item in baseline:
        path = Path(item["path"])
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        if not path.is_file():
            base_bad.append({"path": str(path), "problem": "missing"})
            continue
        got = sha256(path).lower()
        if got != item["sha256"].lower():
            base_bad.append({"path": str(path), "expected": item["sha256"], "got": got})

    manifest = json.loads((ROOT / "art_manifest.json").read_text(encoding="utf-8"))
    art_rows = []
    for layer in manifest["layers"]:
        path = ROOT / layer["file"]
        got = sha256(path)
        art_rows.append(
            {
                "id": layer["id"],
                "file": layer["file"],
                "sha256": got,
                "ok": got.lower() == layer["sha256"].lower(),
            }
        )
    art_bad = [row for row in art_rows if not row["ok"]]

    config = json.loads((ROOT / "runtime_config.json").read_text(encoding="utf-8"))
    common_rows = []
    for section in ("sky", "sea", "shadows", "debris"):
        for item in config[section]:
            rel = Path(item["file"])
            src = DS02 / "layers" / rel.name
            dst = ROOT / rel
            got_src, got_dst = sha256(src), sha256(dst)
            common_rows.append(
                {
                    "file": item["file"],
                    "ds02": str(src),
                    "sha256": got_dst,
                    "byte_identical": got_src == got_dst,
                }
            )
    common_bad = [row for row in common_rows if not row["byte_identical"]]

    ds02_cfg = json.loads((DS02 / "config.json").read_text(encoding="utf-8"))
    rule_fields = {
        "sky": ["name", "size", "x0", "y0", "speed", "wrap_gap", "kind"],
        "sea": ["name", "size", "y0", "period", "speed", "phase0", "top", "kind"],
        "shadows": ["name", "size", "rock", "dx", "dy", "alpha", "surface"],
        "debris": ["name", "size", "x0", "y0", "amp_y", "period", "phase", "kind"],
    }
    rule_rows = []
    for section, fields in rule_fields.items():
        for old, new in zip(ds02_cfg[section], config[section]):
            mismatches = {
                field: [old.get(field), new.get(field)]
                for field in fields
                if old.get(field) != new.get(field)
            }
            rule_rows.append({"section": section, "name": old.get("name"), "mismatches": mismatches})
    rules_ok = all(not row["mismatches"] for row in rule_rows)

    keys = []
    keys.append(config["base"]["file"])
    for section in ("groups", "static", "sky", "sea", "shadows", "debris"):
        for item in config[section]:
            keys.append(item["file"])
    missing = [key for key in keys if not (ROOT / key).is_file()]
    banned = [
        key
        for key in keys
        if any(name in key for name in ("base_static", "island_overlay", "arch_overlay"))
    ]
    runtime_text = "\n".join(
        (ROOT / name).read_text(encoding="utf-8")
        for name in ("preview.html", "preview.js", "runtime_config.json")
    )
    banned_refs = [
        name for name in ("base_static", "island_overlay", "arch_overlay") if name in runtime_text
    ]

    ok = (
        not base_bad
        and not art_bad
        and not common_bad
        and not missing
        and not banned
        and not banned_refs
        and rules_ok
        and config["sea_period"] == ds02_cfg["sea_period"]
    )
    report = {
        "ok": ok,
        "baseline": {"checked": len(baseline), "bad": base_bad},
        "art_layers": {"checked": len(art_rows), "rows": art_rows, "bad": art_bad},
        "common_copies": {"checked": len(common_rows), "rows": common_rows, "bad": common_bad},
        "motion_and_shadow_rules": {"ok": rules_ok, "rows": rule_rows},
        "runtime_assets": {"count": len(keys), "missing": missing, "banned_keys": banned, "banned_refs": banned_refs},
    }
    CHECKS.mkdir(parents=True, exist_ok=True)
    (CHECKS / "final_hashes_check.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("baseline", len(baseline), "bad", len(base_bad))
    print("art", len(art_rows), "bad", len(art_bad))
    print("common", len(common_rows), "bad", len(common_bad))
    print("runtime assets", len(keys), "missing", missing, "banned", banned, banned_refs)
    print("OK" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
