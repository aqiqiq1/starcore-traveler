"""Resolve runtime audio/asset paths that are built from a directory constant.

demo_audio.gd uses {dir?, file} entries; the other audio scripts use one DIR
constant plus an array of basenames. Each resolved path is checked on disk.
"""
import re
from pathlib import Path

R = Path(r"D:\godot game\星核旅人\基础场景原型")
problems = []
checked = []

# --- demo_audio.gd ---------------------------------------------------------
p = R / "scripts/audio/demo_audio.gd"
text = p.read_bytes().decode("utf-8")
consts = dict(re.findall(r'const\s+(\w+)\s*:\s*String\s*=\s*"(res://[^"]*/)"', text))
for m in re.finditer(r'EVENT_\w+:\s*\{(.*?)\}', text):
    body = m.group(1)
    f = re.search(r'"file":\s*"([^"]+)"', body)
    d = re.search(r'"dir":\s*(\w+)', body)
    if not f:
        continue
    base = consts[d.group(1)] if d else consts["RUNTIME_DIR"]
    target = base.replace("res://", "") + f.group(1)
    checked.append(target)
    if not (R / target).exists():
        problems.append("demo_audio: " + target)

# --- single-DIR scripts with basename arrays -------------------------------
for rel in [
    "scripts/audio/player_footstep_audio.gd",
    "scripts/narrative/opening_cinematic.gd",
    "scripts/narrative/dialogue_voice.gd",
]:
    p = R / rel
    text = p.read_bytes().decode("utf-8")
    dirs = re.findall(r'const\s+\w*DIR\w*\s*:\s*String\s*=\s*"(res://[^"]*/)"', text)
    if len(dirs) != 1:
        problems.append(f"{rel}: expected exactly one DIR constant, got {dirs}")
        continue
    base = dirs[0].replace("res://", "")
    names = re.findall(r'"([^"/]+\.(?:wav|ogg))"', text)
    for n in names:
        target = base + n
        checked.append(target)
        if not (R / target).exists():
            problems.append(f"{rel}: {target}")

print("dynamic paths checked:", len(checked))
print("problems:", len(problems))
for pr in problems:
    print("  ", pr)
