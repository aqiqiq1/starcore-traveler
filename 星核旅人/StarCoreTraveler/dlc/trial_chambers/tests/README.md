# 试炼场测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\trial_chambers\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、门与晶体 `gate_test`、真实路线 `route_test`、标题 `title_test`、暂停标题 `pause_title_test`、环境 `ambience_test`，本章 90 帧、本体三关 90 帧。

## 只能开窗跑

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/trial_chambers/tests/capture_intro.tscn
```

## 截图

- `out/intro_crystal_gold.png`：金晶体先亮，青晶体仍暗。
- `out/intro_crystals.png`：金/青晶体依次点亮完成。
- `out/intro_lock.png`：日/月门锁旋转、核心亮起。
- `out/intro_light_pullback.png`：门缝透光并拉开到左侧玩家。

均为实际 640x360 渲染。电影本体由 `trial_intro_cinematic.tscn` 绘制；章节在 `_ready` 中先播电影，结束后再打开共享说明页。
