# DLC 共用 UI / 真实 J 验证记录（2026-11-25）

目录只包含 DLC 共用、可被 trial 与 rift 复用的 UI 和跨章测试。未改基础三关、
`scripts/start_menu.gd`、`project.godot`、`export_presets.cfg`、基础 assets/scripts。
未 Git 提交/推送，未导出。

## 文件

- `dlc/ui/dlc_guide.tscn` / `dlc_guide.gd`：560×236、3 页共用开场说明；
  左侧 160×90 代码绘制 1× 像素示意图，右侧标题+2–3 行说明+按键提示；
  右上 `n / 3`，底部 `F 下一页 · 长按空格 跳过`；打开暂停，长按空格 0.5 s
  关闭（复用 `scripts/narrative/skip_hold_bar.gd` 的 `SkipHoldBar`），Esc 吞掉，
  关闭后清输入并让关卡重新拿回 3 帧开场输入锁。
- `dlc/ui/REFERENCE_INTRO_GUIDE.md`：Celeste tutorial / pause 两张实际画面核看记录；
  证据在 `tests/out/ref/`（`out/.gdignore`，不参与导入/打包）。
- `tests/guide_test.tscn` / `.gd`：两关各自动弹一次、页数、F、Esc、短按空格无效、
  长按 0.5 s 跳过、暂停/关闭、只弹一次、关闭后可移动。
- `tests/real_j_damage_test.tscn` / `.gd`：真实物理 J（`Input.parse_input_event`）
  对 trial 单守卫、rift 金/青各一次，以及双守卫同一 swing 分发；
  不使用 `request_attack()` 冒充。
- `tests/capture_guide.tscn` / `.gd`：两关各 3 页 640×360 实机截图。
- `tests/j_damage_diag.*`、`tests/j_distance_diag.*`：本轮诊断脚本与日志，
  保留用于复现“为什么真实 J 有时打不到”。

## 运行

```powershell
$godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"

# 真实 J（trial + rift）
& $godot --headless --path . res://dlc/ui/tests/real_j_damage_test.tscn

# 3 页说明页
& $godot --headless --path . res://dlc/ui/tests/guide_test.tscn

# 640×360 六张说明页截图（不要加 --headless）
& $godot --path . --position 60,60 res://dlc/ui/tests/capture_guide.tscn

# 诊断复现（可选）
& $godot --headless --path . res://dlc/ui/tests/j_damage_diag.tscn
& $godot --headless --path . res://dlc/ui/tests/j_distance_diag.tscn
```

## 本轮结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 真实 J（trial 单守卫 / rift 金 / rift 青 / 分发） | **23 / 0** | `real_j_damage_test.log` |
| 开场说明页 | **38 / 0** | `guide_test.log` |
| 640×360 说明页截图 | 6 张，均 640×360 error=0 | `out/trial_guide_1..3.png`、`out/rift_guide_1..3.png` |
| 导入 | exit 0，0 SCRIPT/Parse/ERROR | `out/import_final.log` |
| 基础三关 + trial + rift 90 帧 | 均 exit 0，0 ERROR | 见各章 `tests/*_90.log` |
| 临时移走 `dlc/rift_workshop` 后 level_01 90 帧 | exit 0，0 ERROR | `out/level_01_deleted_rift_90.log` |

真实 J 实测数值：

- trial 异相 70 px 蓄力：24 物理帧被拉近 4.39 px，`get_anchor_force_x()=496.8`；
  22 px 背对守卫按真实 J → 自动转向 → `TRUE_HIT`，真伤 0→1。
- trial 同相按真实 J → `SAME_PHASE`，真伤不变；HUD 显示“同相无效 · Q 切异相再按 J”。
- rift 金：真实 J → `TRUE_HIT`，真伤 0→1；被挂起的青守卫收到同一 swing 为 `INACTIVE`。
- rift 青：真实 J → `TRUE_HIT`，真伤 0→1。
- rift 双守卫同时存活：同一真实 J 近处金 `TRUE_HIT`、远处青 `MISS_RANGE`，
  证明 hit 分发不是只结算金守卫。

说明页截图实际看到：

- trial 1/3：金/青门 + 玩家示意图、标题、2 行说明、按键行、页标；
- trial 2/3：同一门示意图 + 门内切相说明；
- trial 3/3：双守卫色点 + 3 格血条示意图，失败回竞技场说明；
- rift 1/3：紫色反转幕 + 两侧相性玩家示意图；
- rift 2/3：横向金/青/金光桥 + 下层安全台示意图；
- rift 3/3：双守卫色点 + 两只都要打、完整重生说明。

## 局限 / 未做

- 未做真人整关节奏、可读性、手柄/键位重映射终审；只按 640×360 实际渲染截图核看。
- 说明页只核看了 Celeste 两张静态画面，未核看其翻页/长按动画；多页节奏沿用
  本项目 `mechanic_popup.gd` 的既定交互。
- 真实 J 测试用 `debug_force_gravity()` 把守卫推进既有蓄力态以避开 3 s AI 周期，
  但攻击本身是真实 J 事件、命中由守卫自己的 `receive_player_hit()` 结算。
- 未改标题菜单两个 DLC 入口的视觉层级；该改动需要动 `scripts/start_menu.gd`，
  已按约束先报告、未实施。
