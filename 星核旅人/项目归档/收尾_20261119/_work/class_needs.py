"""Check whether unreachable scripts are still needed (class_name refs, extends)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
WORK = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119\_work")

report = json.loads((WORK / "asset_usage.json").read_text(encoding="utf-8"))
reach = set(report["reachable_files"])

class_re = re.compile(r'^class_name\s+([A-Za-z0-9_]+)', re.M)
extends_re = re.compile(r'^extends\s+"?(res://[^"\n]+)"?', re.M)

classes: dict[str, str] = {}
for p in sorted(ROOT.rglob("*.gd")):
    relp = p.relative_to(ROOT).as_posix()
    if relp.startswith(("项目归档/",)):
        continue
    t = p.read_text(encoding="utf-8", errors="replace")
    m = class_re.search(t)
    if m:
        classes[m.group(1)] = relp

reach_text = {}
for relp in sorted(reach):
    p = ROOT / relp
    if p.suffix in {".gd", ".tscn", ".scn"} and p.exists():
        reach_text[relp] = p.read_text(encoding="utf-8", errors="replace")

declared_unreachable = {c: f for c, f in classes.items() if f not in reach}
needed: dict[str, list[str]] = {}
for cls, f in sorted(declared_unreachable.items()):
    refs = []
    for relp, t in reach_text.items():
        if re.search(rf'\b{re.escape(cls)}\b', t):
            refs.append(relp)
    if refs:
        needed[cls] = refs

print("scripts on disk:", len([p for p in ROOT.rglob('*.gd') if '项目归档' not in p.relative_to(ROOT).parts]))
print("reachable scripts:", len([r for r in reach if r.endswith('.gd')]))
print("unreachable class_name scripts:", len(declared_unreachable))
print("--- unreachable classes still referenced by reachable files ---")
for cls, refs in needed.items():
    print(f"{cls} ({declared_unreachable[cls]}) <- {refs}")

# scripts not reachable and with no class_name
no_class = []
for p in sorted(ROOT.rglob("*.gd")):
    relp = p.relative_to(ROOT).as_posix()
    if relp.startswith("项目归档/") or relp in reach:
        continue
    t = p.read_text(encoding="utf-8", errors="replace")
    if not class_re.search(t):
        no_class.append(relp)

print("--- unreachable scripts without class_name (referenced only by scene ext_resource?) ---")
for r in no_class:
    refs = [k for k, v in json.loads((WORK / "deps_raw.json").read_text(encoding="utf-8"))["scenes"].items() if r in [d.replace('res://','') for d in v]]
    print(r, "<-", refs[:5])

# extends res:// to scripts
print("--- extends res:// chains ---")
for p in sorted(ROOT.rglob("*.gd")):
    relp = p.relative_to(ROOT).as_posix()
    if relp.startswith("项目归档/"):
        continue
    t = p.read_text(encoding="utf-8", errors="replace")
    for m in extends_re.finditer(t):
        print(relp, "extends", m.group(1), "(reachable)" if relp in reach else "")
