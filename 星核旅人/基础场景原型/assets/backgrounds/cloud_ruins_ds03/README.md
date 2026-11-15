# DS03 云海遗迹动态背景（第一关运行资源）

来源：`自制素材/云海遗迹背景动态修复_DS03`（只读）。本目录的 24 张 PNG 是源目录 `art_assets/` 8 张 + `common/` 16 张的逐字节副本，没有调色、重画、缩放或重新量化 PNG。

- 画布：640×360 逻辑；DS03 参考画布为 2× device（1280×720）。
- 层序：base sky → 7 张天空云 → G3/G4/G5 → G1/G2 → sea_main + shadow_central/cluster → arch_stone → sea_near + shadow_low → rock_remnants_static → 4 组浮石。
- **G1/G2 整座桥绝对固定**，包括柱、梁、墩、拱；两桥都在 `sea_main` 之前，没有 `island_overlay`/右桥旧静态云回盖。
- **G3/G4/G5 轻浮**：公式幅度 0.35/0.30/0.45，周期 18/22/20 s，相位 0.8/1.1/0.15。
- 天空云 +右 3.6/6.2 px/s；主/近云海 +右 4.2/7.2 px/s，周期 1278 px；海面两份相邻绘制，接缝连续。
- `rock_remnants_static` 在运行时跳过 local `(41,155)-(45,157)` 的 5 px 旧小斑；源 PNG 不改。
- 浮石、投影、投影随高低、云面 clip 均按 DS03。

## 原生 Godot 量化

DS03 网页预览在 1280×720 device 画布上使用 0.5 逻辑 px 位置。Godot 工程原生是 640×360 viewport，全局 2D pixel snap 开启，因此 0.5 逻辑 px 没有原生像素可落。

组件对 G3/G4/G5 使用两个相邻原生像素：

- 公式值 ≥ -0.25（中性/正半周）→ 0 px；
- 公式值 < -0.25（网页负半周）→ -1 px；
- 实际峰峰值 **1 逻辑 px**，周期仍是 18/22/20 s；网页正半周的 +0.5 状态没有原生对应。

这不是把幅度放大到 ±1；G1/G2 仍精确固定。云/海/天空使用整数原生位置，单向运动和 1278 px 周期保持。

## 运行时接入

- 组件场景：`res://scenes/backgrounds/cloud_ruins_ds03.tscn`
- 脚本：`res://scripts/backgrounds/cloud_ruins_ds03.gd`
- 生成数据：`res://scripts/backgrounds/cloud_ruins_ds03_data.gd`（由 `tools/import_ds03_background.py` 从 `runtime_config.json` 生成，不要手改）
- 第一关：`scenes/level_01.tscn` 的 `Background/CloudRuinsDS03`；`CloudRuinsV7` 与旧 Sky/FarRuins/NearRuins/Mist/PitCloud 仅保留并隐藏。
- 编辑器：`@tool` 组件只画 t=0 静态预览，不跑动画。
- 运行：连续推进；Esc 暂停冻结；R 通过玩家既有 `reset_performed("level_restart")` 归零；重载从 t=0 开始。
- 纯视觉：没有 CollisionObject/Area2D/Control，不参与遮挡、触发或输入。

## 验证

```powershell
# headless：24 图哈希/导入像素/配置/时钟逻辑；若 headless 会明确跳过渲染项
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_ds03_background.tscn

# GUI：同一专项的实际渲染检查（桥固定、岛微动、云单向/周期/接缝、遮挡、阴影 clip）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_ds03_background.tscn

# 纯背景 + 第一关脚本定帧截图
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_ds03_background.tscn
```

投影两个子 `CanvasItem`（`ShadowsMain`/`ShadowsNear`）已纳入与父层相同的逐帧刷新列表；`tests/test_ds03_shadow_refresh.tscn` 在不切可见性的正常场景中实测 5.625 s 时两个阴影 draw 回调均重执行，普通帧与强制重绘参考帧 0 像素差，暂停不推进、恢复后继续，t=0 帧哈希前后一致。

`runtime_config.json` 与 `source_manifest.json` 是源参数/哈希的追溯副本；运行时不逐帧读取它们，也不每帧重建 CPU 图像。
