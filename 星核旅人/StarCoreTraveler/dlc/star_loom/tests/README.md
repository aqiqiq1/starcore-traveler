# 星核织机测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、机制 `mechanics_test`、门/石/检查点 `gate_test`、
真实路线 `route_test`、说明页 `guide_test`、标题 `title_test`，本章 90 帧、
本体三关 90 帧（`base_level_90_clean` 干净收尾）。

## 只能开窗跑

```powershell
# 音乐/混响/循环（需要真实音频设备与窗口）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/music_test.tscn

# 640x360 开场关键帧
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_intro.tscn

# 640x360 入厅机制：同相门开/关、符文石上槽/拉回、检查点
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_mechanics.tscn
```

`capture_mechanics` 写到 `screenshots/loom_mechanics_20261127/`；该目录带
`.gdignore`，不会被导入成游戏纹理。`music_test` 与截图脚本都依赖
`frame_post_draw`，headless 下不会出帧；`music_test` 已加 headless 保护，
不会挂死，但结论只在开窗时有效。

## 截图

- `out/intro_lamp_row_1.png`：第一排顶灯亮。
- `out/intro_lamp_row_2.png`：第二排顶灯亮。
- `out/intro_lamps.png`：三排顶灯全亮。
- `out/intro_shuttle.png`：木梁轻响、梭子滑过。
- `out/intro_core.png`：两侧光球亮、中央核心点燃。

均为实际 640x360 渲染。章节在电影结束后才显示 HUD，再打开共享说明页。

## 第七轮（2026-11-27）：补回入厅三件本体机制

`run_all.ps1` 实际结果：机制 **216 / 0**、门/石/检查点 **48 / 0**、
路线 **37 / 0**、说明页 **42 / 0**、UI 对齐 **113 / 0**、开场 **39 / 0**、
标题 **42 / 0**；本章 90 帧与本体三关 90 帧均 0 错误；`--headless --import`
0 错误。`base_level_90_clean` 是本次为本体三关补的干净收尾包装：跑满 90 帧后
停标题 BGM/世界音、释放场景再退出，避免 headless 的 title_theme.ogg
“resources still in use” 假错误；场景与运行帧数不变。

640×360 实证在 `screenshots/loom_mechanics_20261127/`：

- `gate_closed.png`：澜相被日门挡住，门上太阳与锁扣清晰，事件行给出辉相。
- `gate_opening_1..3.png`：0.15 s 开门连续三帧，光幕/锁扣变化，角色遮挡不跳。
- `gate_open.png`：真实 Q 后同一门打开，事件行「同相门已开 · 通过」。
- `stone_socket.png`：符文石在 x≈330 槽内，槽唇/金线亮，月门打开。
- `stone_pulled_back.png`：真实换相把石拉回约 20 px，槽线变暗、月门关锁。
- `checkpoint.png`：40×36 本体检查点在角色右侧完整可见并已激活。

`gate_test.gd` 用真实移动/Q 断言：错相阻挡、对相通过、石上槽开门、石可拉回、
走过石头不被顶出、检查点失败恢复、检查点后拉石不锁死、R 复位。`route_test`
把这条真实路线接在完整三阶段通关之前。参考实看记录见
`dlc/star_loom/REF_MECHANICS_20261127.md`。

## 单独的“缺场景”分支

`title_missing_test` 需要先把 `star_loom.tscn` 临时改名才能跑，**不在** `run_all` 里，避免误报。
