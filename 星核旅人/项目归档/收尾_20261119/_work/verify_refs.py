"""Post-change verification: file existence, hashes, dangling res:// references."""
import csv
import hashlib
import json
import re
from pathlib import Path

R = Path(r"D:\godot game\星核旅人\基础场景原型")
OUT = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")
RES = re.compile(r'res://[^"\'\s\)\]]+')


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


problems = []

# 1) renamed assets: exists + same hash
rows = list(csv.DictReader(open(OUT / "asset_rename_map.csv", encoding="utf-8-sig")))
for r in rows:
    new = r["new_path"].replace("res://", "")
    p = R / new
    if not p.exists():
        problems.append(f"RENAMED MISSING {new}")
    elif sha256(p) != r["sha256"]:
        problems.append(f"HASH CHANGED {new}")
    old = r["old_path"].replace("res://", "")
    old_parent = (R / old).parent
    if old_parent.exists() and old in {q.as_posix().replace(R.as_posix() + "/", "") for q in old_parent.iterdir()}:
        problems.append(f"OLD STILL EXISTS {old}")

# 2) archived files: gone from project, present in archive
arch = list(csv.DictReader(open(OUT / "archive_manifest_20261119.csv", encoding="utf-8-sig")))
for r in arch:
    old = r["old_project_path"].replace("res://", "")
    dst = Path(r["archive_path"])
    if (R / old).exists():
        problems.append(f"ARCHIVED STILL IN PROJECT {old}")
    if not dst.exists():
        problems.append(f"ARCHIVE TARGET MISSING {dst}")
    elif sha256(dst) != r["sha256"]:
        problems.append(f"ARCHIVE HASH CHANGED {dst}")

# 3) dangling res:// references in active project files
scanned = 0
for p in sorted(R.rglob("*")):
    if not p.is_file() or p.suffix.lower() not in {".gd", ".tscn", ".scn", ".json", ".cfg", ".tres"}:
        continue
    parts = p.relative_to(R).parts
    if ".godot" in parts or "项目归档" in parts:
        continue
    try:
        text = p.read_bytes().decode("utf-8")
    except UnicodeDecodeError:
        continue
    scanned += 1
    for m in RES.finditer(text):
        ref = m.group(0).rstrip('.,;')
        rel = ref[len("res://"):]
        if not (R / rel).exists():
            problems.append(f"DANGLING {p.relative_to(R).as_posix()} -> {ref}")

# 4) old asset names anywhere in active text (excluding historical evidence dirs)
OLD_NAMES = [
    "male_hero-idle.png", "male_hero-walk.png", "male_hero-run.png",
    "male_hero-jump.png", "male_hero-fall.png", "male_hero-fall_loop.png",
    "male_hero-combo_1.png", "male_hero-combo_1_end.png",
    "gate_portal_fx_v2_8f.png", "polarity_switch_v2.wav", "swing_v2.wav",
    "shell_shatter_heavy_v2.wav", "audio_charge_v2.ogg", "audio_slam_v5.ogg",
    "layered_linked_candidate_base_200x60.png",
    "layered_linked_candidate_active_200x60.png",
    "layered_linked_candidate_mask_200x60.png",
    "layered_linked_candidate_arrival_200x60.png",
    "layered_linked_candidate_facetid_200x60.png",
]
for p in sorted(R.rglob("*")):
    if not p.is_file() or p.suffix.lower() not in {".gd", ".tscn", ".scn", ".json", ".cfg", ".html", ".py"}:
        continue
    parts = p.relative_to(R).parts
    if ".godot" in parts or "项目归档" in parts or "screenshots" in parts:
        continue
    try:
        text = p.read_bytes().decode("utf-8")
    except UnicodeDecodeError:
        continue
    for name in OLD_NAMES:
        if name in text:
            # individual_sheets/ holds the untouched originals; a provenance
            # pointer to them is correct and must keep the original filename.
            for line in text.splitlines():
                if name in line and "individual_sheets" not in line:
                    problems.append(f"OLD NAME {name} in {p.relative_to(R).as_posix()}")
                    break

report = {
    "renamed": len(rows),
    "archived": len(arch),
    "scanned_text_files": scanned,
    "accepted_exceptions": [
        {
            "path": "screenshots/ds03_capture_manifest.json",
            "reason": "历史验收 manifest 仍以 res://tests/logs/... 指向已归档日志；日志原样保存在 "
            "非运行资料/历史测试与证据/tests/logs/（相对结构不变）。未改证据文件，恢复 tests/ 即可解析。",
        }
    ],
    "problems": [p for p in problems if "ds03_capture_manifest.json" not in p],
}
(OUT / "verify_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
print("renamed", len(rows), "archived", len(arch), "scanned", scanned)
print("problems", len(report["problems"]))
for pr in report["problems"][:60]:
    print("  ", pr)
