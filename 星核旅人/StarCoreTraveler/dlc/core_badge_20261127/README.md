# core_badge_20261127

2026-11-27 第二次“星核/标识”修正的可复现资料。只改素材与标识，不改玩法数值。

> 2026-11-28 更新：六章结算徽记已改为金/青双面镜（带眼），由 `dlc/shared/side_route/mirror_face_art.gd` 运行时绘制。本目录的城门徽记 PNG 与生成器仅作历史资料保留，不再被结算页引用。

## 文件

- `gen_completion_emblem.py`：确定性生成 32×32 结算城门徽记
  `assets/ui/icons/completion_gate_emblem_32.png`。
- `capture_core_badge.gd/tscn`：真实 640×360 + 最近邻 4× 证据，输出到
  `screenshots/core_badge_20261127/`。
- `verify_core_badge.gd/tscn`：40 项 headless 断言（无 +/– 节点、无外环、
  DLC2/DLC3 青核=月门、L3 装置新 12 帧、徽记不是守卫/星核）。
- `REFERENCE_20261127.md`：外部/项目内参考实看记录与未核实项。
- `original/`：本轮改写前的星核 PNG 备份（`.gdignore`，不参与导入）。

## 复现命令

```powershell
D:/minic/envs/2024212971/python.exe dlc/core_art_20261127/gen_core_assets.py
D:/minic/envs/2024212971/python.exe dlc/core_badge_20261127/gen_completion_emblem.py
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://dlc/core_art_20261127/verify_core_art.tscn --quit-after 300
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://dlc/core_badge_20261127/verify_core_badge.tscn --quit-after 600
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 res://dlc/core_badge_20261127/capture_core_badge.tscn
```

## 边界

- 不改推/拉力、速度、相性判定、门/仓状态机或关卡坐标。
- 星核仍是 16×16、12 帧、1:1；设备/仓仍用原尺寸。
- 自由核不画外金环、不带 +/−；仓体金环保留。
- 第三方参考只在本机 `references/`/项目 `screenshots/hud_refs/`，没有进入运行资产。
