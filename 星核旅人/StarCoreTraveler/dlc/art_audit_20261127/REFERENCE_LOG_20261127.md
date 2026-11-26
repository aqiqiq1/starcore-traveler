# 参考核看记录 · 2026-11-27

任务：审计并统一六关背景/前景/地形/窗户/柱/火盆/装饰。按项目规则，先实际打开与本问题直接相关的经典像素城内/云海内景，再设计 DLC3 城内改稿。以下参考只用于观察，**没有裁切、描摹、调色或复制任何第三方像素进运行资产**。

## 1. Castlevania: Symphony of the Night — Marble Gallery

- 来源页：<https://www.vgmuseum.com/mrp/stage-sotn.htm>（2026-11-27 打开）
- 实际画面：
  - <https://www.vgmuseum.com/mrp/cv-sotn/screens/stage-marble1-2.png>
  - <https://www.vgmuseum.com/mrp/cv-sotn/screens/stage-marble1-1.png>
- 证据副本（仅研究，不是运行素材）：`references/sotn_marble_gallery_01.png`、`references/sotn_marble_gallery_02.png`（256×207 / 256×207 游戏截图）
- 实际观察：
  - 深色暖灰石墙、连续重复的拱形壁龛/钟柜；柱子有明确的柱头、柱身竖槽和柱基，金色只作 1–2 px 边线/柱头饰。
  - 画面靠**重复的竖向节奏**和“深墙 + 金边”建立豪华感；墙面上部留黑/留暗，细节集中在柱头和拱缘。
  - 地面对比强烈：深色石材 + 少量亮边，前景不靠大面积纯黑遮罩。
- 能借鉴：重复同尺寸开间、柱头/柱基三段式、金色 1–2 px 尺度、顶部/左侧受光的方向、墙面大面积留暗。
- 不能照搬：钟柜、雕像、具体纹样、原游戏色板与像素；不能把整张截图当背景或纹理来源。
- 未核实：参考站点的截图版权/许可状态；本记录只声明“已实际打开并观察”。

## 2. Chrono Trigger — Zeal Palace（浮空城内景）

- 来源页：<https://pixelguides.org/chrono-trigger/the-kingdom-of-zeal-and-mt-woe/>（2026-11-27 打开）
- 实际画面：
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/zpal1.webp>
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/throne_in.webp>
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/oc_zeal0_01.webp>
- 证据副本（仅研究）：`references/ct_zeal_palace_hall.png`（256×224）、`references/ct_zeal_throne.png`（256×224）、`references/ct_zeal_corridor.png`（256×256）
- 实际观察：
  - 浮空城内的石构是**冷蓝紫/青绿**体系，墙面暗、玻璃/灯带亮青；地面与人流区域用暖棕/紫色地毯拉出温度对比。
  - 大厅用严格的左右对称和深色门洞建立纵深；金饰是细线，不铺满。墙面/地面交界有明确的踢脚/压边，不靠一条黑带。
  - 走廊/王座厅的开放留白很大，装饰集中在拱、门、地毯边，像素颗粒不密。
- 能借鉴：冷石 + 暖金/紫的互补关系；青绿玻璃/灯带作为“云海光”；深门洞用层次和边框而不是纯黑；地面与墙面的压边。
- 不能照搬：王座、魔法阵、具体门形、人物/怪物、原游戏像素与布局。
- 未核实：参考页的截图来源许可；只作观察。

## 3. 本工程已批准资产（直接基准）

- `assets/backgrounds/cloud_ruins_ds03/art_assets/base_sky_640x360.png`：顶部 `#2d5a70` 左右到下部 `#78a5ae` 的垂直天空；实际样本 `(45,90,112)`→`(120,165,174)`。
- `assets/backgrounds/cloud_ruins_ds03/common/sea_main.png`：云海主色 `(133,173,181)` / `(135,174,182)`。
- `assets/backgrounds/cloud_ruins_ds03/art_assets/g1_left_bridge.png`、`g2_right_bridge.png`：远景石桥剪影为冷青灰，轮廓清楚但细节少。
- `assets/bridge_stone_v1/generated/l2_ground_1792x40.png`：正式关石材色阶 `(76,67,73)`、`(94,82,87)`、`(112,99,101)`、`(124,110,109)`、`(136,122,120)`、`(147,132,127)`、`(159,146,138)`、`(172,160,151)`，1 px 砖缝、顶部 1 px 亮边。
- `assets/bridge_stone_v1/columns/doric_column_tall_basesquare.png`：52×108，柱头/柱基外扩，左亮右暗，金色/暖灰高光。
- `dlc/PRESENTATION_SYSTEM.md` 第 6 节：同一套石墙/砖缝/壁柱/拱窗/金饰/青紫玻璃/暖火盆尺寸与色阶；共享光照方向、颗粒密度、暗角；窗户同图案、无黑斑。

## 4. 对本轮改稿的直接结论

1. DLC3 旧墙面 `(84,71,58)`/`(104,88,70)` 偏黄棕，和 L2/L3 的灰紫石 `(76,67,73)`–`(172,160,151)` 不是同一色阶 → 改到 L2 石色族。
2. 旧窗玻璃 `NIGHT=(18,14,30)`、`NIGHT_2=(28,20,46)`，且左侧/中部/右侧三扇宽度/位置不同（86–212、278–404、862–942），是“黑斑/不同图案”的直接原因 → 三扇统一为 126×204 的同一模块，玻璃用 DS03 天空/云海色，近黑像素占比 0。
3. 旧窗框/壁柱/火盆的比例各自为政（壁柱 22 px、窗框 4–7 px、火盆 28×44）→ 壁柱改为 40 px 柱身 + 44 px 柱头/柱基；窗框 6 px + 1 px 金线；火盆保持 28×44 并把它对齐到壁柱中线。
4. DLC1/2 的云海与 DLC3 的过渡不能靠再加一层雾；最直接的连接是**从城内窗里看到同一片 DS03 天空/云海**，并在墙脚保留冷光/暖火对比。
