#!/usr/bin/env python3
"""Read a Godot 4.4+ .pck and verify remaps/imports resolve inside the pack.

No export is performed. The PCK is opened read-only.
"""
from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

pck_path = Path(sys.argv[1])
project_root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None

data = pck_path.read_bytes()
magic, pack_version, major, minor, patch, flags, file_base = struct.unpack_from(
    "<IIIIIIQ", data, 0
)
assert magic == 0x43504447, hex(magic)
dir_offset = struct.unpack_from("<Q", data, 32)[0]
print(f"pck={pck_path.name} version={pack_version} godot={major}.{minor}.{patch} flags={flags} file_base={file_base} dir_offset={dir_offset}")
pos = dir_offset
file_count = struct.unpack_from("<I", data, pos)[0]
pos += 4
entries: dict[str, tuple[int, int]] = {}
for _ in range(file_count):
    path_len = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    raw = data[pos:pos + path_len]
    pos += path_len
    path = raw.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
    offset, size = struct.unpack_from("<QQ", data, pos)
    pos += 16
    pos += 16  # md5
    pos += 4   # flags
    entries[path] = (offset, size)

print(f"packed_files={file_count}")
print("first_paths:")
for p in list(entries)[:5]:
    print("  " + p)
print("last_paths:")
for p in list(entries)[-5:]:
    print("  " + p)


def read_entry(path: str) -> bytes:
    offset, size = entries[path]
    start = file_base + offset
    return data[start:start + size]


remap_targets: dict[str, str] = {}
broken_remaps: list[tuple[str, str]] = []
for path in entries:
    if not path.endswith(".remap"):
        continue
    text = read_entry(path).decode("utf-8", errors="replace")
    target = ""
    for line in text.splitlines():
        if line.startswith("path="):
            target = line.split("=", 1)[1].strip().strip('"')
            break
    if not target:
        broken_remaps.append((path, "no path="))
        continue
    target_rel = target[len("res://"):] if target.startswith("res://") else target
    remap_targets[path] = target_rel
    if target_rel not in entries:
        broken_remaps.append((path, target_rel))
print(f"remaps={len(remap_targets)} broken_remaps={len(broken_remaps)}")
for src, target in broken_remaps[:20]:
    print(f"  BROKEN {src} -> {target}")

import_dest: dict[str, list[str]] = {}
broken_imports: list[tuple[str, str]] = []
for path in entries:
    if not path.endswith(".import"):
        continue
    text = read_entry(path).decode("utf-8", errors="replace")
    match = re.search(r"dest_files\s*=\s*(\[[^\]]*\])", text)
    dests: list[str] = []
    if match:
        try:
            dests = json.loads(match.group(1))
        except json.JSONDecodeError:
            broken_imports.append((path, "bad dest_files json"))
            continue
    else:
        # Exported .import files are rewritten as a [remap] block with path=.
        for line in text.splitlines():
            if line.startswith("path="):
                dests = [line.split("=", 1)[1].strip().strip('"')]
                break
        if not dests:
            broken_imports.append((path, "no dest_files/path"))
            continue
    resolved: list[str] = []
    for dest in dests:
        dest_rel = dest[len("res://"):] if dest.startswith("res://") else dest
        resolved.append(dest_rel)
        if dest_rel not in entries:
            broken_imports.append((path, dest_rel))
    import_dest[path] = resolved
print(f"imports={len(import_dest)} broken_import_dests={len(broken_imports)}")
for src, target in broken_imports[:20]:
    print(f"  BROKEN_IMPORT {src} -> {target}")

if project_root is not None:
    excluded = ("/tests/", "/tools/", "screenshots/", "art_audit_", "项目归档")
    source_files: list[Path] = []
    for pattern in ("*.tscn", "*.tres", "*.gd", "*.ogg", "*.wav", "*.png", "*.ttf"):
        for path in project_root.rglob(pattern):
            rel = path.relative_to(project_root).as_posix()
            if any(x in "/" + rel for x in excluded) or rel.startswith("dlc/art_audit"):
                continue
            source_files.append(path)

    absent: list[str] = []
    for path in source_files:
        rel = path.relative_to(project_root).as_posix()
        if rel in entries or (rel + ".remap") in entries or (rel + ".import") in entries:
            continue
        absent.append(rel)
    print(f"project_files_not_packed={len(absent)} of {len(source_files)}")
    for p in absent[:60]:
        print("  NOT_PACKED " + p)
