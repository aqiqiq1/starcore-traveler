# 裂隙工坊 · 呈现参考（2026-11-25）

本章新做的呈现对象有四个：反转光幕（InversionField）、相性光桥（PhaseBridge）、
新敌 PolarityWisp、裂隙背景紫色雾。按项目规则，先联网打开直接相关的游戏画面再设计；
本文件只记录**实际打开并看到的**内容，不把搜索摘要当成观看结果。

## 实际打开并核看的来源

### 1. Celeste Wiki · Core Block（热/冷两态）

- 页面：<https://celeste.ink/wiki/Core_Block>（2026-11-25 打开）
- 页面内的两态动图（GIF，已下载逐帧查看前 7 / 12 帧）：
  - Hot：<https://static.wikitide.net/celestewiki/e/e4/Core_Block_Hot.gif>
  - Cold：<https://static.wikitide.net/celestewiki/6/68/Core_Block_Cold.gif>
- 实际观察：
  - Hot 是近黑的炭块，内部亮红/橙裂纹向中心汇聚，中心是一枚偏白橙的亮核；
  - Cold 是**同一轮廓**整体转成深蓝/靛蓝，裂纹变青/浅蓝，中心核也变青白；
  - 两态不是换造型，而是整块换色 + 中央亮核；核有轻微脉动，轮廓始终保持 1 px 深边；
  - 页面文字确认两态由 core switch 切换。
- 能借鉴的只有**读序**：整块同色 → 中央亮核 → 再读细节；1× 像素下先让人知道“当前是哪种状态”。
- 不照搬：不使用其方块像素、裂纹贴图、Hot/Cold 造型、弹飞/下沉玩法、调色板数值。
  本项目的反转光幕是 24×120 紫色光幕，光桥是 64×10 金/青能量桥，均为独立几何。

### 2. Celeste Wiki · Seeker（悬浮敌与 5A 镜殿背景）

- 页面：<https://celeste.ink/wiki/Seeker>（2026-11-25 打开）
- 图中动图（已下载逐帧查看 8 帧）：<https://static.wikitide.net/celestewiki/5/56/Celeste_seeker.gif>
- 实际观察：
  - 敌体是紫色圆团，最醒目的是**一只大白眼 + 深色瞳孔**，周围一圈小尖刺/触须；
  - 背景是紫/品红的镜殿，剪影化的神殿构件压在雾里，前中后景靠明度分层；
  - 角色在 16–24 px 尺度下依旧先读到“白眼球 + 圆轮廓”，细节最后才读到。
- 能借鉴：16×16 的小敌人需要**一个大而清楚的读点**（本项目用 4×4 亮眼 + 2×2 深瞳），
  以及背景紫色必须压低明度、靠剪影分层，不能盖过金/青玩法色。
- 不照搬：不使用 Seeker 的精灵、尖刺环造型、紫/品红具体配色、追踪 AI 或冲刺玩法。
  本项目的 PolarityWisp 是原创的双色独眼光灵：金/青两态、正弦悬浮、定时脉冲推/拉。

### 3. 项目内 DS03 背景（非第三方，作为底色基准）

- `assets/backgrounds/cloud_ruins_ds03/art_assets/base_sky_640x360.png`
- 实际观察：顶部深青蓝、地平线偏浅灰青，整体低饱和；遗迹是灰蓝剪影。
- 结论：紫色雾必须放在**中下部**、低到中低 alpha，顶部保持干净，否则会把 DS03 的
  “高空云墟”读感洗掉；地面/角色/金青机关都在雾层之上，不受影响。

## 证据路径（本机实际查看用）

- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-celeste-core-hot-2026-11-25.png`
  （Hot 动图前 7 帧拼图）
- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-celeste-core-cold-2026-11-25.png`
  （Cold 动图前 8 帧拼图）
- `D:/godot game/星核旅人/.openchamber/screenshots/rift-ref-celeste-seeker-2026-11-25.png`
  （Seeker 动图前 8 帧拼图，含 5A 背景）

这些只是核看证据，不属于 DLC 运行素材，不随工程分发。

## 未核实 / 边界

- 未运行 Celeste 本体，未听/看其开关、脉冲音效与连续运动；本参考只支持
  “整块换色 + 中央亮核”的静态读序与“大眼球剪影”的静态可读性。
- 未核 Celeste 源码或真实像素尺寸；本项目 16×16 / 24×120 / 64×10 均为独立设计，
  不声称与原作同尺寸、同动画、同节奏。
- 本章的金/青配色、紫 #a874ff、深边 #0a121a 全部沿用本项目现有调色板与
  trial_chambers/polarity_gate 的既有规范，没有从参考图取色。
