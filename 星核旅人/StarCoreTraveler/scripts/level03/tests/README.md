# 第三关 · 固定生命条验证（2026-11-27）

第三关的受击显示已从玩家头顶的护符碎片改为共享红色分段血条：
`PlayerHealthBar` 2 格，固定 (14,324)，格子 14×8 / gap 2，
填充 `#d95757`、末格 `#ff7b7b`、空槽 `#211214`；上方「生命值」12 px
at (14,310)。暂停、机制弹窗、失败恢复与结算都会隐藏条和标签。

## 运行

```powershell
$godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . res://scripts/level03/tests/health_bar_test.tscn
& $godot --path . --position 60,60 res://scripts/level03/tests/capture_health_bar.tscn
```

## 结果

- `health_bar_test.tscn`：**23 / 0**。覆盖样式 bar、2 格、14×8/gap 2、
  (14,324)、红色、12 px 标签、不跟随玩家、暂停隐藏/恢复、恢复黑幕隐藏、
  结算隐藏、真实 `guard.player_struck` 受击掉到 1 格与 0 格。
- `capture_health_bar.tscn`：640×360、error=0。真实按住右走进守卫视野后
  触发一次已受理受击，保存 `out/health_bar_hit.png`；暂停页保存
  `out/health_bar_pause.png`（条与标签均不可见）。
- 汇总记录：`dlc/UI_HEALTH_BAR_ROLLOUT_20261127.md`。
