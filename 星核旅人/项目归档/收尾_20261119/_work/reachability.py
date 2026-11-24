"""Reachability from the real entry scene, plus asset-usage report."""
from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
WORK = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119\_work")

RES_RE = re.compile(r'res://[^"\'\s\)\]]+')

raw = json.loads((WORK / "deps_raw.json").read_text(encoding="utf-8"))

# normalize: res://x -> x (posix, no leading slash)
def norm(p: str) -> str:
    p = p.strip()
    if p.startswith("res://"):
        p = p[len("res://"):]
    p = p.rstrip('.,;')
    return p.replace("\\", "/")


graph: dict[str, set[str]] = {}

for kind in ("scenes", "scripts"):
    for key, deps in raw[kind].items():
        graph.setdefault(key, set())
        for d in deps:
            graph[key].add(norm(d))

# expand directory references (audio dirs etc.) to every file inside
all_files = []
for dirpath in ROOT.rglob("*"):
    if ".godot" in dirpath.parts or "项目归档" in dirpath.parts:
        continue
    if dirpath.is_file():
        all_files.append(dirpath.relative_to(ROOT).as_posix())

for key, deps in list(graph.items()):
    extra = set()
    for d in deps:
        if d.endswith("/"):
            for f in all_files:
                if f.startswith(d):
                    extra.add(f)
    if extra:
        deps |= extra

missing = set()
for key, deps in graph.items():
    for d in deps:
        if not (ROOT / d).exists() and d not in graph:
            missing.add((key, d))

# BFS
entry = "scenes/level_01.tscn"
seen: set[str] = set()
order = [entry]
q = deque([entry])
while q:
    cur = q.popleft()
    if cur in seen:
        continue
    seen.add(cur)
    for d in sorted(graph.get(cur, ())):
        if d not in seen and (ROOT / d).exists():
            order.append(d)
            q.append(d)

reachable = set(seen)
all_scenes = sorted(k for k in raw["scenes"] if (ROOT / k).exists())
unreachable_scenes = [s for s in all_scenes if s not in reachable]

# reverse map: which reachable file references an asset
reverse: dict[str, list[str]] = {}
for k in reachable:
    for d in graph.get(k, ()):
        reverse.setdefault(d, []).append(k)

report = {
    "entry": entry,
    "reachable_count": len(reachable),
    "reachable_scenes": [s for s in all_scenes if s in reachable],
    "unreachable_scenes": unreachable_scenes,
    "unreachable_scene_count": len(unreachable_scenes),
    "missing_refs": sorted([f"{a} -> {b}" for a, b in missing]),
}
(WORK / "reachability.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8"
)

print("entry", entry)
print("reachable files", len(reachable))
print("reachable scenes", len(report["reachable_scenes"]))
print("unreachable scenes", len(unreachable_scenes))
print("missing refs", len(missing))
for r in report["missing_refs"][:40]:
    print("  MISSING", r)
