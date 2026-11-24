"""Orphaned sidecar check: .import without payload, .uid without script."""
from pathlib import Path

R = Path(r"D:\godot game\星核旅人\基础场景原型")
orphans = []
for p in sorted(R.rglob("*")):
    if not p.is_file():
        continue
    rel = p.relative_to(R)
    if ".godot" in rel.parts or "项目归档" in rel.parts:
        continue
    if p.suffix == ".import":
        src = p.with_name(p.name[: -len(".import")])
        if not src.exists():
            orphans.append(("import_orphan", rel.as_posix()))
    elif p.suffix == ".uid":
        src = p.with_name(p.name[: -len(".uid")])
        if not src.exists():
            orphans.append(("uid_orphan", rel.as_posix()))

print("orphans:", len(orphans))
for kind, rel in orphans[:50]:
    print(" ", kind, rel)
