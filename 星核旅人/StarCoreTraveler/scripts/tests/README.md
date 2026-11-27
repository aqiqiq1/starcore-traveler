# 本体 DLC 机制测试（2026-11-27）

## 逻辑验收（headless）

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . `
  res://scripts/tests/base_dlc_mechanics_test.tscn
```

覆盖：

- L1 出口同相门：错相阻挡（含跳跃尝试）、对相通过、Q 换回、checkpoint 仍可触发。
- L2 入口反转紫幕：进入翻一次、停留不重复、离开再进入才再翻、HUD 事件行、
  第一联动仓的真实 E 存档 / 符石点亮。

## 640×360 画面证据（需要开窗）

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 `
  res://scripts/tests/capture_base_dlc_mechanics.tscn
```

输出：`screenshots/base_dlc_mechanics_20261127/`（四张，均为真实视口）。

## 说明

- 两处机制直接复用已批准的
  `res://dlc/trial_chambers/polarity_gate.tscn` 与
  `res://dlc/rift_workshop/rift_inversion_field.tscn`，没有新增美术或 UI。
- L2 的 `PrototypePlayer.set_polarity_state()` 是脚本换相入口，不增加 Q 计数，
  因此紫幕不会冒充一次真实 Q。
