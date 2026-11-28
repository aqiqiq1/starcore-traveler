# 说明页 / 机制弹窗演示帧条

这些帧条由正式章节场景实拍，横向 24 帧、每帧 256×144、8 fps，PNG 为
`6144×144`；同名 JSON 记录 `source`、`crop`、`camera`、`note`。加载路径是
`res://dlc/ui/demos/`，说明页与 `MechanicPopup` 共用。

## 2026-11-28 第二轮（字体/演示核对）

当前场景已是 2026-11-27 的室内工坊；旧 `rift_inversion`、`rift_bridge`、
`rift_mirror` 仍是最早的室外露台/InversionB/Q 光桥版本，已全部重录：

| 演示 | 结果 |
| --- | --- |
| `rift_inversion` | 重录。当前只有一个 `InversionA`（x=160），旧条录的是已删除的 `InversionB`（x=400）且为室外。新条：室内工坊，玩家从右向左穿过紫幕，`get_trigger_count()=1`，澜相→辉相，月门在右。 |
| `rift_bridge` | 重录。旧条是已退役的 Q 光桥 + 室外露台。新条：室内桥段，真实 J 击杀桥上的悬浮光灵 → 章节把桥标为 stable（苍白锁定核），玩家走过永久亮起的桥；无 Q、无假击杀。 |
| `rift_mirror` | 重录。旧条背景是室外露台，且没有当前双面镜的 3 形态/锚定光灵表现。新条：当前 Boss，帧 6 澜相 J 碎金面盘、帧 13 辉相 J 碎青面盘、帧 18 J 命中暴露核心；`receive_player_hit()` 真实结算，无 `debug_shatter_face`。重录时标记 `rift_mirror_tip`/`rift_core_tip` 已看，避免教学弹窗盖住演示条。 |
| `rift_core` | 重录并逐像素复核（与旧条仅 299 px 差，来自核心 12 帧动画相位）。正式场景 `FinishPoint/Core` 当前仍是 `assets/level03_prototype/key_core_12f.png`：灰岩核，**无金圈、无 +/−**。它不是 `assets/star_core/` 的新宝石核；若要求把终点核也换成新宝石素材，需要改 `rift_workshop.tscn` 的贴图（超出“重录”范围，待批准）。 |
| `loom_nodes` | 重录。正式 `star_loom.tscn`；金色/青色物体是**象牙极性节点盘**（`loom_node_city_40x40_2f.png` + 代码环/心），不是自由星核。 |
| `loom_fire` | 未重录。正式场景的 stage-2 地火/横扫预警仍与页面一致；用工具内已有的 fire 采集函数试录时会被火道教学弹窗盖住、取景偏移，故保留原条。 |
| `loom_gear` | 未重录。stage-3 齿轮/浮灵仍与页面一致；用工具内已有的 gear 采集函数试录时没有抓到齿轮滚动，保留原条。 |
| `trial_gate` / `trial_gate_inside` / `trial_guard_hit` | 未重录。用 `capture_guide_demos.tscn` 重录时，当前相机在传送后仍滞后，前几帧玩家在画外，比原条差；已恢复原条。试炼场已停用（玩家流程无入口），原条内容仍与页面一致。`trial_gate_inside` 目前没有页面/弹窗引用。 |

所有 10 条仍为 24 帧 / 256×144 / 8 fps；JSON 的 `frames`/`fps`/`frame_width`/
`frame_height`/`crop` 已逐条校验。

## 工具

- `dlc/star_loom/tools/capture_loom_demos.gd/.tscn`：默认只重录 `loom_nodes`
  （关闭开场电影）。
- `dlc/rift_workshop/tools/capture_core_demo.gd/.tscn`：重录 `rift_core`。
- `dlc/rift_workshop/tools/capture_bridge_demo.gd/.tscn`：**新增**，重录
  `rift_bridge`（真实 J 杀桥光灵 → stable → 过桥）。
- `dlc/rift_workshop/tools/capture_rift_guide_demos.gd/.tscn`：**新增**，重录
  `rift_inversion` 与 `rift_mirror`。
- `dlc/ui/tools/capture_guide_demos.gd/.tscn`：试炼三条的采集工具；本轮尝试
  重录后恢复原条（取景问题）。

运行示例（不要加 `--headless`，需要真实视口）：

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tools/capture_loom_demos.tscn
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/rift_workshop/tools/capture_core_demo.tscn
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/rift_workshop/tools/capture_bridge_demo.tscn
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/rift_workshop/tools/capture_rift_guide_demos.tscn
```

写 PNG 后必须跑一次 `--headless --import`，否则运行时会加载旧的 `.ctex`。
