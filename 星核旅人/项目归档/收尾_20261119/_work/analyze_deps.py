"""Dependency + reachability analysis for the Godot project.

Read-only. Emits JSON/CSV used to build the archive/keep inventory.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
OUT = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119\_work")

SKIP_DIRS = {".godot", "项目归档"}

RES_RE = re.compile(r'res://[^"\'\s\)\]]+')


def walk_files() -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = Path(dirpath).relative_to(ROOT)
        parts = set(rel.parts)
        if parts & SKIP_DIRS:
            dirnames[:] = []
            continue
        for name in filenames:
            out.append(Path(dirpath) / name)
    return out


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def parse_scene_deps(path: Path) -> tuple[set[str], list[str]]:
    """Return (res paths referenced, script class names uids etc.)."""
    text = path.read_text(encoding="utf-8", errors="replace")
    deps: set[str] = set()
    for m in re.finditer(r'path="(res://[^"]+)"', text):
        deps.add(m.group(1))
    for m in re.finditer(r'uids?="uid://[^"]+"', text):
        pass
    return deps, []


def parse_text_deps(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    deps: set[str] = set()
    for m in RES_RE.finditer(text):
        s = m.group(0).rstrip('.,;')
        deps.add(s)
    return deps


def main() -> None:
    files = walk_files()
    scenes = [p for p in files if p.suffix in {".tscn", ".scn"}]
    scripts = [p for p in files if p.suffix == ".gd"]

    scene_text = {}
    for p in scenes:
        scene_text[rel(p)] = p.read_text(encoding="utf-8", errors="replace")

    # uid -> res path, from .import and .uid and project files
    uid_map: dict[str, str] = {}
    for p in files:
        if p.suffix == ".import":
            t = p.read_text(encoding="utf-8", errors="replace")
            m = re.search(r'uid="(uid://[^"]+)"', t)
            if m:
                target = "res://" + rel(p)[:-len(".import")]
                uid_map[m.group(1)] = target
        elif p.suffix == ".uid":
            uid = p.read_text(encoding="utf-8", errors="replace").strip()
            if uid.startswith("uid://"):
                target = "res://" + rel(p)[:-len(".uid")]
                uid_map[uid] = target

    data = {
        "scenes": {},
        "scripts": {},
        "uid_map": uid_map,
    }

    for p in scenes:
        deps, _ = parse_scene_deps(p)
        base = p.parent
        resolved = set()
        for d in deps:
            if d.startswith("res://"):
                resolved.add(d)
        data["scenes"][rel(p)] = sorted(resolved)

    for p in scripts:
        data["scripts"][rel(p)] = sorted(parse_text_deps(p))

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "deps_raw.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print("scenes", len(scenes), "scripts", len(scripts), "uid", len(uid_map))


if __name__ == "__main__":
    main()
