# 星核仓真实记录 → 关联符石测试房

更新：2026-10-31。范围是“仓数据 + 联动控制 + 测试房集成”，不是正式谜题、门、出口或三关系统。

## 入口

- 从默认主场景按 **F7** 进入独立测试场景；测试场景内再按 **F7** 回主场景。F7 使用换场景，不把新房间塞进 Main。
- 编辑器中直接打开 `scenes/polarity_record_test_room_standalone.tscn`，按 **F6** 运行。
- 房间本体 `scenes/polarity_record_test_room.tscn` 可单独拖入其他场景，但需要像 standalone 一样提供 `PrototypePlayer` 和 `PrototypeHUD`，并调用 `activate()`。

## 操作与可复现路线

- A/D 或方向键走，左 Shift 跑，空格跳，Q 只切玩家极性，E 主动释放/存入，R 恢复测试房初始状态，Esc 暂停，F3 显示核心/符石范围与力方向。
- 初始：起始仓内有预装紫色核，**无历史记录**；关联仓空；玩家 GOLD +。关联符石 `initial_active = false`，保持同一石壳与同一个暗裂纹，不显示正负提示、不产生力；HUD 与链接标签写 **INACTIVE**，不把内部默认正极假称成已激活 GOLD。
- 推荐路线：
  1. 走到起始仓左侧，按 E 释放。释放瞬间星核取玩家极性相反值（此例 CYAN -）。
  2. 可故意在开罩期间按 Q，确认玩家变了而核快照不变；需要运输时再切回 GOLD 吸引。
  3. 把核带到右侧关联仓（LINKED）座位，按 E 存入。记录在 E 接受瞬间读取**活动核自己的**极性；本例记录 CYAN -，即使玩家是 GOLD +。
  4. 观察记录灯立即变青；短光脉冲飞向符石。此时符石仍是 INACTIVE，对玩家的力精确为零。脉冲到达后符石才开始“暗裂纹 → 目标颜色”的首次亮起；亮起视觉结束的同一刻才真正激活并提交实际力。
  5. 首次亮起中途站在符石范围内，F3 只显示范围与中性采样点，不画假受力箭头；HUD 仍为 INACTIVE。激活完成后才出现真实力箭头与 ATTRACT/REPEL。
  6. 站到符石左侧安全地面，先看 F3 力方向；再按 Q 切玩家极性，实际吸/斥应反向。核心存仓时符石力仍作用于玩家，但不作用于核。
  7. 再从关联仓按 E 取出。记录灯和符石保持最近值，不因取出恢复初始；符石继续保持激活与最近极性。
  8. 用不同极性的核再次存入同一仓：记录灯在 E 接受时改写，脉冲后符石改成新值。符石已经激活时，相同极性再次存入仍是有效记录/反馈，不会卡住请求，也不会重播石色；**首次**存入若恰好等于内部默认正极，仍必须完整执行首次亮起并激活，不能按旧“同极性 no-op”卡住。
  9. 若上一条脉冲/首次亮起尚未走完就接受更新记录，旧符石请求会被取消，旧回调不能把石激活；新脉冲到达后再从暗或当前已提交颜色完成最新目标。
  10. 按 R：清空两仓记录、取消在途脉冲/亮起、符石回 `initial_active = false` 的暗裂纹未激活状态；等待后也不应有旧请求落下。F7 离开再进入同样从干净未激活状态开始。

## 数据与生效时点

1. E 有效存入被接受 → `StarCoreBayInteractable.start_store_core(core_positive)` 同步写入该仓记录并发出 `polarity_recorded(positive)`。
2. `BayRuneLink` 立即把记录灯切到真实值；这发生在脉冲到达之前。灯只表示仓记录，不表示符石已经生效。
3. 已有 `PolarityLinkVisual.play_transfer()` 脉冲开始；它不再负责“到了才让仓记住”。
4. 脉冲到达 → `BayRuneLink` 调用 `RuneStoneField.request_polarity()`。
5. 未激活符石收到请求后进入首次亮起：`sample_field()` 始终返回 `INACTIVE` 与精确零力，直到 `RuneStoneVisual` 从暗裂纹亮到目标色并发出 `transition_finished`。这时字段才 `is_activated() == true`、提交实际极性并发出一次 `polarity_committed`。
6. 已激活符石换到异极时，仍沿用旧力直到新视觉结束；同极请求仍是 no-op。激活态之外，`is_positive()` 只是内部默认值，HUD/链接必须同时检查 `is_activated()`。
7. 房间每物理帧把“玩家—核”对玩家力与“关联符石对玩家力”相加，通过唯一一次 `player.apply_external_force()` 应用；核只接收玩家—核对力，符石不吸/斥核。
8. 取出核不清记录、不重置符石。只有下一次有效 E 存入覆盖记录，R 恢复未激活。

旧的 `start_store()` 无参调用仍可用，但只启动合罩、不伪造记录；正式房间路径调用 `start_store_core()` 并传入活动核的 `is_positive()`。开罩/合罩期间按 Q、暂停、长按 E 都不会重读快照。

## 场景可编辑项

- `TerrainBody` / `CollisionShape2D`：连续地面碰撞，拖动即可改高度/宽度。
- `Bays/StartBay`、`Bays/TargetBay`：仓位置、`bay_name`、交互半径、座位范围、开合时长；`TargetBay` 在本房间即关联仓。
- `Core`、`PlayerSpawn`：初始核位置与玩家出生点。
- `RuneField`：`RuneStoneField` 实例。本测试房显式 `initial_active = false`；可改 `initial_positive`、范围、内径、满力半径、外缘、加速度与调试显示。普通固定石保持 `initial_active = true`。
- `PolarityLink`：`PolarityLinkVisual` 实例；`source_path` 指向关联仓，`target_path` 指向符石，线/灯偏移和脉冲时长可调。
- `LinkController`：`BayRuneLink` 实例；`bay_path`、`field_path`、`link_visual_path` 均以 NodePath 连接。
- 地形、仓、符石、出生点、关联 NodePath 都在场景中可见可调，不需要运行时生成整张地图。

## 验证

独立测试：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_polarity_record.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_rune_stone_field.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_rune_stone_visual.tscn
```

本轮结果：

- 记录集成 **210 通过、0 失败、0 跳过**，日志 `tests/logs/polarity_record_test.log`（原 160 条保留并更新初始 INACTIVE 预期，新增首次两种颜色、亮起中零力、同色二次存、取核保持、R/重进在途复位、HUD/提示、旧回调等断言）。
- `RuneStoneField` **229 通过、0 失败**，日志 `tests/logs/rune_stone_field_test.log`（原 159 条保留，新增 inactive/首次亮起/覆盖/取消/暂停用例）。
- 裂隙符石视觉 **175 通过、0 失败、0 跳过**，日志 `tests/logs/rune_stone_visual_test.log`（原 146 条保留，新增 energized/暗裂纹/首次亮起用例）。
- 联动视觉 **118 通过、0 失败、0 跳过**，日志 `tests/logs/polarity_link_visual_test.log`（回归，未改组件）。
- 星核交互 **207 通过、0 失败、0 跳过**，日志 `tests/logs/star_core_interaction_test.log`（受影响回归通过）。
- 主 runner **314 通过、0 失败**，日志 `tests/logs/headless_test.log` / `tests/logs/last_run.log`（回归通过）。

覆盖：真实 InputMap/60 Hz 的释放→行走→E 存入、记录属于具体仓、核与玩家极性不同时只记核、记录灯先于脉冲、首次脉冲/亮起期间 INACTIVE 与精确零力、亮起结束才激活并出现真实吸/斥、首次目标与内部默认同色仍激活、同色二次存不挂、取核保持激活、不同极性覆盖、暂停冻结、更新记录取消旧首次亮起、R 在脉冲中/亮起中清理、长按 E 只记一次、无自动捕获、合力相加不覆盖、核不受符石影响、切房/重进清理、唯一核。

## 截图

`tools/capture_polarity_record.tscn` 用 GUI Godot 捕获 4 张真实引擎视口静帧：

- `screenshots/record_01_initial_no_history.png`：初始石为 INACTIVE，暗裂纹、无正负提示、HUD INACTIVE。
- `screenshots/record_02_store_cyan_lamp_immediate.png`：E 接受后灯立即变青，脉冲在途，符石仍未激活、零力。
- `screenshots/record_03_cyan_stone_live.png`：首次暗→青亮起完成，符石激活为 CYAN，F3 范围与真实力箭头。
- `screenshots/record_04_overwrite_gold_live.png`：第二次存入覆盖记录，符石亮起并提交 GOLD。

说明见 `screenshots/MANIFEST_RECORD.txt`。这些是**脚本驱动的真实 60 Hz 物理静帧**，不是录像，也不是人工试玩；不能当作手感验收。

## 未验证 / 边界

- 未做人工连续键盘试玩与编辑器内拖放微调；自动断言和静帧不等于手感/可读性认可。
- 这是单屏沙盒，不是正式谜题；没有门、出口、三关、目标仓校准条件或存档。记录只存在本次运行中，R/重进清空。
- 用 F7 在主场景和测试场景之间切换会重新加载场景，因此不保留在场状态；这是有意的测试入口，不扩展正式房间架构。
- 已激活后的相同极性再次存入时，记录灯和脉冲仍有反馈；`RuneStoneField` 对相同目标极性按自身设计不重播换色，故没有“第二次同色动画”，这不影响实际力/记录正确性。首次同色存入不同，会完整亮起并激活。
- 关联仓与符石相距约 240 px，站在仓旁时符石通常已在范围外；需要走进右侧受力区观察吸/斥。这是测试布局，不是正式关卡平衡结论。
