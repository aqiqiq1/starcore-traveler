#!/usr/bin/env python3
"""Back up exactly the formal files this rebuild will overwrite.

The outer repo is untracked, so these byte copies plus hashes are the recovery
evidence. No zip, no deletion, no unrelated files.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "项目归档" / "关卡改版前_20261113" / "L2_unified_ground"

FILES = [
    "scenes/level_01.tscn",
    "scenes/level_02.tscn",
    "scripts/level_02.gd",
    "scripts/level_02_hud.gd",
    "scenes/decorations/doric_column_tall.tscn",
    "scenes/decorations/doric_column_broken.tscn",
    "scenes/decorations/doric_column_base.tscn",
    "scripts/bay_rune_link.gd",
    "scripts/rune_stone_field.gd",
]


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {"created": "2026-11-13", "purpose": "before unified-ground L1/L2 rebuild", "files": []}
    for rel in FILES:
        src = ROOT / rel
        dst = DEST / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        manifest["files"].append({"path": rel, "sha256": sha(src), "bytes": src.stat().st_size})
        print(f"BACKUP {rel} {manifest['files'][-1]['sha256']}")
    (DEST / "MANIFEST.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"WROTE {DEST / 'MANIFEST.json'} ({len(FILES)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
