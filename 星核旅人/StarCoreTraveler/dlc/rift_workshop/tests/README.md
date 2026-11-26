# 裂隙工坊测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\rift_workshop\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、机制 `mechanics_test`、真实路线 `route_test`、打磨 `polish_test`、标题 `title_test`，本章 90 帧、本体三关 90 帧。

## 只能开窗跑

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/rift_workshop/tests/capture_intro.tscn
```

## 截图

- `out/intro_eye_closed.png`：镜心仍是暗缝，链条在暗处。
- `out/intro_eye_opening.png`：镜面眼睑初开，瞳孔仍小。
- `out/intro_eye_open.png`：瞳孔放大，金/青面盘开始亮。
- `out/intro_plates_wave.png`：两面盘全亮，相位波扫过地面。

均为实际 640x360 渲染。镜框与两面盘使用本章 Boss 的现有精灵；眼睛、链条与相位波为程序化绘制。

## 单独的“缺场景”分支

`title_missing_test` 需要先把 `rift_workshop.tscn` 临时改名才能跑，**不在** `run_all` 里。
