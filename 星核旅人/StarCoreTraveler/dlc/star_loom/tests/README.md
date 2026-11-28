# 星核织机测试

## 一键跑（headless）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_all.ps1
```

覆盖：开场电影契约 `intro_test`、机制 `mechanics_test`、门/星核/检查点 `gate_test`、
检查点镜面轻提示 `hidden_hint_test`、阶段 1 首轮浮灵 `core_wisp_test`、真实路线 `route_test`、说明页 `guide_test`、
标题 `title_test`，本章 90 帧、本体三关 90 帧（`base_level_90_clean` 干净收尾）。
章节页“未发现支线”页脚由 `dlc/chapter_select/tests/chapter_select_test.gd` 覆盖。

检查点之后、竞技场之前的隐藏 `镜面裂隙`（x=420）和 `resume_from_side` 主线恢复由
`dlc/hidden_levels_20261127/tests/hidden_levels_test.tscn` 覆盖；本目录的 90 帧冒烟只保证
正常开局不触发隐藏路线。

## 只能开窗跑

```powershell
# 音乐/混响/循环（需要真实音频设备与窗口）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/music_test.tscn

# 640x360 开场关键帧（真实织机厅运镜）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_intro.tscn

# 0.2 s 连续核对表所需帧（写到 tests/out/loom_opening_strip/）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_intro_strip.tscn

# 640x360 入厅机制：同相门开/关、星核入仓/拉出、检查点、阶段 1 浮灵
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 res://dlc/star_loom/tests/capture_mechanics.tscn

# 640x360 两处隐藏支线轻提示（检查点 / 章节页页脚）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 --path . \
  res://dlc/star_loom/tests/capture_hidden_hint.tscn
```

`capture_mechanics` 写到 `screenshots/loom_core_wisp_20261127/`；该目录带
`.gdignore`，不会被导入成游戏纹理。`music_test` 与截图脚本都依赖
`frame_post_draw`，headless 下不会出帧；`music_test` 已加 headless 保护，
不会挂死，但结论只在开窗时有效。

## 截图

- 当前开场证据：`screenshots/loom_opening_20261127/` 的
  `00_hall_dark_loom_silhouette.png`、`01_lamp_row_1.png`、
  `02_lamp_rows_all.png`、`03_lamp_rows_shuttle.png`、
  `04_orbs_core_lit.png`、`05_pull_back_to_player.png`、
  `06_control_returned.png`、`contact_sheet_0.2s.png`。全部为真实
  `StarLoom` + 真实 `OpeningCamera2D` 的 640×360 渲染。
- `tests/out/intro_lamp_row_1.png`、`intro_lamp_row_2.png`、`intro_lamps.png`、
  `intro_shuttle.png`、`intro_core.png` 是 2026-11-27 之前黑底另绘版的旧图，
  仅保留历史记录，不再作为本轮真实关卡运镜的证据。

## 第九轮（2026-11-27）：运送星核 + 阶段 1 浮灵提前

入口段使用星核：`CoreDeliveryCarrier`（2026-11-27 起位于
`dlc/shared/core_delivery/`，DLC2/DLC3 共用）用 `StarCoreVisual` 的
`star_core_positive_12f` 金色 12 帧（16×16，1:1）运送真星核；`RuneStoneField`
的 160 px 场、同相斥/异相吸、250–330 行程与无实体碰撞规则不变。x=330 改为
`CoreDeliveryBay`：现有 `star_core_bay_base/glass` 基座/玻璃罩 + 低石座、暗龛口、
金色核心环、槽唇和通往 x=380 月门的短导线；空仓暗、入仓基座变白/玻璃罩合上/
金环与导线亮起。星核可拉回、门关；检查点 x=410 与同相门 x=150 未动。

二次修订（同日）：这枚核实际供的是第二道月门，改为
`star_core_negative_12f` 青色澜相核；核色不随玩家 Q 变。自由核去掉外金环和
+/− 徽记，只保留切面/内芯/碎屑；金属环只留在仓体上。

浮灵：阶段 1 第一次自然攻击固定为 `summon`（`_intro_summon_pending`），只生成
1 只 44 px/s 浮灵，28×28 命中框、12 s 寿命、1 次 J 击杀不变；之后阶段 1 仍只
走 `["homing"]`，阶段 3 的召唤保留。首轮预警文案提前教「挥剑可清」。

本轮实际结果：`run_all.ps1` **12 例全部 exit=0、problems=0**；机制
**216 / 0**、门/星核/检查点 **61 / 0**、阶段 1 浮灵 **28 / 0**、路线
**37 / 0**、开场 **78 / 0**、说明页 **42 / 0**、UI 对齐 **113 / 0**、
标题 **42 / 0**；本章 90 帧与本体三关 90 帧 0 错误；`--headless --import`
0 错误。640×360 证据在 `screenshots/loom_core_wisp_20261127/`（星核未入仓、
推进中、入仓连续帧、亮起/门开、拉出/门关、阶段 1 浮灵预警/本体；每张另有
3× 最近邻细节图）。参考实看记录见 `REF_CORE_DELIVERY_20261127.md`。

## 第八轮（2026-11-27）：开场改为真实关卡运镜

`intro_test` 实际 **78 checks / 0 failures**（真实开窗额外 1 条 BGM 检查为
**79 / 0**）：真实 `OpeningCamera2D` current、真实 Core/NodeA/NodeB/Player、
首帧中心 >600 且 zoom >1.05、三排灯/真实 4 帧梭子、Boss 全程未激活、
BGM 未在片内启动、HUD 隐藏、移动/J/Q 锁定、F/长按空格跳过、拉回中跳过
立即回玩家、HUD 0.35 s 淡入、说明页 0.45 s 延迟、R/失败不重播。
`run_all.ps1` **11 例全部 exit=0、problems=0**（含 gate 48/0、mechanics 216/0、
本章 90 帧与本体三关 90 帧）。`--headless --import` 0 错误。参考记录
`dlc/star_loom/REF_OPENING_SCENE_20261127.md`。

## 第七轮（2026-11-27）：补回入厅三件本体机制

`run_all.ps1` 实际结果：机制 **216 / 0**、门/星核/检查点 **48 / 0**、
路线 **37 / 0**、说明页 **42 / 0**、UI 对齐 **113 / 0**、开场 **39 / 0**、
标题 **42 / 0**；本章 90 帧与本体三关 90 帧均 0 错误；`--headless --import`
0 错误。`base_level_90_clean` 是本次为本体三关补的干净收尾包装：跑满 90 帧后
停标题 BGM/世界音、释放场景再退出，避免 headless 的 title_theme.ogg
“resources still in use” 假错误；场景与运行帧数不变。

640×360 实证在 `screenshots/loom_mechanics_20261127/`：

- `gate_closed.png`：澜相被日门挡住，门上太阳与锁扣清晰，事件行给出辉相。
- `gate_opening_1..3.png`：0.15 s 开门连续三帧，光幕/锁扣变化，角色遮挡不跳。
- `gate_open.png`：真实 Q 后同一门打开，事件行「同相门已开 · 通过」。
- `loom_core_wisp_20261127/01_core_before_bay.png`：星核在仓外，月门未通电。
- `loom_core_wisp_20261127/03_core_seated_lit.png`：星核入仓，基座/玻璃罩/导线亮起，月门打开。
- `loom_core_wisp_20261127/04_core_pulled_door_closed.png`：真实换相把星核拉回约 20 px，仓线变暗、月门关锁。
- `checkpoint.png`：40×36 本体检查点在角色右侧完整可见并已激活。

`gate_test.gd` 用真实移动/Q 断言：错相阻挡、对相通过、星核入仓开门、星核可拉回、
走过星核不被顶出、检查点失败恢复、检查点后拉星核不锁死、R 复位。`route_test`
把这条真实路线接在完整三阶段通关之前。参考实看记录见
`dlc/star_loom/REF_MECHANICS_20261127.md`。

## 单独的“缺场景”分支

`title_missing_test` 需要先把 `star_loom.tscn` 临时改名才能跑，**不在** `run_all` 里，避免误报。
