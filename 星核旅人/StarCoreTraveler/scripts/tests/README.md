# 本体 DLC 机制测试（2026-11-27）

## 逻辑验收（headless）

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . `
  res://scripts/tests/base_dlc_mechanics_test.tscn
```

覆盖：

- L1 出口同相门：出生点 1 s 无提示、60 px 仍无、56 px 出现完整教学
  （同相 / 日·月 / 按 Q）、撞门只留「按 Q 换相」、10 s 内不重复、
  错相阻挡（含跳跃尝试）、对相通过、Q 换回、checkpoint 仍可触发。
- L2 已删除入口反转紫幕：场景无 `InversionField`、无 `RiftInversionField` 实例；
  第一联动仓的真实 E 存档 / 符石点亮仍可完成。

## 640×360 画面证据（需要开窗）

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 `
  res://scripts/tests/capture_base_dlc_mechanics.tscn
```

输出：`screenshots/base_dlc_mechanics_20261127/`（四张，均为真实视口）：
`l1_gate_hint_56px` / `l1_gate_blocked` / `l1_gate_open` / `l2_no_veil`。

## 说明

- 门的提示只由 56 px 接近触发；开场电影期间的同类提示直接丢弃，不排队到交还控制。
- L1 的完整门教学在 HUD 事件行与门前石碑；DLC1 说明页只保留本章的金晶体与守卫，
  DLC3/DLC2 只做短提醒。
- L2 的 `PrototypePlayer.set_polarity_state()` 仍是脚本换相入口，不增加 Q 计数。
