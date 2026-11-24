"""Build the per-scene keep/archive inventory CSV.

Scenes still in the project come from the live reachability closure; archived
scenes come from archive_manifest_20261119.csv so the inventory stays complete
after the move.
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
OUTDIR = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")
WORK = OUTDIR / "_work"

reach = json.loads((WORK / "reachability_full.json").read_text(encoding="utf-8"))
deps = json.loads((WORK / "deps_raw.json").read_text(encoding="utf-8"))
keep = set(reach["reachable_files"])
keep_scenes = reach["reachable_scenes"]

archived = [
    r["old_project_path"].replace("res://", "")
    for r in csv.DictReader(open(OUTDIR / "archive_manifest_20261119.csv", encoding="utf-8-sig"))
    if r["old_project_path"].endswith((".tscn", ".scn"))
]

reverse: dict[str, list[str]] = {}
for src in sorted(keep):
    for d in deps["scenes"].get(src, []) + deps["scripts"].get(src, []):
        p = d.replace("res://", "").rstrip(".,;")
        reverse.setdefault(p, []).append(src)


def category(scene: str) -> tuple[str, str]:
    if scene.startswith("tests/"):
        return "test_harness", "历史/当前回归测试场景，游戏运行不加载；随测试组整体归档"
    if scene.startswith("tools/"):
        return "capture_tool", "截图/预览采集工具场景，游戏运行不加载；随工具场景组归档"
    if scene.startswith("previews/"):
        return "preview_capture", "预览采集场景，游戏运行不加载"
    if scene == "scenes/main.tscn":
        return "sandbox_hub", "旧沙盒主场景（project.godot 入口已是 level_01）；仅被独立测试场景引用，非运行回退路径"
    if scene.startswith("scenes/polarity_record_test_room"):
        return "sandbox_room", "极性记录独立测试房，仅 main.tscn / 测试使用"
    if scene.startswith("scenes/star_core_interaction"):
        return "sandbox_room", "星核交互独立测试房，仅 main.tscn / 测试使用"
    if scene.startswith("scenes/tutorial_stele"):
        return "sandbox_room", "教学石碑独立示例场景，正式关用 guide_echo/level_guide，不实例化此场景"
    if scene.startswith("scenes/star_core_bay_interactable"):
        return "sandbox_room", "星核仓交互原型场景；正式关用 level02_bay/star_core_carrier，类脚本 star_core_bay_interactable.gd 保留"
    if scene.startswith("scenes/enemies/"):
        return "sandbox_room", "独立敌人演示场景；正式第三关用 scenes/level03/guard.tscn"
    if scene.startswith("scenes/experiments/"):
        return "sandbox_room", "极性魔像实验场景；正式第三关用 scenes/level03/guard.tscn"
    return "unknown", "未分类"


rows = []
for s in keep_scenes:
    up = sorted(set(reverse.get(s, [])))
    rows.append(
        {
            "scene_path": s,
            "decision": "KEEP",
            "category": "runtime",
            "reason": "在 res://scenes/level_01.tscn 依赖闭包内（含 autoload/三关导航/实例化/动态加载/class_name）",
            "upstream": " | ".join(up),
        }
    )
for s in archived:
    cat, reason = category(s)
    if cat == "test_harness":
        upstream = "tests/ 组内引用一并移动（场景+脚本+uid+日志+manifest）"
    elif cat == "capture_tool":
        upstream = "tools/ 采集场景与专用脚本组内引用一并移动"
    elif cat == "preview_capture":
        upstream = "该 previews/ 目录整组移动"
    else:
        upstream = "main.tscn 沙盒组内引用（同组房间场景/脚本一并移动）"
    rows.append(
        {
            "scene_path": s,
            "decision": "ARCHIVE",
            "category": cat,
            "reason": reason,
            "upstream": upstream,
        }
    )

rows.sort(key=lambda r: (r["decision"] != "KEEP", r["scene_path"]))
csv_path = OUTDIR / "scenes_inventory.csv"
with csv_path.open("w", encoding="utf-8-sig", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["scene_path", "decision", "category", "reason", "upstream"])
    w.writeheader()
    w.writerows(rows)

print("scene rows", len(rows), "keep", len(keep_scenes), "archive", len(archived))
