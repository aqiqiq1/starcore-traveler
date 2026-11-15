# 星核仓首版纯视觉组件

更新日期：2026-10-31。本文只说明本轮星核仓首版视觉组件、素材、预览与独立测试；不改变玩法、地图或既有素材归属。

> **状态：原型首版，等待用户视觉反馈；不是最终美术定稿。**
> 只做静态外观和可复用的程序化罩动画；不包含存取交互、碰撞、吸力或仓状态机。玩法层的开合/入仓状态由 `StarCoreBayInteractable` 负责，不属于本组件。

## 1. 范围

组件按同一原点叠四层，显示 32×32 侧视星核仓：

| 层 | 节点 | z_index | 内容 |
| --- | --- | --- | --- |
| 后 | `Base` | 1 | 32×32 白/暖白石质底座，灰蓝阴影，少量金符文。 |
| 后 | `LockMark` | 1（Base 之后的独立子节点） | 代码绘制 4×3 金色锁定小标识，不烘焙进 PNG。 |
| 中 | `Core` | 2 | 工程既有 `StarCoreVisual`，16×16 原紫 `LOCKED`；关闭右下角 badge。 |
| 前 | `Glass` | 3 | 32×32 浅青半圆钟形玻璃，内部清透。 |

**渲染层级修正：** 所有 z_index 均为非负相对值。`Base=1`、`LockMark=1`、`Core=2`、`Glass=3`；`LockMark` 在树顺序上位于 `Base` 之后，因此在底座之上、核心/玻璃之下。之前 `Base=-1` 会在预览/UI Control 自己的背景绘制之后被遮住，只剩玻璃、核心和悬空锁标；现在底座已可靠显示。不要把 `Base` 改回负 z。

组件是**纯视觉**：没有 `CharacterBody2D`、`Area2D`、`CollisionShape2D`、吸力、拾取、仓储状态机或输入处理。`occupied` 只控制核心和锁定标识的显示/隐藏；`start_open`/`start_close` 只驱动玻璃罩的视觉遮罩，不声称已实现仓状态机。

## 2. 文件

| 文件 | 用途 |
| --- | --- |
| `assets/star_core_bay/star_core_bay_base.png` | 32×32 底座后层。 |
| `assets/star_core_bay/star_core_bay_glass.png` | 32×32 同原点玻璃前层。 |
| `assets/star_core_bay/star_core_bay_empty.png` | 32×32 空仓组合图（base+glass），可直接拖用。 |
| `scripts/star_core_bay_visual.gd` | `@tool` 组件；导出 `occupied`、`show_lock_marker`；管理四层与显示开关。 |
| `scripts/star_core_bay_lock_mark.gd` | `@tool` 独立锁定标识绘制节点；4×3 金色小锁，不烘焙。 |
| `scenes/star_core_bay_visual.tscn` | 可直接拖入编辑器的组件场景（Base/LockMark/Core/Glass）。 |
| `tools/preview_star_core_bay.gd` | 640×360 空/满仓 1×/4× 预览、主角 1× 比例参照、可选截图与底图像素检查。 |
| `tools/preview_star_core_bay.tscn` | 预览入口场景。 |
| `tests/test_star_core_bay_visual.gd` | 独立 headless 验收脚本。 |
| `tests/test_star_core_bay_visual.tscn` | 独立 headless 测试入口场景。 |
| `tests/test_star_core_bay_render.gd` | GUI 渲染像素检查；含“隐藏底座必须失败”的负对照。 |
| `tests/test_star_core_bay_render.tscn` | GUI 渲染测试入口场景（非 headless）。 |
| `screenshots/star_core_bay_preview.png` | 640×360 真实引擎预览截图，不是玩法截图。 |
| `screenshots/star_core_lid_keyframes.png` | 六个 4× 实时实例的罩动画关键帧，不是后期拼图。 |
| `screenshots/MANIFEST_LID.txt` | 关键帧来源、方向和像素检查结果。 |

素材生成脚本、README、manifest 和对比评审图在项目根目录 `自制素材/星核仓/`。

## 3. 几何

图像坐标以 32×32 左上角为 (0,0)，组件原点在 (16,16)：

- 底座：y=24..31；主体 x=4..27，顶板/底脚 x=2..29。
- 既有星核：16×16，组件内 (0,0)，图像 x=8..23、y=8..23。
- 星核底边 y=23，底座顶面 y=24：不重叠；核心不压底座。
- 玻璃：半圆帽外半径 15、中心 (15.5,16)、顶 y=1；短直壁到 y=23；封圈 y=24。
- 玻璃在星核整块 16×16 内 alpha=0：核心完整透出。
- 锁定标识：图像 x=20..23、y=27..29，位于底座正面右侧，不与星核相交。

### 半圆与 32×32 的取舍

严格正半圆在 32×32 内无法容纳“16 px 核心 + 有厚度的白底座”：正半圆顶部收得太快，核心顶部会越出圆弧。本轮采用“**半圆帽 + 短直壁**”的钟形玻璃，保留上部半圆轮廓并接到底座；没有缩核心，也没有改底座造型。

若必须严格正半圆，最小调整建议是**把仓体加宽到约 44×32（留边建议 46×32）**，而不是只加高到 32×40：32 px 宽度下正半圆半径只有 16，核心顶部会落在圆弧顶点外；只加高会变成更高的半椭圆/钟形，仍不是严格正半圆。不要缩小 16 px 核心。当前 32×32 的“半圆帽 + 短直壁”是保持画布不变的最小改法；是否改为更大画布请用户确认。

## 4. 使用

在 Godot 编辑器中把 `scenes/star_core_bay_visual.tscn` 拖入 2D 场景即可。选中根节点后可改：

- `occupied`（默认 true）：true 显示核心和锁定标识；false 显示空仓。纯显示开关。
- `show_lock_marker`（默认 true）：是否在底座上绘制金色锁定标识。

也可以在代码中：

```gdscript
var bay: StarCoreBayVisual = preload("res://scenes/star_core_bay_visual.tscn").instantiate()
add_child(bay)
bay.occupied = false   # 空仓显示，不涉及仓逻辑
bay.show_lock_marker = false
```

组件已 `@tool`，在编辑器中修改导出属性会立即重绘；底座和玻璃使用 `TEXTURE_FILTER_NEAREST`。缺图时对应层留空并警告一次，不生成替代 PNG。

### 罩动画（2026-10-31）

玻璃不再整体压缩 `scale.y`，也不再做均匀 alpha 淡出。现有 32×32 glass PNG 保持原点、1:1 缩放和原色，由 `star_core_bay_visual.gd` 内的 CanvasItem shader 按像素做弧线遮罩：

- **合罩**：左右下缘/侧壁先出现，沿罩弧向顶部中央推进，顶部中央最后闭合；
- **开罩**：顶部中央先消失，左右侧壁沿弧向底座下降，完全打开时玻璃隐藏；
- 遮罩是硬边，仅在推进边缘做 1 px 浅色提示；底座、核心和玻璃主色不变，玻璃不移动、不越底座；
- `open_progress` 0 = 完整闭合轮廓，1 = 完全打开；旧 `set_lid_open_immediately()` 和静态 `occupied` 用法保留。

代码 API：`start_open(duration)`、`start_close(duration)`、`set_lid_open_immediately(open)`、`stop_lid_animation()`、`is_lid_open()`、`is_lid_closed()`、`get_lid_progress()`。玩法状态由 `StarCoreBayInteractable` 的 LOCKED/OPENING/OPEN/CLOSING 驱动。

真实引擎关键帧：`screenshots/star_core_lid_keyframes.png`，六个 4× 同屏实例；顶行合罩 66%→33%→闭合，底行闭合→开罩 33%→66%。来源 `tools/preview_star_core_lid.tscn`，像素结果见 `screenshots/MANIFEST_LID.txt`。像素检查按行轮廓判定左右对称；顶部中央条带在 33/66% 为 0、闭合时 >0。左侧白反光/右侧暗部会让原始左右颜色计数不同，不能直接用颜色计数判对称。

## 5. 预览与截图

单独运行，不接入默认主场景：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core_bay.tscn
```

预览固定 640×360，显示空仓/满仓各 1× 与 4×，并用工程主角 idle 的真实 32×37 可见像素做 1× 比例参照。它不是玩法截图，也不代表正式关卡摆放。

可选真实引擎截图：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core_bay.tscn -- --capture-preview
```

输出 `screenshots/star_core_bay_preview.png`（640×360）。截图路径现在会检查**实际截图像素**：采样 4× 满仓仓体底座正面/底脚区域，要求白色像素 ≥500、底座区域平均亮度 ≥0.35，且明显高于背景采样区；否则以退出码 1 失败，不再只依赖节点 z 自检。

### GUI 渲染测试（必须非 headless）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_bay_render.tscn
```

该测试实例化真实预览、抓取真实 viewport 像素，并额外隐藏 4× 满仓 bay 的 `Base` 做负对照：正常时底座区域应有白色像素；隐藏底座后同一检查必须失败。

## 6. 独立测试

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_bay_visual.tscn
```

覆盖：组件 `@tool`/Node2D/无物理节点、**Base/LockMark/Core/Glass 四层原点与全非负 z 顺序**、`LockMark` 为独立 @tool 子节点、核心 `LOCKED` 且 badge 关闭、底座/玻璃 32×32 同原点、底座 y≥24 且不进入核心矩形、玻璃在核心矩形内 alpha=0、核心每行都在玻璃外轮廓内、底座亮度/金符文/玻璃反光、空仓图无紫色核心、`occupied`/`show_lock_marker` 切换（检查实际 `LockMark.visible`）、**罩动画 shader 遮罩/左右对称/顶部中央最后闭合**、旧静态 `set_lid_open_immediately` 兼容、预览 640×360/空满仓 1×/4×/主角 1× 参照/ASCII 标签/非玩法声明。

### 本轮实测（2026-10-31，层级修复后）

- Headless 视觉契约测试：**151 通过、0 失败、0 跳过，退出码 0**（2026-10-31 罩动画更新后）。
- GUI 渲染测试：**通过，退出码 0**；4× 满仓底座区域 `white=1024/500`、`base_mean=0.712`、`background_mean=0.057`；隐藏 `Base` 负对照 `white=0`、`base_mean=0.136`、检查失败，证明像素检查真实观察白底座。
- 真实引擎预览捕获：`PREVIEW_BAY_ART loaded_instances=4 missing=`、`PREVIEW_CAPTURED ... size=(640, 360)`、`PREVIEW_PIXEL_CHECK white=1024/500 base_pixels=2080 base_mean=0.712 background_mean=0.057 ok=true`，退出码 0。
- 既有全量测试 runner 复跑：**314 通过、0 失败**；既有星核三态组件测试复跑：**100 通过、0 失败**。未发现对原基础场景/借力房/三态组件的回归。
- 素材自检：三张 PNG 32×32 RGBA；底座 bbox `[2,24,30,32]`；玻璃 bbox `[1,1,31,25]`；核心矩形玻璃 alpha 最大 0；底座在核心矩形内像素 0；源星核 SHA256 前后一致。
- 本轮层级修复未改三张 PNG 的造型、尺寸或哈希；32×32 轮廓不变。日志：`tests/logs/star_core_bay_visual_test.log`、`tests/logs/star_core_bay_render_test.log`。

## 7. 边界与后续

本轮未做、也不应被理解为已实现：

- 星核仓存取/回收/锁定玩法状态机（本组件只提供视觉开合；当前交互由 `StarCoreBayInteractable` 驱动）；
- 物理、碰撞、吸力、拾取、投掷；
- 默认主场景接入、正式关卡布局、三关流程；
- 修改 `player.gd`、`main.gd`、`anchor_room.gd`、`star_core_visual.gd` 及其测试；
- 修改 `progress.md`、工程 `ASSET_CREDITS.md`（由协调者汇总）。

后续正式仓逻辑应放在独立的玩法节点中，只调用本组件的 `occupied` / 视觉开合 API；不要把碰撞、吸力或存取状态机塞进本组件。当前是首版外观与罩动画，等待用户对玻璃厚度、底座比例、白/灰蓝明度、金符文密度、锁定标识可读性以及罩动画速度/方向给出视觉反馈后再迭代。

## 8. 来源

底座、玻璃和空仓组合图为本轮程序化自制像素，无第三方素材、无外部生成服务。组件/预览中的紫色星核是工程既有 `assets/star_core/star_core_locked.png`（Frakassets Free Shiny Gem Round，CC BY 4.0），原文件未修改。预览截图中的主角 idle 截帧来自工程既有角色素材，仅作真实比例参照；其作者与许可仍未知。完整署名与修改说明由协调者汇总到 `ASSET_CREDITS.md`。
