#!/usr/bin/env python3
"""Before/after protection for the compact-header UI task.

Scopes: project settings, all formal scenes/scripts, all asset PNGs, key asset
JSON, and 项目归档/.gdignore. The only authorized edits are the two HUD scripts.
A new shared header script is a new file, not a baseline change.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "tests" / "logs" / "compact_header_before.json"
REPORT = ROOT / "tests" / "logs" / "compact_header_protection.json"
AUTHORIZED = {
    "scripts/level_hud.gd",
    "scripts/level_02_hud.gd",
}


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def files() -> list[str]:
    out = ["project.godot", "项目归档/.gdignore"]
    for pattern in ("scripts/**/*.gd", "scenes/**/*.tscn", "assets/**/*.png"):
        for path in sorted(ROOT.glob(pattern)):
            out.append(path.relative_to(ROOT).as_posix())
    for path in sorted((ROOT / "assets").rglob("*.json")):
        out.append(path.relative_to(ROOT).as_posix())
    return sorted(set(out))


def main() -> int:
    rels = files()
    current = {rel: sha(ROOT / rel) for rel in rels}
    if "--write" in sys.argv:
        BASE.parent.mkdir(parents=True, exist_ok=True)
        BASE.write_text(json.dumps(current, indent=2) + "\n", encoding="utf-8")
        print(f"WROTE {BASE} ({len(current)} files)")
        return 0
    before = json.loads(BASE.read_text(encoding="utf-8"))
    current = {rel: sha(ROOT / rel) for rel in rels}
    new_files = [rel for rel in rels if rel not in before]
    changed = [rel for rel in rels if rel in before and before[rel] != current[rel]]
    authorized = [rel for rel in changed if rel in AUTHORIZED]
    unauthorized = [rel for rel in changed if rel not in AUTHORIZED]
    report = {
        "baseline": BASE.relative_to(ROOT).as_posix(),
        "file_count": len(rels),
        "new": new_files,
        "changed": changed,
        "authorized": authorized,
        "unauthorized": unauthorized,
        "current": current,
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for rel in new_files:
        print(f"NEW {rel}")
    for rel in authorized:
        print(f"AUTHORIZED {rel}")
    for rel in unauthorized:
        print(f"UNAUTHORIZED {rel}", file=sys.stderr)
    print(f"COMPACT_HEADER_PROTECTION {len(rels)} files; new={len(new_files)} authorized={len(authorized)} unauthorized={len(unauthorized)}")
    return 1 if unauthorized else 0


if __name__ == "__main__":
    raise SystemExit(main())
