# 说明页 / 机制弹窗演示帧条

这些帧条由正式章节场景实拍，横向 24 帧、每帧 256×144、8 fps，PNG 为
`6144×144`；同名 JSON 记录 `source`、`crop`、`camera`、`note`。加载路径是
`res://dlc/ui/demos/`，说明页与 `MechanicPopup` 共用。

## 2026-11-28 重录

| 演示 | 结果 |
| --- | --- |
| `loom_nodes` | 用正式 `star_loom.tscn` 重录。录制时关闭开场电影，避免黑场/电影轨道环混入。底下的金色物体是**极性节点**（`assets/city/loom_node_city_40x40_2f.png` + 代码绘制的环/心），不是自由星核；画面与 2026-11-26 版逐像素一致。 |
| `loom_core` | **已删除** PNG / JSON / `.import`。它只服务已移除的入口/核心教学弹窗；运行时与说明页现在只用 `loom_nodes` 与 `loom_gear`，没有 `loom_core` 演示引用（`UI_PARITY_SPEC.md` 仍保留一行历史记录）。 |
| `rift_core` | 用正式 `rift_workshop.tscn` 重录（关闭开场电影、唤醒 Boss 的自身崩塌时钟）。实拍对象仍是场景当前的 `assets/level03_prototype/key_core_12f.png`，所以画面与旧版逐像素一致；要显示新星核必须改 `rift_workshop.tscn` 的 `FinishPoint/Core` 贴图，属于游戏素材变更，按 2026-11-28 指示**未改**，待批准。 |

`loom_fire`、`loom_gear`、`trial_*`、`rift_inversion`、`rift_bridge`、`rift_mirror`
本轮没有重录，保持原样。

## 工具

- `dlc/star_loom/tools/capture_loom_demos.gd/.tscn`：本轮只重录 `loom_nodes`；
  已关闭开场电影。`loom_core` 的采集路径随旧弹窗一起删除。
- `dlc/rift_workshop/tools/capture_core_demo.gd/.tscn`：重录 `rift_core`；
  已适配 2026-11-27 开场电影与 Boss 悬挂状态。
- `dlc/ui/tools/capture_guide_demos.gd/.tscn`：恢复为试炼三条的采集工具；
  旧裂隙 Q 桥/双守卫路径已退役，改由裂隙章节自己的工具采集。

运行示例（不要加 `--headless`，需要真实视口）：

```powershell
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tools/capture_loom_demos.tscn
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/rift_workshop/tools/capture_core_demo.tscn
```
