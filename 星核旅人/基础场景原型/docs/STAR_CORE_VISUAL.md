# 星核三态纯视觉组件

更新日期：2026-10-30。本文只说明本组件、预览与独立测试，不改变玩法、地图或素材归属。

## 1. 范围

本组件用于显示星核的三种外观状态，供后续运输场景拖放使用：

- `LOCKED`：原紫色星核，带简单锁定标识。
- `POSITIVE`：金色正极星核，带加号。
- `NEGATIVE`：青色负极星核，带减号。

它是**纯视觉组件**，不包含刚体、碰撞、吸斥力、拾取、交互、星核仓或运输逻辑。状态只影响外观，测试不驱动任何玩法。

不属于本次任务：三张 PNG 的生成/调色、正式关卡布局、默认主场景接入、`progress.md`/主 README/`ASSET_CREDITS.md` 汇总。

## 2. 新增文件

| 文件 | 用途 |
| --- | --- |
| `scripts/star_core_visual.gd` | `@tool` 视觉组件；导出 `LOCKED/POSITIVE/NEGATIVE`；延迟加载 PNG；代码绘制锁定/加号/减号标识。 |
| `scenes/star_core_visual.tscn` | 可直接拖入编辑器的组件场景，根节点 `StarCoreVisual`，包含唯一子节点 `Gem`（`Sprite2D`）。 |
| `tools/preview_star_core.gd` | 640×360 三态预览、缺图状态说明、可选引擎截图。 |
| `tools/preview_star_core.tscn` | 预览入口场景。 |
| `tests/test_star_core_visual.gd` | 独立验收脚本，不修改现有测试 runner。 |
| `tests/test_star_core_visual.tscn` | 独立测试入口场景。 |
| `docs/STAR_CORE_VISUAL.md` | 本文。 |
| `screenshots/star_core_visual_preview.png` | 640×360 真实引擎预览截图；三张正式 PNG 已加载，展示 1x 与 4x 近看，不是玩法截图。 |

说明：首次运行 Godot 后，引擎会像其他脚本一样为本组件的 `.gd` 生成 `.uid` 侧车文件；它们不是人工设计文件。

## 3. 组件用法

在 Godot 编辑器中把 `scenes/star_core_visual.tscn` 拖入 2D 场景即可。组件原点位于 16×16 宝石中心，材质向外绘制在右下角。选中根节点后，在检查器修改 `state`：

- `Locked`（默认）
- `Positive`
- `Negative`

状态切换会在编辑器和运行时立即重绘对应 PNG 与标识。也可以在代码中设置：

```gdscript
var core: StarCoreVisual = preload("res://scenes/star_core_visual.tscn").instantiate()
add_child(core)
core.state = StarCoreVisual.CoreState.POSITIVE
# 或 core.set_core_state(StarCoreVisual.CoreState.NEGATIVE)
```

### 显示规则

- 三张源图固定路径：
  - `res://assets/star_core/star_core_locked.png`
  - `res://assets/star_core/star_core_positive.png`
  - `res://assets/star_core/star_core_negative.png`
- 源图必须为 16×16 透明 PNG；组件按 1:1 显示，不自动缩放，不自动重新调色。
- 根节点和 `Gem` 都使用 `TEXTURE_FILTER_NEAREST`，`Gem` 居中、无翻转、`modulate` 保持白色。
- 正/负符号和锁定图标由脚本在 16×16 宝石主体之外绘制，固定于右下角 `Rect2(9, 9, 7, 7)`，与宝石范围 `Rect2(-8, -8, 16, 16)` 不相交；不受素材图内容影响，也不会镜像。
- 组件不创建 `CharacterBody2D`、`Area2D`、`CollisionShape2D` 或任何场/吸力节点，不读取输入。

### 缺图行为

PNG 可能由另一并行任务稍后生成。组件**没有 preload 任何星核 PNG**，因此缺图时脚本仍能正常解析和加载：

- 对应状态显示中性虚线占位框，不绘制假宝石、不写入替代 PNG。
- 每张缺失路径只在控制台警告一次。
- `is_art_missing()` 返回 `true`，`get_missing_texture_path()` 给出路径。
- 图片导入后调用 `refresh()`，或切换一次状态，即可重新读取。
- 如果 PNG 尺寸不是 16×16，仍会原样 1:1 显示并警告；不会暗中缩放。

## 4. 预览

单独运行，不接入默认主场景：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core.tscn
```

预览逻辑画布与窗口均为 640×360。LOCKED / POSITIVE / NEGATIVE 横向并排，每态同时展示：

- `ACTUAL SIZE (1x)`：真实 16px 大小；
- `NEAR VIEW (4x, INTEGER SCALE)`：同尺度整数倍近看。

标签全部为 ASCII 英文，避免缺中文字体；页面明确写有 `VISUAL COMPONENT ONLY / NOT GAMEPLAY`，并注明徽标由代码绘制、不在宝石主体上、不镜像。

可选真实引擎截图：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core.tscn -- --capture-preview
```

输出 `screenshots/star_core_visual_preview.png`（640×360）后退出。若 PNG 尚未就绪，截图会如实显示中性占位与缺图状态，不会伪造正式素材。

## 5. 独立测试

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_visual.tscn
```

测试覆盖：

- 工程 640×360 与世界默认 nearest 过滤；
- 组件为 `@tool`、根为 `Node2D`、状态枚举导出与默认值；
- `Gem` 居中、1:1、nearest、不翻转、不染色；
- 组件无碰撞/区域节点；标识矩形与宝石主体不相交；
- 三状态切换路径与标识（锁定/加号/减号）；
- 缺图分支：精灵为空、报告缺图路径、不会生成替代图；
- 安全加载器对不存在路径返回 `null`；
- 预览为 640×360，6 个实例（3 态 × 1x/4x），标签全 ASCII，包含“非玩法”声明；
- 有图时额外验证三张图均为 16×16 且保留 alpha。

### 当前实测（2026-10-30）

- 三张 PNG 到位并完成 Godot 导入后，headless 测试：**100 通过、0 失败、0 跳过，退出码 0**。
- 三张 PNG 均验证为 16×16、保留 alpha；组件按状态自动换图，正/负/锁定标识切换，符号不覆盖宝石主体。
- GUI 预览捕获：`PREVIEW_CAPTURED ... size=(640, 360)`，状态为 `3/3 state PNGs loaded`，退出码 0。
- 独立测试日志：`tests/logs/star_core_visual_test.log`。

缺图分支也做过真实运行证据：三张 PNG 尚未生成时，同一测试为 **91 通过、0 失败、4 跳过，退出码 0**，并成功捕获三态中性占位预览，没有脚本解析错误或替代 PNG。PNG 到位后，全部图片相关断言转为通过。

**尚未验证**：协调者人工在编辑器中逐个拖放/检查三态，以及正式运输关卡中的同屏可读性和实际玩法效果。本组件尚未接入默认主场景。

## 6. 后续接入边界

本组件只负责“长什么样”。后续星核物理/运输/星核仓应在独立逻辑节点中实现，并设置本组件的 `state`；不要把力场、碰撞或仓逻辑塞进本组件。三张 PNG 的作者、许可与修改说明由协调者汇总到 `ASSET_CREDITS.md`，本文不替代授权记录。
