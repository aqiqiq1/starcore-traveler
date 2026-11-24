"""Second rename batch: lowercase take letters in the reassembly SFX."""
from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
OUT = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")

RENAMES = [
    (
        "assets/audio_movement_20261117/reassembly_A_reverse.wav",
        "assets/audio_movement_20261117/reassembly_a_reverse.wav",
    ),
    (
        "assets/audio_movement_20261117/reassembly_B_pauliuw.wav",
        "assets/audio_movement_20261117/reassembly_b_pauliuw.wav",
    ),
]
TEXT_SUFFIXES = {".gd", ".tscn", ".scn", ".json", ".py", ".ps1", ".cfg", ".html", ".tres"}
SKIP_PARTS = {".godot", "项目归档"}
SKIP_PREFIXES = ("tests/logs/",)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def import_uid(p: Path) -> str:
    side = p.with_name(p.name + ".import")
    if not side.exists():
        return ""
    m = re.search(r'uid="(uid://[^"]+)"', side.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else ""


rows = []
for old, new in RENAMES:
    src, dst = ROOT / old, ROOT / new
    assert src.exists(), old
    case_only = src.name.lower() == dst.name.lower()
    if not case_only:
        assert not dst.exists(), new
    tmp = src.with_name(src.name + ".casetmp")
    row = {
        "old_path": "res://" + old,
        "new_path": "res://" + new,
        "bytes": src.stat().st_size,
        "sha256": sha256(src),
        "import_uid_before": import_uid(src),
        "import_uid_after": "",
        "rewritten_references": "",
    }
    src.rename(tmp)
    tmp.rename(dst)
    side_old = ROOT / (old + ".import")
    if side_old.exists():
        side_new = ROOT / (new + ".import")
        text = side_old.read_bytes().decode("utf-8")
        text = text.replace('source_file="res://' + old + '"', 'source_file="res://' + new + '"')
        side_tmp = side_old.with_name(side_old.name + ".casetmp")
        side_old.rename(side_tmp)
        side_tmp.rename(side_new)
        side_new.write_bytes(text.encode("utf-8"))
    row["import_uid_after"] = import_uid(dst)
    rows.append(row)

pairs = [(o, n) for o, n in RENAMES]
base_pairs = [(Path(o).name, Path(n).name) for o, n in RENAMES]
touched: dict[str, list[str]] = {}
for p in sorted(ROOT.rglob("*")):
    if not p.is_file() or p.suffix.lower() not in TEXT_SUFFIXES:
        continue
    rel = p.relative_to(ROOT).as_posix()
    if set(p.relative_to(ROOT).parts) & SKIP_PARTS or rel.startswith(SKIP_PREFIXES):
        continue
    try:
        text = p.read_bytes().decode("utf-8")
    except UnicodeDecodeError:
        continue
    new_text = text
    hits = []
    for o, n in pairs:
        if o in new_text:
            hits.append(o)
            new_text = new_text.replace(o, n)
    for o, n in base_pairs:
        if o in new_text:
            hits.append(o)
            new_text = new_text.replace(o, n)
    if new_text != text:
        p.write_bytes(new_text.encode("utf-8"))
        touched[rel] = hits

for row in rows:
    old = row["old_path"][len("res://"):]
    name = Path(old).name
    row["rewritten_references"] = " | ".join(
        sorted(k for k, v in touched.items() if old in v or name in v)
    )

csv_path = OUT / "asset_rename_map.csv"
with csv_path.open("a", encoding="utf-8-sig", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    w.writerows(rows)

print("renamed", len(rows), "touched", len(touched))
for k in sorted(touched):
    print("  ", k)
