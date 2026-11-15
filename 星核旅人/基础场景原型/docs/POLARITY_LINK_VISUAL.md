# 极性关联纯视觉组件（仓记录灯 → 短脉冲 → 符石换色）

更新日期：2026-10-31。本文只说明本轮获批的**纯视觉演示**：仓的记录极性如何被表现为一盏小金/青记录灯、一条克制细光路和一段从仓到符石的短脉冲，以及预览中收到完成信号后调用 `RuneStoneVisual.set_polarity()` 的演示接线。

> **状态：视觉原型，等待用户查看；不是玩法定稿。**
> 未实现真实仓记录、星核入仓数据读取、力场联动、取核后的恢复规则、符石实际功能或正式关卡。`record_positive` 只是显示值；`play_transfer()` 只播放动画。

## 1. 范围与边界

本轮只做：

- 在现有 32×32 星核仓旁叠加一盏程序绘制的小记录灯，金正/青负，带小 `+`/`-`；
- 从仓底座外侧到目标符石画一条 1 px 虚线符文光路；
- 一段 5 px 量级的短脉冲沿光路从 source 移到 target；到点后发出完成信号；
- 预览在收到 `visual_delivery_finished` 后动态调用并行任务的 `RuneStoneVisual.set_polarity(positive, false)`，展示符石裂隙短暗再亮；
- 独立测试、真实 GUI 截图和底图像素负对照。

明确未做、也不得由本文推断为已实现：

- 不读取或写入真实星核仓状态；
- 不记录“星核入仓前的极性”到任何数据；
- 不修改力场、吸引/排斥范围、玩家极性或星核物理；
- 不决定取核后符石恢复预设极性还是保持最近状态；
- 不新增碰撞、交互、拾取、投掷或关卡目标；
- 不修改 `player.gd`、`main.gd`、`star_core_bay_visual.gd`、既有仓 PNG、既有场景或既有测试；
- 不把符石颜色变化当作实际力场或玩法效果。

## 2. 文件

| 文件 | 用途 |
| --- | --- |
| `scripts/polarity_link_visual.gd` | `@tool class_name PolarityLinkVisual`，纯视觉灯/光路/脉冲与完成信号。 |
| `scenes/polarity_link_visual.tscn` | 可拖入编辑器的组件场景；`z_index=4`，Nearest。 |
| `tools/preview_polarity_link.gd` | 640×360 独立视觉预览、SPACE 演示、4× 灯检查、可选截图与像素检查。 |
| `tools/preview_polarity_link.tscn` | 预览入口。 |
| `tests/test_polarity_link_visual.gd` | Headless 验收测试，含动态加载符石场景的可选集成检查。 |
| `tests/test_polarity_link_visual.tscn` | 测试入口。 |
| `screenshots/polarity_link_visual_preview.png` | 真实引擎 640×360 截图；不是玩法截图。 |

## 3. 视觉设计

### 3.1 记录灯

记录灯由组件 `_draw()` 绘制，**不改任何 PNG**。默认相对 source 原点的顶左为 `(-24, 7)`，尺寸 7×9：

- 深色金属小壳、顶部/底部边框、右侧 1 px 挂耳；
- 5×5 镜片：记录正极为金色 `#f4cd63`，负极为青色 `#5fe1e6`；
- 镜片内以深色画 3×3 `+` 或 3 px `-`；
- 放在 32×32 仓体左侧，和底座左缘保持 1 px 空隙；不覆盖底座 PNG，也不覆盖既有 4×3 锁定标识；
- **不使用紫色代表记录极性**。紫色仍只属于仓内既有 `StarCoreVisual` 的 LOCKED 星核。

灯在 1× 即可辨认；预览右侧用两个真实 `PolarityLinkVisual` 实例放大 4× 检查金/青与符号，不是另画一张替代图标。

### 3.2 光路与脉冲

- 默认从 source 原点 `+(17, 12)` 出发，即仓右缘外 1 px，不从底座上起笔；target 默认可配置。
- 二次曲线，默认向上拱 8 px（`link_arc_height = -8`），1 px 虚线，低透明度；每隔一段加一个 3 px 小十字刻度。
- 常态光路用当前记录极性淡着色；传递时脉冲用被传递极性亮色，形成方向可读的短拖尾。
- 脉冲由程序在 `_draw()` 里计算，**不实例化粒子、节点或 Tween**；重复播放不会累计场景节点。
- 到点后仅有约 0.18 秒的 5 px 到达闪点，不产生永久大范围发光，也不是粗激光。
- 所有坐标绘制前 round 到整数像素，根节点和相机保持 1×，Nearest。

### 3.3 层级与底座可见性

- 组件根：`z_index = 4`，高于既有仓的 Base/LockMark=1、Core=2、Glass=3。
- 记录灯在仓体矩形外侧，不靠负 z 去“压”到底座下面。
- 预览截图脚本直接检查实际底图像素；隐藏 Base 做负对照，防止再次出现 `z=-1` 导致白底座消失的缺陷。

## 4. API

```gdscript
signal visual_delivery_finished(positive: bool)

@export var record_positive: bool
@export var source_path: NodePath
@export var target_path: NodePath
@export var source_position: Vector2
@export var target_position: Vector2

func play_transfer(positive: bool) -> void
func stop_transfer() -> void
```

辅助/测试接口：

- `advance_transfer(delta)`：固定时间步推进，正常运行时由 `_process` 调用；树暂停时同样冻结。
- `is_transfer_active()`、`get_transfer_progress()`、`get_transfer_polarity()`、`get_last_delivered_positive()`。
- `get_link_source_point()`、`get_link_target_point()`、`get_pulse_position()`、`get_pulse_color()`。
- `get_record_lamp_rect()`、`get_record_lamp_lens_rect()`、`get_record_lamp_bracket_rect()`、`get_record_lamp_accent_color()`、`get_record_symbol()`。

### 4.1 坐标

- `source_path` / `target_path` 优先：若指向树内 `Node2D`，用其全局位置换算到本组件局部坐标。
- 路径为空或不可解析时，使用 `source_position` / `target_position`（**本组件局部坐标**）作为后备。
- `link_source_offset`、`link_target_offset` 与 `record_lamp_offset` 都是本组件空间的像素偏移；默认值适合 32×32 仓。
- `@tool` 场景在编辑器中可摆放。组件会在编辑器里检查 source/target 几何变化并重绘；移动节点后不必重新加载脚本。

### 4.2 播放语义

- `play_transfer(positive)` 从 source 重新开始；`record_positive` **不会立即改变**，直到到达 target。
- 若正在传递时再次调用，**最后一次调用生效**：旧请求被放弃并从 source 重新出发；旧状态不会补发完成信号。
- 到达 target 时，先把 `record_positive` 更新为最终极性，再 emit 一次 `visual_delivery_finished(positive)`；回调里再启动新请求不会覆盖新请求状态。
- `stop_transfer()` 放弃请求，不发完成信号，不改 `record_positive`。
- 树暂停时进度和到达闪点都冻结；`advance_transfer()` 显式检查暂停。
- 组件只动画和发信号，不保存真实仓/符石状态。

## 5. 预览

运行：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_polarity_link.tscn
```

捕获真实引擎截图：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_polarity_link.tscn -- --capture-preview
```

预览固定 640×360，并明确标注 `VISUAL ONLY / NOT GAMEPLAY / NO BAY STATE, FORCE, OR RECOVERY RULE`。

操作：

- `SPACE`：发送与当前记录灯相反的极性；传递中再按会翻转最新请求并从头开始，用于演示“最后请求生效”；
- `P`：暂停/恢复；组件冻结；
- `R`：复位为金色记录、停止传递、符石恢复正极（若已加载）；
- `ESC`：退出。

画面内容：

- 左侧 1× 场景：现有 `StarCoreBayVisual`（含旋转紫锁定星核）、代码绘制的记录灯、光路和短脉冲；
- 右侧 4× 检查：真实的金/青记录灯实例；
- 底部实时状态：当前记录、传递极性/百分比、目标模式；
- 目标符石通过 `ResourceLoader.exists("res://scenes/rune_stone_visual.tscn")` 动态判断并 `load()`，**不 preload 尚不存在的资源**。存在且贴图已导入时实例化真实 `RuneStoneVisual`；不存在或缺图时明确显示 `PENDING` / `ART MISSING` 和说明文字，不显示假符石，也不调用 `set_polarity()` 冒充完成。`set_polarity` 只在实际收到 `visual_delivery_finished` 后调用。
- 预览不包含角色比例参照；本轮以仓本身 32 px 尺寸为主，不额外引入角色素材。

截图状态：捕获时故意冻结在传递中段，显示“当前记录仍金、脉冲为青、目标符石此时仍为金裂”的可读对比；完成后的短暗再亮由交互预览和测试验证，不由这张静帧冒充全过程。

## 6. 验证

运行测试：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_polarity_link_visual.tscn
```

本轮结果：

- 组件/预览 Headless 测试：**118 通过、0 失败、0 跳过，退出码 0**（日志 `tests/logs/polarity_link_visual_test.log`）。
- 覆盖：source/target 节点路径与位置后备的对齐、默认 7×9 灯在仓体左侧 1 px 且不碰底座/锁标、金/青调色板、SPACE 输入确实启动预览传递、source→target 方向、半程/四分之三位置、完成信号只发一次且携带正确极性、重复调用最后请求生效、旧请求不发信号、树暂停/固定步进冻结、停止不发信号、重复触发不增加节点、预览 640×360/非玩法文案/4× 灯实例、动态符石场景的集成检查。
- 并行符石场景已出现后，测试实际进入 `mode=rune`，`PREVIEW_DELIVERY positive=false target=set_polarity`，并检查到 `RuneStoneVisual.polarity_positive == false` 与 `is_transitioning() == true`；说明预览确实调用了 `set_polarity(false, false)`，短暗再亮的后续视觉由该并行组件的自身实现负责。
- GUI 截图/像素检查：`PREVIEW_CAPTURED ... size=(640, 360)`；`gold_lamp=304`、`cyan_lamp=336`、`main_lamp=19`、`pulse=5`、`base_light=189`，`ok=true`；隐藏主仓 Base 的负对照 `base_light=9`、检查失败。说明底座真实可见、金/青记录灯、1× 主场景记录灯和青脉冲都被实际 viewport 像素观察到。日志 `tests/logs/polarity_link_preview_capture.log`。
- 截图：`screenshots/polarity_link_visual_preview.png`。

尚未验证：

- 真实人工连续按 SPACE/P/R 的手感与长时间运行；
- 在编辑器中实际拖放 source/target 节点后的视觉微调（脚本已具备 @tool 重绘）；
- 正式仓数据、取核恢复、力场联动和正式关卡接入，这些未实现也不在本轮授权内；
- 若并行符石素材在最终集成前被替换，预览需要重新跑一次并复查截图。

## 7. 来源与归属

- 星核与仓体：沿用工程既有 `StarCoreVisual` / `StarCoreBayVisual` 与既有 PNG，本轮未修改原图、未新增星核 PNG。
- 记录灯、光路、脉冲、4× 检查框：本轮程序化绘制，无第三方素材、无外部生成服务。
- 目标符石：来自并行任务的 `res://scenes/rune_stone_visual.tscn` 及其既有 PNG；本组件不复制、不改写其素材。预览只在资源和贴图可用时实例化并调用其公开视觉 API。
- `progress.md`、工程 `ASSET_CREDITS.md` 由协调者汇总；本文不替代正式署名表。
