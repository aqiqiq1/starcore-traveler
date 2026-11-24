"""Asset usage table for production assets referenced from the reachable set."""
from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
WORK = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119\_work")

raw = json.loads((WORK / "deps_raw.json").read_text(encoding="utf-8"))


def norm(p: str) -> str:
    p = p.strip()
    if p.startswith("res://"):
        p = p[len("res://"):]
    return p.rstrip('.,;').replace("\\", "/")


graph: dict[str, set[str]] = {}
for kind in ("scenes", "scripts"):
    for key, deps in raw[kind].items():
        graph.setdefault(key, set()).update(norm(d) for d in deps)

all_files = [
    p.relative_to(ROOT).as_posix()
    for p in ROOT.rglob("*")
    if p.is_file() and ".godot" not in p.parts and "项目归档" not in p.parts
]

for key, deps in list(graph.items()):
    extra = {f for d in deps if d.endswith("/") for f in all_files if f.startswith(d)}
    deps |= extra

entry = "scenes/level_01.tscn"
seen, q = set(), deque([entry])
while q:
    cur = q.popleft()
    if cur in seen:
        continue
    seen.add(cur)
    for d in graph.get(cur, ()):
        if d not in seen and (ROOT / d).exists():
            q.append(d)

reverse: dict[str, list[str]] = {}
for src in sorted(seen):
    for dst in graph.get(src, ()):
        reverse.setdefault(dst, []).append(src)

assets = {k: v for k, v in reverse.items() if k.startswith("assets/")}
previews = {k: v for k, v in reverse.items() if k.startswith("previews/")}
other = {k: v for k, v in reverse.items() if not k.startswith(("assets/", "scripts/", "scenes/", "tests/", "tools/"))}

report = {
    "reachable_files": sorted(seen),
    "reachable_asset_count": len(assets),
    "assets": {k: sorted(v) for k, v in sorted(assets.items())},
    "reachable_previews": {k: sorted(v) for k, v in sorted(previews.items())},
    "other_refs": {k: sorted(v) for k, v in sorted(other.items())},
}
(WORK / "asset_usage.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")

print("reachable files", len(seen))
print("reachable assets", len(assets))
print("reachable previews", len(previews))
for k in sorted(previews):
    print("  PREVIEW REF", k, "<-", previews[k])
for k in sorted(other):
    print("  OTHER REF", k, "<-", other[k])
print("total assets on disk", len([a for a in all_files if a.startswith('assets/')]))
