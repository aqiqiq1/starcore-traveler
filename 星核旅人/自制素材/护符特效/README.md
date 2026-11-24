# 星核旅人 · 胸前极性护符特效

本目录是本次素材生成任务的全部产物：正极暖金 / 负极冷青的 5×5 胸前护符、11×11 四帧脉动光晕、24×24 四帧切换扩散环，以及角色叠加预览和纯特效联系表。

- 全部特效为本次用 Python + Pillow 从零程序化像素绘制，没有下载、提取或使用第三方特效资源，也没有调用远程图像生成/付费工具。
- 没有创建 Godot 工程，没有修改 `individual_sheets/` 中的角色表，也没有在 Godot 中实际导入或运行验证。
- 预览图是本地像素合成，不是游戏截图；图上的棋盘/深色背景都不属于透明 PNG 素材。

## 文件

| 文件 | 规格 | 用途 |
| --- | --- | --- |
| `talisman_gold.png` | 5×5 RGBA，21 个不透明像素，3 px 中心高光 | 正极暖金护符本体，透明底 |
| `talisman_cyan.png` | 5×5 RGBA，21 个不透明像素，3 px 中心高光 | 负极冷青护符本体，透明底 |
| `glow_gold_4f.png` | 44×11 RGBA，横向 4 帧，每帧 11×11 | 正极光晕，8 FPS 循环 |
| `glow_cyan_4f.png` | 44×11 RGBA，横向 4 帧，每帧 11×11 | 负极光晕，8 FPS 循环 |
| `switch_ring_gold_4f.png` | 96×24 RGBA，横向 4 帧，每帧 24×24 | 正极切换扩散环，20 FPS 单次 |
| `switch_ring_cyan_4f.png` | 96×24 RGBA，横向 4 帧，每帧 24×24 | 负极切换扩散环，20 FPS 单次 |
| `preview_chest_gold.png` | 8× NEAREST 合成 | 正极单态胸口预览 |
| `preview_chest_cyan.png` | 8× NEAREST 合成 | 负极单态胸口预览 |
| `preview_chest_compare.png` | 8× NEAREST 合成 | 两态并排对照 |
| `effects_contact_sheet.png` | 整数放大联系表 | 放大展示所有光晕/扩散环帧 |
| `preview_polarity_switch.gif` | 可选小 GIF | 仅切换护符颜色，姿势固定 idle #0 |
| `manifest.json` | 机器可读清单 | 文件名、sheet 尺寸、帧尺寸/数量、FPS/循环、定位 |
| `generate_talisman_assets.py` | 生成脚本 | 调色重制；不会改写原角色 |

四帧规格：光晕每帧 11×11、共 4 帧，8 FPS 时一轮 0.5 秒；扩散环每帧 24×24、共 4 帧，20 FPS 时总长 0.20 秒。

## Godot 4 使用

两种节点都可使用，关键是把四帧横向 sheet 切成 4 帧：

1. **AnimatedSprite2D + SpriteFrames**
   - 新建 SpriteFrames；在“从精灵表添加帧”中选择横向 4 列、1 行（每帧 11×11 或 24×24）。
   - 光晕动画：`speed = 8`，`loop = true`。
   - 扩散环动画：`speed = 20`，`loop = false`；播放一次后在 `animation_finished` 里隐藏，或换回默认状态。
   - `centered = false`，按下面的 top-left 偏移放置。
2. **普通 Sprite2D**
   - 设置 `hframes = 4`、`vframes = 1`，用 `frame = 0..3` 换帧；或让 AnimationPlayer 驱动 `frame`。
   - 光晕循环播放；扩散环只播放一次，同样建议设 `centered = false`。

透明度与采样：

- 所有特效 PNG 都是 RGBA 透明底，四角 alpha=0；没有把棋盘或预览背景烘进素材。
- 导入时选 Godot 的 “2D Pixel” 预设（或等效设置）：**Filter = Nearest、Mipmaps = Off**；不要用 Linear。
- 素材是 1× 原生像素，需要更大请用整数倍 NEAREST，不要非整数缩放。
- 不需要 Bloom 插件、shader 或后处理。

建议层级：

```text
Player (Node2D)
├─ CharacterSprite (AnimatedSprite2D)   z_index = 0
├─ Glow (AnimatedSprite2D/Sprite2D)     z_index = -1  ← 在角色后面
├─ Talisman (Sprite2D)                  z_index = 1   ← 最上层
└─ SwitchRing (AnimatedSprite2D)        z_index = 2   ← 短时扩散环
```

光晕放在角色后方，这样不会把脸、围巾或胸甲整体染亮；护符放最上层，读取清楚。扩散环是 0.2 秒短特效，可以盖在角色上方，播放完立即隐藏。

## 角色定位（只对 idle #0）

预览固定使用：

- 原表：`individual_sheets/male_hero-idle.png`
- 帧号：**第 0 帧**（左侧第一格，128×128）
- 该帧角色可见 bbox：`x=41..72, y=43..79`（Pillow bbox 右/下开区间为 `[41,43,73,80]`），约 32×37 px
- 精灵帧心/锚点：`(64,64)`
- 胸口像素：`(64,63)`（该像素中心为 `(64.5,63.5)`）
- 护符在表中的 top-left：`(62,61)`，覆盖 `x=62..66, y=61..65`

为了避免 5×5、11×11、24×24 这类奇偶尺寸混用造成半像素偏移，**本包按 `centered = false` 设计**。把特效节点作为 Player 的同级/子级摆放时，相对于角色帧中心 `(64,64)` 使用这些整数偏移：

| 特效 | 原表 top-left | 相对角色帧中心的节点位置 |
| --- | --- | --- |
| 护符 | `(62,61)` | `(-2,-3)` |
| 光晕 | `(59,58)` | `(-5,-6)` |
| 扩散环 | `(52,51)` | `(-12,-13)` |

这样三者的视觉中心都落在胸口像素中心 `(64.5,63.5)`，与 preview 的叠放位置一致。若坚持使用 `centered = true`，不能直接套用上表，需要按各纹理中心重新对位，并注意半像素；不建议。若你的 Player 根节点锚在脚底而不是 128×128 帧心，请先把帧心到脚底的偏移计入，再套用上表。

## 预览说明

- `preview_chest_*.png` / `preview_chest_compare.png` 使用原 idle #0，整数 8× NEAREST 放大；护符按 1× 原生尺寸合成，不改变角色。静态预览与 GIF 均取光晕第 2 帧（峰值帧）。
- 光晕在合成时位于角色之后，护符位于角色之前；因此头脸、围巾和身体像素不会因光晕被覆盖或染色。
- 自动检查确认：除护符 top-left `(62,61)` 起的 5×5 区域外，角色原有可见像素完全不变；护符 bbox 内没有围巾的洋红/紫色像素，头部更在其上方。
- 预览中的深色网格、棋盘和文字只是评审背景，不属于素材；不要把预览图当作透明贴图或游戏实机截图。预览图是不透明合成图（RGB），透明资源只有 6 个特效 PNG。
- GIF 只演示换色，姿势固定 idle #0，不代表已经实现逐帧跟踪。转身、walk/run/jump/fall 等动作需要后续逐帧配置定位，不能把这张静态叠图当成完整系统。

## 许可与边界

- 护符、光晕、扩散环的像素数据和生成脚本是本任务原创、简单程序化绘制；没有引入第三方美术/特效资产。
- 角色预览来自项目现有的 `male_hero-idle.png`，其来源与许可仍按原角色文件的约定处理；本目录没有重新授权角色，也没有改动原文件。
- 预览图、GIF、联系表仅用于本项目内部评审与搭配确认，不是可自由再分发的角色/游戏资产；外部发布前请项目组确认角色与字体许可。预览中的说明文字由系统字体栅格化，不提取为游戏字体。
- 这些效果素材可用于本项目原型；如果要把特效本身单独发布为素材包，请先由项目组决定许可与署名方式，不能把本 README 当作法律许可文本。

## 重新生成 / 调色

环境（项目指定）：

```powershell
D:\minic\envs\2024212971\python.exe
```

在本目录运行：

```powershell
D:\minic\envs\2024212971\python.exe generate_talisman_assets.py
```

脚本只读取 `../../individual_sheets/male_hero-idle.png`，只向当前目录写入生成文件；不会改原角色表或根目录文档。脚本会重写本目录同名的 PNG / GIF / manifest。

调色：

- 修改脚本顶部 `PALETTES["gold"]` / `PALETTES["cyan"]` 的色板，可整体重制两态。
- `TALISMAN_INNER` 控制 3×3 内芯的明暗/3 px 高光；`GLOW_FRAMES`、`RING_FRAMES` 控制光晕半径/alpha 和扩散环半径/线宽。
- 若改画布尺寸或帧中心，请同步修改 manifest 和 README 中的定位偏移，并用脚本的 `verify_assets()` 重新检查。

## 自检结果

本次实际运行生成脚本后的检查（不是 Godot 导入测试）：

- [x] 11 个图像文件（6 个透明特效 PNG + 4 个不透明预览 PNG + 1 个 GIF）实际生成；6 个特效 PNG alpha 非空。
- [x] 护符 `5×5`，`21` 个不透明像素，中心高光 `3` px；正/负 alpha 形状逐字节一致。
- [x] 光晕 `44×11` = `4×11×11`；扩散环 `96×24` = `4×24×24`；均能整除。
- [x] 扩散环四帧中心一致（bbox 中心均为 `(12,12)`），中心与四角 alpha=0；最后一帧 alpha 仍为 142，放大后可见。
- [x] 所有特效四角透明；没有不透明底色。
- [x] `preview_preserves_character_outside_talisman = true`：除 5×5 护符叠放区外，角色可见像素未被改动。
- [x] 预览背景是独立合成图层，透明素材 PNG 中不含背景。
- [ ] **未在 Godot 4 中导入、切帧、播放或检查 z-order / 半像素**；这些属于后续引擎内验证项。

若后续采用这些文件，建议先在一个临时场景里按上表位置加载 idle #0，确认相机缩放与像素吸附后再接入状态切换。
