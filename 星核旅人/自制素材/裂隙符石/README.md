# 裂隙符石 · 概念原图直接转换版

状态：**按用户“就要预览图刚才那样的裂口像素化”的要求，重新从已批准概念 sprite 直接生成；待用户实机复审，不称美感已通过**。本轮没有修改玩法、力、碰撞、地图、场景节点位置、角色或星核参数。

## 本轮为什么重做

上一版 r3 保留了旧 528 px 壳轮廓，又自行画了 8 段分支来“适配 32 px”，和批准的 96 px 概念形态不是同一块石头，因此被用户明确拒绝。本版删除了这条重画路线：

- **唯一外观来源**：`自制素材/符石概念示意/generate_concept.py` 的 `sprite('sleep'/'gold'/'cyan')`。
- **不裁整张概念图**：没有读取或裁切 1600×1000 的 `concept.png`，只调用 96×96 的 `sprite()`。
- **不重画**：没有新的 OUTLINE、CRACKS、GAPS、壳片、光晕或随机点；脚本中不含任何绘制逻辑。
- **直接转换**：96×96 三态 → 32×32 NEAREST（精确 3:1，目标像素中心采样），保留概念自带的裂口、内芯、内壁、金/青反光和壳缘高光。

## 对照图与 32 px 结论

- 对照图：`preview_concept96_vs_direct32.png`（每态左侧 96 px 源图 ×6，右侧直接 32 px ×18）。
- 已实际读图核对：三态的主裂口连线、交汇位置、壳片分块与批准 96 px 图一一对应；32 px 仍能读出完整的分叉网络和露芯口。
- 32 px 的必然损失：3:1 采样会把极少数 96 px 外缘小尖角压缩成 1–2 px 的孤立亮/暗点，这是直接 NEAREST 的像素事实，不是重画；没有为了“更好看”改路径。
- 因此本轮继续使用 32 px 原生图，没有改用 48/96 px 原生图，也没有以放大贴图伪装 32 逻辑尺寸。若用户要求连 96 px 的每一个单像素外缘尖角都保留，才需要另批更大原生尺寸；本轮未这样做。

## 文件

| 文件 | 规格 | 用途 |
| --- | --- | --- |
| `rune_stone_sleep.png` | 32×32 RGBA | 概念 `sleep` 直接转换：暗芯、同一壳与裂纹网络、无金/青光 |
| `rune_stone_gold.png` | 32×32 RGBA | 概念 `gold` 直接转换：金芯、内壁和金色反光 |
| `rune_stone_cyan.png` | 32×32 RGBA | 概念 `cyan` 直接转换：青芯、内壁和青色反光 |
| `rune_stone_sleep_96.png` 等 | 96×96 RGBA | 概念 `sprite()` 原图副本，放在 `source_96/`，仅作来源核对 |
| `preview_concept96_vs_direct32.png` | 1224×2044 RGB | 批准 96 px ×6 vs 直接 32 px ×18，三态并排 |
| `preview_rune_stone_states.png` | 640×360 RGB | 三态 5× + 1× 联系表，由本次 32 px 图生成 |
| `generate_rune_stone_assets.py` | Python + Pillow | 仅导入概念脚本、保存 96 源图、直接 NEAREST 到 32、自检和写 manifest |
| `manifest.json` | JSON | 尺寸、转换法、逐态 SHA256、验证统计 |
| `README.md` | 本文件 | 来源、显示架构、接入与验证边界 |

工程实际只复制三张 32×32 状态图到 `基础场景原型/assets/rune_stone/`；旧的 `rune_stone_shell.png`、`rune_stone_crack_mask.png` 及其 `.import` 已移除，避免旧两层资产继续被误引用。

## 工程显示架构

`scripts/rune_stone_visual.gd` 仍保持原有公开行为：

- `@export polarity_positive: bool = true`
- `@export energized: bool = true`
- `@export show_polarity_hint: bool = false`
- `@export transition_duration: float = 0.22`
- `func set_polarity(positive: bool, immediate: bool = false)`
- `signal transition_finished(positive: bool)`
- `nearest` 过滤、32×32 逻辑尺寸、`-16..16` 石体矩形、石外 `+/-` 提示、暂停冻结和结束才提交的时机均未变。

显示改为两层 Sprite2D：

- `Base`：始终显示 `sleep` 状态图，提供概念原样的暗芯和壳面。
- `Accent`：显示 `gold` 或 `cyan` 整态图；休眠时 `alpha=0`，静止亮态 `alpha=1`。换极时旧图先暗出，再换目标图暗入；`get_accent_strength()` 返回当前 alpha。
- 因为 gold/cyan 图本身包含概念的金/青内芯、内壁反射和高光，不再需要用“壳 + 白遮罩运行时 tint”去近似；三态轮廓逐像素同形（32 px 下均为 535 个不透明像素）。
- 兼容旧调用：`get_shell_sprite()` 仍返回暗态底层，`get_crack_sprite()` 仍返回亮态上层；新代码应使用 `get_base_sprite()` / `get_accent_sprite()`。

## F2 / F7 接入

- F7 `polarity_record_test_room.tscn` 的现有 `RuneStoneField` 继续复用 `rune_stone_visual.tscn`：初始 `initial_active=false` 显示 sleep 暗芯、零力；记录/脉冲后先暗后亮，视觉结束才提交激活或变极；R 清记录复原，取核保持规则不变。
- F2 `anchor_room.tscn` 在固定 `(320, 200)` 复用同一 `rune_stone_visual.tscn`，固定 GOLD；进入 160 px 范围在石外显示 `+`。力、遮挡、碰撞体数量、起落点、成功条件均未改。
- 两房只换视觉资源/组件内部实现，没有改任何房 `.tscn`、角色、星核、力或地图逻辑。

## 重建与自检

只使用项目指定环境：

```powershell
D:\minic\envs\2024212971\python.exe generate_rune_stone_assets.py
```

脚本自检（本次实测）：

- 三态 `concept.sprite()` 均为 96×96，且重复调用逐字节一致；
- 保存的 96 源图与 `sprite()` 返回图逐像素一致；96 不透明像素 4807；
- 32 输出与独立实现的直接 NEAREST 采样逐字节一致；32 不透明像素 535，三态 alpha 轮廓完全相同；
- `sleep` 在 accent 半径 55 内没有金/青像素；gold/cyan 各有 29 个 accent-family 像素；
- 每对状态有 147 个像素不同（金↔青、金↔暗、青↔暗）；
- 输出 SHA256 写入 `manifest.json`；独立复核也验证了 `source_96 = sprite()`、`32 = 直接 NEAREST`、工程副本 = 32 输出，日志见 `基础场景原型/tests/logs/rune_stone_concept_fidelity_python.log`。

把三张 32×32 PNG 复制到 `基础场景原型/assets/rune_stone/` 后，删除旧 `.ctex` 缓存并执行：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" --import
```

## 预览与实机截图

独立预览：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_rune_stone_art_revision.tscn
```

捕获：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_rune_stone_art_revision.tscn -- --capture-art-revision
```

本轮真实引擎截图（均重新导入后生成，非旧缓存）：

- `基础场景原型/screenshots/rune_stone_art_revision.png`：三态 4× + 1×，暗/金/青。
- `基础场景原型/screenshots/rune_stone_visual_preview.png`：旧 640×360 视觉预览，已更新为三态直接转换版。
- `基础场景原型/screenshots/anchor_01_entry.png`、`anchor_02_field_debug.png`：F2 固定 GOLD 实景与 F3 范围/力线。
- `基础场景原型/screenshots/record_01_initial_no_history.png`、`record_03_cyan_stone_live.png`：F7 暗芯与首次暗→青完成后的实景；另有 record_02/04。
- 捕获日志：`基础场景原型/tests/logs/art_revision_concept_capture.log`、`rune_stone_preview_concept_capture.log`、`anchor_concept_capture.log`、`record_concept_capture.log`。

F2/F7 截图使用现有 `capture_anchor.tscn` / `capture_polarity_record.tscn`，只更新说明文字，不改变捕获脚本的玩法路径。对石体 56×56 裁剪区做像素抽查：F2 GOLD 有 15 个近 `#f4cd63` 像素，F7 完成态有 11 个近 `#5fe1e6` 像素，F7 休眠态金/青均为 0；三张实景确实显示对应概念状态，不是旧图或占位。

## 回归测试

本轮实测（Godot 4.7.2 headless）：

| 测试 | 结果 | 日志 |
| --- | --- | --- |
| `test_rune_stone_visual.tscn` | **208 / 0 / 0** | `tests/logs/rune_stone_visual_test.log`；终端副本 `rune_stone_visual_concept_test.log` |
| `test_rune_stone_field.tscn` | **229 / 0** | `tests/logs/rune_stone_field_test.log`；终端副本 `rune_stone_field_concept.log` |
| `test_polarity_record.tscn` | **210 / 0 / 0** | `tests/logs/polarity_record_test.log`；终端副本 `polarity_record_concept.log` |
| `test_runner.tscn` | **316 / 0** | `tests/logs/runner_concept.log` |
| `test_polarity_link_visual.tscn` | **118 / 0 / 0** | `tests/logs/polarity_link_visual_concept.log` |

视觉测试更新了过时的“两图层/白遮罩”结构断言，但没有弱化行为：inactive 无金/青光且零力、同色首次激活仍先暗后亮、暂停冻结、结束才发 `transition_finished`、R/取消/过期回调仍由 field/record 测试覆盖。测试还对比导入纹理与三张源 PNG 的可见像素，防止缓存旧图。

## 许可与边界

- 三张状态图完全来自项目已批准的概念 sprite；本目录只做原样保存和 96→32 NEAREST 转换，没有第三方图片、下载或外部生成服务。
- 概念图 `concept.png`、概念脚本和批准图未修改。
- 角色预览只引用工程现有角色 PNG；背景只引用工程现有遗迹背景，均不改原图。
- 是否采纳由用户复审；本轮只完成忠实转换、接入和回归，不声称已通过美感验收。
