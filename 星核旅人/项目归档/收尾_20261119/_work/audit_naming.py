"""Naming audit for every runtime-referenced asset payload + archive staleness count."""
from __future__ import annotations

import csv
import json
import re
from pathlib import Path

R = Path(r"D:\godot game\星核旅人\基础场景原型")
OUT = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")
WORK = OUT / "_work"

reach = json.loads((WORK / "reachability_full.json").read_text(encoding="utf-8"))
renamed = {
    r["old_path"].replace("res://", ""): r["new_path"].replace("res://", "")
    for r in csv.DictReader(open(OUT / "asset_rename_map.csv", encoding="utf-8-sig"))
}
renamed_new = set(renamed.values())

PAYLOAD = {".png", ".wav", ".ogg", ".ttf", ".webp", ".jpg", ".svg"}
NONASSET_DIRS = ("source_evidence", "evidence")
SNAKE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*(\.[a-z0-9]+)$")

rows = []
for rel in sorted(reach["reachable_files"]):
    if not rel.startswith("assets/"):
        continue
    if Path(rel).suffix.lower() not in PAYLOAD:
        continue
    if any(d in rel for d in NONASSET_DIRS):
        continue
    name = Path(rel).name
    if rel in renamed_new:
        status = "RENAMED"
        note = "旧名 " + next(k for k, v in renamed.items() if v == rel)
    elif SNAKE.match(name):
        status = "COMPLIANT"
        note = ""
    else:
        status = "RETAINED_NON_SNAKE"
        note = "保留：文件名含外部原资产标识或版本语义，无运行时收益"
    rows.append({"asset_path": rel, "file_name": name, "status": status, "note": note})

with (OUT / "asset_naming_audit.csv").open("w", encoding="utf-8-sig", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["asset_path", "file_name", "status", "note"])
    w.writeheader()
    w.writerows(rows)

print("runtime asset payloads:", len(rows))
for st in ("RENAMED", "COMPLIANT", "RETAINED_NON_SNAKE"):
    print(" ", st, sum(1 for r in rows if r["status"] == st))
for r in rows:
    if r["status"] == "RETAINED_NON_SNAKE":
        print("   retained:", r["asset_path"])

# how many archived files still name a renamed asset (inert, alias map needed)
OLD = list(renamed.keys()) + [Path(o).name for o in renamed if not Path(o).name.startswith("male_hero")]
ARCH = Path(r"D:\godot game\星核旅人\非运行资料\历史测试与证据")
stale = {}
for p in sorted(ARCH.rglob("*")):
    if not p.is_file() or p.suffix.lower() not in {".gd", ".tscn", ".py", ".json", ".html", ".ps1"}:
        continue
    try:
        text = p.read_bytes().decode("utf-8", errors="replace")
    except OSError:
        continue
    hits = [o for o in OLD if o in text]
    if hits:
        stale[p.relative_to(ARCH).as_posix()] = sorted(set(hits))
print("archived files naming a renamed asset:", len(stale))
(OUT / "archive_stale_asset_refs.json").write_text(
    json.dumps(stale, ensure_ascii=False, indent=1), encoding="utf-8"
)
