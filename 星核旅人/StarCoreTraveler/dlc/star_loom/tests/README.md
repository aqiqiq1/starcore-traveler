# 星核织机测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、机制 `mechanics_test`、真实路线 `route_test`、说明页 `guide_test`、标题 `title_test`，本章 90 帧、本体三关 90 帧。

## 只能开窗跑

```powershell
# 音乐/混响/循环（需要真实音频设备与窗口）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/music_test.tscn

# 640x360 开场关键帧
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_intro.tscn
```

`music_test` 与截图脚本都依赖 `frame_post_draw`，headless 下不会出帧；`music_test` 已加 headless 保护，不会挂死，但结论只在开窗时有效。

## 截图

- `out/intro_lamp_row_1.png`：第一排顶灯亮。
- `out/intro_lamp_row_2.png`：第二排顶灯亮。
- `out/intro_lamps.png`：三排顶灯全亮。
- `out/intro_shuttle.png`：木梁轻响、梭子滑过。
- `out/intro_core.png`：两侧光球亮、中央核心点燃。

均为实际 640x360 渲染。章节在电影结束后才显示 HUD，再打开共享说明页。

## 单独的“缺场景”分支

`title_missing_test` 需要先把 `star_loom.tscn` 临时改名才能跑，**不在** `run_all` 里，避免误报。
