#!/usr/bin/env python3
"""Static resource-path audit for the StarCoreTraveler project.

Scans .gd/.tscn/.tres/.cfg under the project root (excluding .godot, archives)
for res:// literals in preload(), load(), ResourceLoader.load/exists,
Image.load, and tscn ext_resource paths. Reports every literal that has no
matching file on disk. Also reports audio paths that are runtime-guarded.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
EXCLUDE_DIRS = {".godot", "项目归档", "__pycache__"}

PATTERNS = [
    re.compile(r'preload\(\s*["\'](res://[^"\']+)["\']'),
    re.compile(r'\bload\(\s*["\'](res://[^"\']+)["\']'),
    re.compile(r'ResourceLoader\.(?:load|exists)\(\s*["\'](res://[^"\']+)["\']'),
    re.compile(r'Image\.load(?:_from_file)?\(\s*["\'](res://[^"\']+)["\']'),
    re.compile(r'\[ext_resource[^\]]*?path="(res://[^"]+)"'),
]

missing: list[tuple[str, int, str]] = []
literals = 0
files = 0
exts = {".gd", ".tscn", ".tres", ".cfg", ".godot"}

for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
    for name in filenames:
        if Path(name).suffix.lower() not in exts:
            continue
        path = Path(dirpath) / name
        files += 1
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.splitlines(), 1):
            for pat in PATTERNS:
                for match in pat.finditer(line):
                    literal = match.group(1)
                    literals += 1
                    target = ROOT / literal[len("res://"):]
                    if not target.exists():
                        missing.append((str(path.relative_to(ROOT)), lineno, literal))

print(f"scanned_files={files} res_literals={literals} missing={len(missing)}")
for rel, lineno, literal in missing:
    print(f"MISSING {rel}:{lineno} {literal}")

# Audio literals that are runtime-guarded (not preload consts) are listed for
# the missing-audio behavior check.
guarded: list[str] = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
    for name in filenames:
        if Path(name).suffix != ".gd":
            continue
        path = Path(dirpath) / name
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(r'ResourceLoader\.(?:load|exists)\(\s*["\'](res://[^"\']+\.(?:ogg|wav|mp3))["\']', text):
            guarded.append(str(path.relative_to(ROOT)) + " -> " + match.group(1))
print(f"runtime_guarded_audio_sites={len(guarded)}")
for line in sorted(set(guarded)):
    print("GUARDED " + line)

sys.exit(1 if missing else 0)
