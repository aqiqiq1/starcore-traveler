# 星核仓首版素材（32×32 侧视像素分层）

更新日期：2026-10-31。本文说明本轮**原型首版**的程序化像素素材、生成方式、几何与验证结果。

> **状态：原型首版，等待用户视觉反馈；不是最终美术定稿。**
> 本轮只做静态外观/编辑器可见的视觉组件与独立预览，不做开盖动画、存取交互、碰撞、吸力或正式关卡接入。

## 1. 产物

| 文件 | 位置 | 用途 |
| --- | --- | --- |
| `generate_star_core_bay.py` | 本目录 | 唯一生成脚本，Pillow 逐像素绘制；不下载、不调用外部生成服务。 |
| `star_core_bay_base.png` | 本目录 / 工程 `assets/star_core_bay/` | 32×32 白底座后层。 |
| `star_core_bay_glass.png` | 本目录 / 工程 `assets/star_core_bay/` | 32×32 同原点浅青玻璃前层。 |
| `star_core_bay_empty.png` | 本目录 / 工程 `assets/star_core_bay/` | 32×32 空仓组合图（base + glass），供直接拖用；不含星核。 |
| `manifest.json` | 本目录 | 尺寸、alpha、坐标、哈希、自检结果、分层/接入说明。 |
| `star_core_bay_review.png` | 本目录 | 1280×900 本地 NEAREST 评审大图：8× 分层、1×/4× 组合、主角 1× 比例参照。不是引擎截图。 |
| `star_core_bay_preview.png` | 工程 `screenshots/` | 640×360 真实 Godot 引擎预览截图。 |

工程 `assets/star_core_bay/` 只放上述三张必要 PNG；Godot 自动生成的 `.import` 侧车文件不属于美术素材。

## 2. 设计说明

- **视角**：侧视像素，32×32 画布，Nearest 采样，1:1 使用。
- **底座**：暖白/白色石质，图像 y=24..31，共 8 px 高；顶板、主体、底脚形成台阶，右侧和底部用灰蓝阴影表现厚度。没有改成深色底座，也没有现代大机器结构。
- **玻璃**：浅青边缘、少量左上白反光、极淡内部反射；玻璃内腔在既有 16×16 星核的整块矩形内 **alpha=0**，中心完全透出星核。
- **星核**：直接使用工程既有 `assets/star_core/star_core_locked.png`（16×16 原紫），不复制、不重绘、不改原文件。
- **金色符文**：底座正面一个约 4×3 的空心菱形+中心点，另有 1 个暗金小点；不是极性加号，也不铺满底座。
- **锁定标识**：Godot 组件用独立的 `LockMark` 子节点在底座正面右侧绘制 4×3 金色小锁；不烘焙进任何 PNG，空仓图不含锁定标识。
- **分层**：`Base` z=1、`LockMark` z=1（Base 之后的独立子节点）、`Core` z=2、`Glass` z=3；全部非负相对 z，共用原点 (0,0)。`Base` 不能改回负 z，否则会落到预览/UI Control 自己的背景之后，出现“白底座消失、只剩玻璃/核心/悬空锁标”的渲染问题。

## 3. 几何与放置

坐标以 32×32 图像左上角为 (0,0)，Godot 组件原点在图像 (16,16)。

| 项目 | 数值 |
| --- | --- |
| 画布 | 32×32，RGBA |
| 底座范围 | 图像 y=24..31；主体 x=4..27，顶板/底脚 x=2..29 |
| 星核范围 | 图像 x=8..23、y=8..23（16×16，组件内 (0,0)） |
| 星核底边 | y=23 |
| 底座顶面 | y=24 |
| 重叠 | 无；星核矩形与底座矩形不相交 |
| 玻璃外轮廓 | 半圆帽外半径 15，中心 (15.5,16)，顶 y=1；短直壁到 y=23；封圈 y=24 |
| 玻璃内腔 | 在星核整块 16×16 内 alpha=0 |
| 底座平均不透明亮度 | 约 196/255（白/浅色底座，见 manifest） |
| 金符文像素 | 8 个（不含代码锁定标识） |

### 关于“半圆”的必要说明

**严格正半圆在 32×32 内放不下 16 px 星核 + 有厚度的白底座。** 正半圆的高度只有半径，顶部收得太快；16×16 核心放在底座上方时，顶部会超出圆弧。因此本轮使用“**半圆帽 + 短直壁**”的钟形玻璃：上部仍是半圆，短直壁把罩体接到 y=24 的底座，既保留浅青玻璃罩的轮廓，也不缩核心、不改底座。

如果必须严格正半圆，**最小调整建议是把仓体加宽到约 44×32（留边建议 46×32），而不是只加高到 32×40**：32 px 宽度下正半圆半径只有 16，核心顶部会落在圆弧顶点外；只加高会变成更高的半椭圆/钟形，仍不是严格正半圆。不要缩小 16 px 核心。当前 32×32 的“半圆帽 + 短直壁”是保持画布不变的最小改法；是否改为更大画布请用户确认。

## 4. 生成与自检

指定环境：

```powershell
& "D:\minic\envs\2024212971\python.exe" "D:\godot game\星核旅人\自制素材\星核仓\generate_star_core_bay.py"
```

脚本会：

1. 读取既有紫色星核，记录运行前后 SHA256，确认原文件未变；
2. 逐像素生成底座和玻璃，合成空仓图；
3. 从磁盘回读三张 PNG，检查 32×32、RGBA、alpha、透明角、底座 y≥24、星核矩形不透明度、核心矩形玻璃 alpha=0、空仓中心透明、金符文数量、玻璃白反光/青边、底座亮度等；
4. 写 `manifest.json` 和 `star_core_bay_review.png`；
5. 任何布尔自检失败都会以非零退出码终止，不静默通过。

本轮实测自检全部通过（见 `manifest.json` 的 `checks`）：

- 三张 PNG 均 32×32、RGBA、保留 alpha；
- 底座 bbox `[2,24,30,32]`，y<24 无像素；
- 玻璃 bbox `[1,1,31,25]`；
- 星核矩形内玻璃 alpha 最大值 **0**；
- 底座在星核矩形内像素数 **0**；
- 空仓中心 alpha **0**；
- 白色底座平均不透明亮度约 **196.43/255**；
- 金符文像素 **8**；亮白反光像素 **12**；浅青边缘像素 **149**；
- 源星核 SHA256 前后一致。

## 5. 工程内查看与截图

组件场景：`基础场景原型/scenes/star_core_bay_visual.tscn`
组件脚本：`基础场景原型/scripts/star_core_bay_visual.gd`
锁定标识脚本：`基础场景原型/scripts/star_core_bay_lock_mark.gd`

在 Godot 编辑器中打开工程后，可单独打开 `tools/preview_star_core_bay.tscn` 按 F6 运行，或直接用命令行：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core_bay.tscn
```

预览固定 640×360，显示：

- 空仓/满仓各 1× 与 4×；
- 工程主角 idle 真实截帧 1× 比例参照（32×37 可见像素）；
- 分层顺序、底座/玻璃/核心范围、非玩法声明。

真实引擎截图：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tools/preview_star_core_bay.tscn -- --capture-preview
```

输出 `基础场景原型/screenshots/star_core_bay_preview.png`（640×360）。截图路径会检查真实像素：4× 满仓底座正面/底脚区域必须白色像素 ≥500、区域平均亮度 ≥0.35，且明显高于背景；否则退出码 1。实测 `white=1024/500 base_pixels=2080 base_mean=0.712 background_mean=0.057 ok=true`。

### GUI 渲染测试（必须非 headless）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_bay_render.tscn
```

测试实例化真实预览、抓取真实 viewport 像素，并隐藏 4× 满仓 bay 的 `Base` 做负对照。实测正常 `white=1024`、`base_mean=0.712`；隐藏底座后 `white=0`、`base_mean=0.136`、检查失败，负对照符合预期，退出码 0。

## 6. 测试

独立测试，不改既有测试 runner：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_star_core_bay_visual.tscn
```

本轮实测：**126 通过、0 失败、0 跳过，退出码 0**。覆盖组件为 `@tool`、Base/LockMark/Core/Glass 四层原点与全非负 z 顺序、独立 `LockMark` 节点、无物理节点、核心 badge 关闭、底座/玻璃 32×32 与同原点、底座不进入核心矩形、玻璃在核心矩形内全透明、核心每行都在玻璃外轮廓内、底座亮度/金符文/玻璃反光、空仓无紫色核心、`occupied`/`show_lock_marker` 切换实际 `LockMark.visible`、预览 640×360、空/满仓 1×/4×、主角 idle 1× 参照、标签 ASCII 与非玩法声明。

既有全量测试 runner 复跑：**314 通过、0 失败**；既有星核三态组件测试复跑：**100 通过、0 失败**。未发现对原基础场景/借力房/三态组件的回归。本轮层级修复未改三张 PNG 的造型、尺寸或哈希，32×32 轮廓不变。日志：`基础场景原型/tests/logs/star_core_bay_visual_test.log`、`基础场景原型/tests/logs/star_core_bay_render_test.log`。

## 7. 边界

本轮明确**没有**做：

- 开盖动画、存取/回收交互、碰撞、吸力、仓储逻辑；
- 星核仓玩法状态机、正式关卡布局、默认主场景接入；
- 修改 `player.gd`、`main.gd`、`anchor_room.gd`、`star_core_visual.gd` 及其测试；
- 修改 `progress.md` / `ASSET_CREDITS.md`（由协调者汇总）。

`occupied` 只是**纯显示开关**：false 时隐藏既有核心和代码锁定标识，露出空仓；不声称已实现仓逻辑。

## 8. 来源与署名

- 底座、玻璃、空仓组合图：本轮项目自制程序化像素，无第三方素材、无外部生成服务。
- 合成参照/工程场景使用的紫色星核：既有 `star_core_locked.png`，来自 Frakassets “Free Shiny Gem Round”，CC BY 4.0；本轮未修改原文件。完整署名与修改说明由协调者汇总到工程 `ASSET_CREDITS.md`。
- 本目录的 `star_core_bay_review.png` 是内部评审合成图，含棋盘、文字、既有星核、代码锁定标识的复刻，以及工程既有主角 idle 截帧（仅作 1× 比例参照）。主角作者与许可仍未知，因此该评审图仅供内部使用，不是可分发素材包，也不替代授权记录。
