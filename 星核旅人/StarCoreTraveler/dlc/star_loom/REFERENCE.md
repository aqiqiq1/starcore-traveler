# 星核织机 · 呈现参考记录（2026-11-26）

本章新做的呈现对象：96×96 星核织机本体、24×24 极性节点、8×8 追踪弹、
16×16 裂隙浮灵、960×360 织机厅 overlay、三层攻击预警、HUD 与完成页。
按项目规则，先联网打开直接相关的游戏画面再设计；本文件只记录**实际打开并
看到的**内容，不把搜索摘要当成观看结果。

`websearch` 在本次会话中没有返回结果，因此改用直接打开原页面 / 官方商店截图 /
wiki 动图的方式取得证据；下面每条都附了实际文件与证据路径。

## 实际打开并核看的来源

### 1. Ikaruga（斑鸠）· 官方商店实机截图

- 页面：<https://store.steampowered.com/app/253750/Ikaruga/>（2026-11-26 打开）
- 截图（Steam appdetails 返回的第 3 张）：
  <https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/253750/ss_e7c98893ad0a17250ad50075fba6efa12fcc5f7a.1920x1080.jpg>
- 证据：`D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-ikaruga-gameplay-2026-11-26.jpg`
- 实际观察：
  - 垂直竞技场，上方大型敌机/首领，带一条独立血条；玩家在下方，画面中央
    被高亮的青色激光占据；
  - 敌机和弹幕用**黑白两种体色**区分极性，不靠色相；白弹/黑弹都有深色 1 px
    轮廓，饱和度高，背景是低饱和的岩壁；
  - 同屏弹幕密度高，但每一种弹都保持清楚的形状与亮核，玩家机体是画面里
    最亮的白点之一。
- 能借鉴：
  - 极性用**体色明度 + 形状**双读点，不只靠金/青色相：本章节点在底色之外
    再加金色菱形 / 青色双横线的 1 px 标记，核心用菱形而不是圆点；
  - 弹幕先读排列、再读颜色：本章只有少量慢弹，深色轮廓 + 白核；
  - 首领占据画面中右，玩家从左侧进入，血条/状态独立于场景。
- 不照搬：不使用 Ikaruga 的机体、敌机、子弹、激光、黑白配色数值、纵版
  卷轴布局、连锁计分或任何原作节奏；本章是横版 960×360 单厅首领战。

### 2. Celeste Wiki · Seeker（小体型悬浮敌）

- 页面：<https://celeste.ink/wiki/Seeker>（2026-11-26 打开）
- 动图：<https://static.wikitide.net/celestewiki/5/56/Celeste_seeker.gif>
- 证据：`D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-celeste-seeker-2026-11-26.gif`
- 实际观察（GIF 首帧，256×256）：
  - 紫色圆团身体，最醒目的是**一只大白眼 + 深色瞳孔**，周围一圈尖刺/触须；
  - 背景是低明度的紫/品红镜殿，构件压成剪影；前景亮色栏杆只占底部一条；
  - 小敌在 16–24 px 尺度下仍然先读到“白眼球 + 圆轮廓”，细节最后才读到。
- 能借鉴：
  - 16×16 的裂隙浮灵只保留一个强读点：大白眼球 + 紫色团块 + 三条摆尾；
  - 敌人紫色与玩法金/青分开，紫色只表示“裂隙生物”，不承担极性；
  - 背景必须低明度、低饱和，不能盖过金/青玩法色。
- 不照搬：不使用 Seeker 的精灵、尖刺环造型、紫/品红具体配色、追踪/踩踏
  玩法或雪球式行为。本章浮灵是慢速漂移、接触即爆、任意相性 J 一击清除。

### 3. Celeste Wiki · Badeline Boss（首领剪影与体量对比）

- 页面：<https://celeste.ink/wiki/Badeline_Boss>（2026-11-26 打开）
- 动图：<https://static.wikitide.net/celestewiki/a/ac/Celeste_badeline_boss.gif>
- 证据：`D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-badeline-frames-2026-11-26.png`
  （用 Pillow 抽出 53 帧、放大 3× 拼成联系表）
- 实际观察：
  - 首领是深紫/近黑的巨大毛发团，六向伸展，占据画面上半；玩家是底部
    一个小人，落点/受击都靠体量与明度对比读出；
  - 53 帧中首领的轮廓缓慢摆动，玩家在平台边缘移动；背景是青绿/深绿的
    低明度神殿；
  - 首领没有铺满屏幕的高亮光斑，危险读点靠轮廓与局部亮色。
- 能借鉴：
  - 首领用**大块深色剪影 + 中央亮核**建立体量；玩家在其前方仍是亮的小人；
  - 背景只做低对比织机厅剪影，危险效果集中在小范围；
  - 首领的“呼吸”用 2 帧/3 fps 的轻微变化，不靠全屏闪。
- 不照搬：不使用 Badeline 的毛发造型、颜色、Boss 招式、平台/攀爬玩法。
  本章 96×96 织机是方形织框 + 圆环 + 中央插座，完全不同的几何。

### 4. Cuphead · Captain Brineybeard 实机画面（横版首领构图）

- 页面：<https://en.wikipedia.org/wiki/Cuphead>（2026-11-26 打开）
- 图片：`File:Cuphead gameplay, Captain Brineybeard.png`（经 en.wikipedia
  Special:FilePath 下载）
- 证据：`D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-cuphead-brineybeard-2026-11-26.png`
- 实际观察：
  - 首领在画面右侧，玩家在左下，码头是清楚的横向地面；空中是少量
    可读的粉色/白色弹与特效；
  - 首领体量远大于玩家，HUD 只占左下角一小条 HP；背景（海/天）压得很低，
    不与弹幕抢读；
  - 弹与玩家都在同一水平带附近，玩家向上/向前应对。
- 能借鉴：
  - 横版单厅：左侧入口、右侧首领、连续地面；
  - HUD 只占顶部一条，不盖住战斗；玩家与首领同处一条可读的水平带；
  - 弹幕数量克制，靠位置与预警而不是铺屏。
- 不照搬：不使用 Cuphead 的手绘风格、角色、码头、弹型、HUD 布局或配乐。

### 5. Taisei Project / 弹幕地狱截图（弹的可读性）

- 页面：<https://en.wikipedia.org/wiki/Bullet_hell>（2026-11-26 打开）
- 图片：`File:Danmaku in Taisei Project.png`（经 Wikimedia Commons
  Special:FilePath 下载，960×1091）
- 证据：`D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-taisei-danmaku-2026-11-26.png`
- 实际观察：
  - 紫/白弹幕都有深色 1 px 轮廓与亮核，背景是低饱和灰绿；玩家是画面
    下方的小人，判定点清楚；
  - 弹幕密集但每种弹的形状一致，玩家可以按“形状 + 颜色”读；
  - 高亮激光/爆炸只占局部，不是整屏白。
- 能借鉴：
  - 本章追踪弹：8×8 深紫轮廓 + 白核 + 2×2 拖尾；预警点用同色 1 px 环；
  - 全屏只保留低 alpha 的织机剪影/紫色薄雾，弹幕与预警是最高对比层。
- 不照搬：不使用 Taisei 的弹型、角色、背景、密度或任何数值；本章
  同屏追踪弹上限 6，扫带一次 1 条，浮灵上限 3。

## 与本项目实现的对齐

- 复用项目既有调色板：金 `#f4cd63`、青 `#5fe1e6`、紫 `#a874ff`、深底
  `#0a0812`；没有从参考图取色。
- 生成素材全部在 `dlc/star_loom/assets/`：
  `loom_boss_96x96_2f.png`、`loom_node_24x24_2f.png`、
  `loom_bullet_8x8_2f.png`、`loom_wisp_16x16_4f.png`、
  `loom_bg_overlay_960x360.png`；由 `tools/gen_assets.py` 程序化绘制。
- 960×360 overlay 只做低 alpha 的织框/经线/地面阴影，没有大面积亮斑；
  玩法金/青、紫弹、预警线都在其上层。
- 预警时长 0.55 / 0.65 / 0.80 s，均高于任务要求的 0.3 s；测试直接断言
  这些常量与真实 spawn。参考中没能核看到 60 fps 视频，这一点见下。

## 证据路径（本机）

- `D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-ikaruga-gameplay-2026-11-26.jpg`
- `D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-celeste-seeker-2026-11-26.gif`
- `D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-badeline-frames-2026-11-26.png`
- `D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-cuphead-brineybeard-2026-11-26.png`
- `D:/godot game/星核旅人/.openchamber/screenshots/loom-ref-taisei-danmaku-2026-11-26.png`

这些只是核看证据，不属于 DLC 运行素材，不随工程分发。

## 未核实 / 边界

- 没有运行 Ikaruga / Celeste / Cuphead / Taisei 本体；没有核听它们的音效与
  音乐，也没有核看 Ikaruga 的连续弹幕视频。Ikaruga 只有一张静态实机图，
  Celeste 有 Seeker 单帧 GIF 与 Badeline 53 帧 GIF，Cuphead 只有一张静态图。
- 因此“0.3 s 预警在连续运动中是否足够”没有外部视频证据；本章以
  0.55/0.65/0.80 s 的余量 + 真实测试核验来降低风险，仍需要人工试玩终审。
- 未从参考中提取任何像素、调色板、字体、音效或动画；所有新素材均为
  `gen_assets.py` 原创绘制/合成。
- 120 Hz / 高刷新率下的像素对齐只做了 640×360 截图核看，未做多分辨率
  逐帧终审。
