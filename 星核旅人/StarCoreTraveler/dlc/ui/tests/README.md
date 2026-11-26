# DLC 共用 UI / 真实 J 验证记录（2026-11-25）

目录只包含 DLC 共用、可被 trial 与 rift 复用的 UI 和跨章测试。未改基础三关、
`scripts/start_menu.gd`、`project.godot`、`export_presets.cfg`、基础 assets/scripts。
未 Git 提交/推送，未导出。

## 文件

- `dlc/ui/dlc_guide.tscn` / `dlc_guide.gd`：560×236、3 页共用开场说明；
  左侧 **256×144 实机演示窗**，播放 24 帧 / 8 fps 的真实关卡循环（横向帧条 +
  `AtlasTexture`，与基础 `mechanic_popup.gd` 一致）；右侧标题+2–3 行说明+按键提示；
  右上 `n / 3`，底部 `F 下一页 · 长按空格 跳过`；打开暂停，长按空格 0.5 s
  关闭（复用 `scripts/narrative/skip_hold_bar.gd` 的 `SkipHoldBar`），Esc 吞掉，
  关闭后清输入并让关卡重新拿回 3 帧开场输入锁。切页时演示从第 0 帧重播；
  缺失帧条时显示“演示缺失”占位与文字，不显示示意图、不报错。
- `dlc/ui/demos/`：六条 6144×144 PNG（24×256×144）+ JSON：
  `trial_gate`、`trial_gate_inside`、`trial_guard_hit`、`rift_inversion`、
  `rift_bridge`、`rift_twins`。
- `dlc/ui/tools/capture_guide_demos.tscn` / `.gd`：从正式
  `trial_chambers.tscn` / `rift_workshop.tscn` 实拍上述帧条；只写
  `res://dlc/ui/demos/`。真实输入（Q/移动/物理 J）或场景自身规则；debug 只用于
  摆位和把守卫推进既有 `GRAVITY_CHARGE`。
- `dlc/ui/REFERENCE_INTRO_GUIDE.md`：Celeste tutorial / pause 两张实际画面核看记录；
  证据在 `tests/out/ref/`（`out/.gdignore`，不参与导入/打包）；外部图不是演示素材。
- `tests/guide_test.tscn` / `.gd`：两关各自动弹一次、页数、F、Esc、短按空格无效、
  长按 0.5 s 跳过、暂停/关闭、只弹一次、关闭后可移动；每页 demo id/帧数 24/8 fps、
  切页第 0 帧重播、缺失素材降级。
- `tests/real_j_damage_test.tscn` / `.gd`：真实物理 J（`Input.parse_input_event`）
  对 trial 单守卫、rift 金/青各一次，以及双守卫同一 swing 分发；
  不使用 `request_attack()` 冒充。
- `tests/capture_guide.tscn` / `.gd`：两关各 3 页 640×360 实机截图（每页等待 1.6 s，
  让演示进入动作帧）。
- `tests/j_damage_diag.*`、`tests/j_distance_diag.*`：真实 J 伤害诊断脚本与日志。

## 运行

```powershell
$godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"

# 真实 J（trial + rift）
& $godot --headless --path . res://dlc/ui/tests/real_j_damage_test.tscn

# 3 页说明页 + demo 帧条/切页/缺失降级
& $godot --headless --path . res://dlc/ui/tests/guide_test.tscn

# 重新实拍 6 条演示帧条（不要加 --headless；只写 dlc/ui/demos）
& $godot --path . --position 60,60 res://dlc/ui/tools/capture_guide_demos.tscn

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
| 开场说明页（含 demo/切页/缺失） | **81 / 0** | `guide_test.log` |
| 640×360 说明页截图 | 6 张，均 640×360 error=0 | `out/trial_guide_1..3.png`、`out/rift_guide_1..3.png` |
| 六条演示帧条 | 6 条，均 6144×144、24 帧、8 fps | `out/capture_guide_demos.log`、`../demos/*.png` + `.json` |
| 导入 | exit 0，0 SCRIPT/Parse/ERROR | `../rift_workshop/tests/import.log`、`out/import_demos_final.log` |

真实 J 实测数值：

- trial 异相 70 px 蓄力：24 物理帧被拉近 4.39 px，`get_anchor_force_x()=496.8`；
  22 px 背对守卫按真实 J → 自动转向 → `TRUE_HIT`，真伤 0→1。
- trial 同相按真实 J → `SAME_PHASE`，真伤不变；HUD 显示“同相无效 · Q 切异相再按 J”。
- rift 金：真实 J → `TRUE_HIT`，真伤 0→1；被挂起的青守卫收到同一 swing 为 `INACTIVE`。
- rift 青：真实 J → `TRUE_HIT`，真伤 0→1。
- rift 双守卫同时存活：同一真实 J 近处金 `TRUE_HIT`、远处青 `MISS_RANGE`，
  证明 hit 分发不是只结算金守卫。

说明页截图实际看到：

- trial 1/3：真实金门场景，Q 后玩家穿过；文字“Q 换辉相过金门，再 Q 回澜相过青门”；
- trial 2/3：真实青门场景，门内切相/离开后闭合；
- trial 3/3：真实守卫蓄力 + J 命中，血条 3→2；
- rift 1/3：真实紫色反转幕与玩家；
- rift 2/3：真实金桥实化/消失与下层；
- rift 3/3：双守卫同框、金守卫蓄力 + J 命中，两条血条可见。

## 局限 / 未做

- 帧条是 8 fps 采样（24 帧/3 秒），不是 60 fps 录屏；动作节奏以实际采样为准。
- 未做真人整关节奏、可读性、手柄/键位重映射终审；只按 640×360 实际渲染截图核看。
- 说明页只核看了 Celeste 两张静态 UI 画面，未核看其翻页/长按动画；外部图不作为
  演示素材。
- 真实 J 测试用 `debug_force_gravity()` 把守卫推进既有蓄力态以避开 3 s AI 周期，
  但攻击本身是真实 J 事件、命中由守卫自己的 `receive_player_hit()` 结算。
- 未改标题菜单两个 DLC 入口的视觉层级；该改动需要动 `scripts/start_menu.gd`，
  已按约束先报告、未实施。
