# 试炼场测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\trial_chambers\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、门与晶体 `gate_test`、真实路线 `route_test`、标题 `title_test`、暂停标题 `pause_title_test`、环境与音乐 `ambience_test`，本章 90 帧、本体三关 90 帧（clean teardown）。

## 只能开窗跑

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 res://dlc/trial_chambers/tests/capture_intro.tscn
```

## 截图（2026-11-27 真实关卡运镜）

输出到 `screenshots/trial_opening_20261127/`：

- `00_gate_real_wide.png`：真实 `GateGold`（x=280）近景，太阳牌与锁未亮，两侧真实晶体暗。
- `01_crystals_and_lock.png`：金晶体先亮、青晶体后亮；锁环开始转。
- `02_seam_light_pool.png`：门缝暖光落在真实地面，形成光池。
- `03_pull_to_player.png`：镜头拉远，入口处真实玩家进入画面。
- `04_control_returned.png`：结束后相机交还玩家、HUD 淡入。
- `05_same_gate_in_gameplay.png`：普通玩法取景下的同一道门，用于核对「门是不是关卡里那道门」。

均为实际 640x360 渲染。影片本体是 `trial_intro_cinematic.tscn` 的 Node2D；它用真实 `OpeningCamera2D` 和真实门/晶体/地面/玩家，不再绘制黑底替身。章节在 `_ready` 中先播电影，结束后留一个短交还节拍再打开共享说明页。
