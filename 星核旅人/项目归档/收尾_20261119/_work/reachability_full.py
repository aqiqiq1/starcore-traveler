"""Full reachability: scene/script resource edges + global class_name edges.

Comment lines are stripped before class-name matching so doc mentions do not
create false dependencies.
"""
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
    deps |= {f for d in deps if d.endswith("/") for f in all_files if f.startswith(d)}

class_re = re.compile(r'^class_name\s+([A-Za-z0-9_]+)', re.M)
classes: dict[str, str] = {}
for p in sorted(ROOT.rglob("*.gd")):
    relp = p.relative_to(ROOT).as_posix()
    if relp.startswith("项目归档/"):
        continue
    m = class_re.search(p.read_text(encoding="utf-8", errors="replace"))
    if m:
        classes[m.group(1)] = relp


def code_only(text: str) -> str:
    out = []
    for line in text.splitlines():
        s = line.lstrip()
        if s.startswith("#"):
            continue
        out.append(line)
    return "\n".join(out)


text_cache: dict[str, str] = {}


def code_of(relp: str) -> str:
    if relp not in text_cache:
        p = ROOT / relp
        text_cache[relp] = code_only(p.read_text(encoding="utf-8", errors="replace")) if p.exists() else ""
    return text_cache[relp]


entry = "scenes/level_01.tscn"
autoloads = []
proj = (ROOT / "project.godot").read_text(encoding="utf-8", errors="replace")
in_autoload = False
for line in proj.splitlines():
    if line.startswith("["):
        in_autoload = line.strip() == "[autoload]"
        continue
    if in_autoload and "=" in line:
        val = line.split("=", 1)[1].strip().strip('"').lstrip("*")
        if val.startswith("res://"):
            autoloads.append(norm(val))

seen: set[str] = set()
q = deque([entry] + autoloads)
while q:
    cur = q.popleft()
    if cur in seen:
        continue
    seen.add(cur)
    nxt = set()
    for d in graph.get(cur, ()):
        if (ROOT / d).exists():
            nxt.add(d)
    if cur.endswith(".gd"):
        code = code_of(cur)
        for cls, f in classes.items():
            if re.search(rf'\b{re.escape(cls)}\b', code):
                nxt.add(f)
    for d in sorted(nxt):
        if d not in seen:
            q.append(d)

scenes_all = sorted(k for k in raw["scenes"] if (ROOT / k).exists())
keep_scenes = [s for s in scenes_all if s in seen]
arch_scenes = [s for s in scenes_all if s not in seen]

report = {
    "reachable_files": sorted(seen),
    "reachable_scenes": keep_scenes,
    "archivable_scenes": arch_scenes,
}
(WORK / "reachability_full.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")

print("reachable files", len(seen))
print("reachable scenes", len(keep_scenes))
print("archivable scenes", len(arch_scenes))
print("reachable scripts", len([r for r in seen if r.endswith('.gd')]))
print("archivable scripts", len([r for r in all_files if r.endswith('.gd') and r not in seen]))
