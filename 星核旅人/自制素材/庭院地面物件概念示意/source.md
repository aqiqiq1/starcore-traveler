# 庭院地面物件概念示意（待审核，不是实机）

仅生成 `concept.png`，不修改或导入 Godot 工程。物件拟用于无碰撞后侧装饰；图中地形、人物、石碑只是比例参照，不代表关卡改造方案。未新增玩法、机关、发光、符号、大拱门或背景建筑。

## 来源与许可

- 石材与碎石：Szadi art.，**Pixel Platformer World**，https://szadiart.itch.io/pixel-platformer-world 。本次使用本地既有包，未下载或混用 STONE RUINS。
- 包内许可：`素材库/古遗迹候选/01_szadi_pixel_platformer_world/extracted_map/public-license.txt`；本地页面证据：同包上级 `PAGE_EVIDENCE.md`。
- 许可原文：`Artwork created by Szadi art. License for Everyone. Public domain and free to use, personal or commercial. Credit is not required but appreciated. You can edit, but not sell the asset pack.`
- 这是作者自定义许可文本，允许编辑、个人及商业使用，禁止销售素材包；**不笼统标为 CC0**。公开分发含原始素材的源工程之边界仍由负责人复核。本次仅本地审核概念图，未重新联网确认页面。
- 主角、石碑、护符均为工程现有资产，仅作参照；本次不重新确认其发布授权。文字使用工程 `assets/fonts/tutorial_zh.ttf`，随附 OFL 许可为 `tutorial_font_LICENSE.txt`。

## 裁切与派生记录

坐标为原图左上原点，Pillow 的 `(left, top, right, bottom)` 半开区间；以下均是原像素裁切/拼接，不是整根柱子缩放。

源目录：`素材库/古遗迹候选/01_szadi_pixel_platformer_world/extracted_map/`。

- `main_lev_buildB.png` 较亮暖褐组：
  - 柱头/承托形模块 `(54,272,106,290)`，52×18。高柱上部使用此模块，仅左上局部删除数个像素形成缺口。
  - 砖石柱身模块 `(66,290,94,314)`，28×24。原像素沿纵向重复；高柱柱身72px，断柱柱身64px（最后一段裁取16px）。模块接缝保持砖缝节律。
  - 柱脚使用上述52×18承托模块上下翻转，**这是派生拼接用途，不是原包现成立柱成品**。
  - 高柱总画布52×108，柱头18＋柱身72＋柱脚18；断柱总画布52×82，柱身64＋柱脚18。断柱上方局部透明裁口，辅以1px灰褐断面边；实际可见高度略小于82px。
  - 柱座52×24，由6px柱身及18px柱脚组合；倒落段由56px拼接柱身整数旋转90度，得到56×28，端部局部切缺，底部置于地形后方。
  - 为贴近灰褐岩台，以上柱子构件仅在派生图中做低对比灰褐映射：`L=.299R+.587G+.114B`；`R'=36+.64L, G'=34+.60L, B'=34+.58L`，四舍五入，保留原alpha。不是改动原素材文件。
- `main_lev_buildA.png` 原有小碎石：`(260,40,275,48)`、`(282,40,304,48)`、`(326,40,338,48)`、`(344,40,366,48)`，不缩放。
- 地面直接复用工程 `基础场景原型/assets/map/ruin_platform_tiles.png`（192×32），原来源为A表 `(224,80,416,112)`；1:1平铺。不重绘或修改源地形。
- 人物：`基础场景原型/assets/characters/male_hero-idle.png` 首帧 `(0,0,128,128)`；原实际alpha包围盒 `(41,43,73,80)`，高37px。按既有Sprite偏移 `(-59,-79)` 放置，护符使用既有 `assets/talisman/talisman_gold.png` 叠于帧内 `(64,63)`。
- 石碑：`assets/tutorial_stele/tutorial_stele_grey.png`，26×52，保持原尺寸。
- 背景是低对比灰紫渐变示意，非新增背景资产或定稿；本次读取过 background2/4，但未将其山体/植被引入本图。

## 显示、检查与待定

- 场景640×280逻辑像素，整张以 NEAREST 2倍输出1280×560；文字先按12px绘制后随场景放大。高柱108px约为37px人物的2.92倍，断柱画布82px约2.22倍；所有构件与人物像素尺度一致。
- 源A/B为RGBA，有透明区域；裁切保留alpha，未用矩形黑底填充。已读取生成PNG检查整体比例、接缝、透明边缘、像素锐度与疏密关系。
- 所有立柱、断口、倒落段都是**审核用派生构想**，不是声称作者包中存在完整同款。用户尚未批准色调、断口形状和具体摆位；也未进行Godot导入、实际遮挡或运行验证。

复现：在项目根目录运行：

```powershell
& 'D:\minic\envs\2024212971\python.exe' '自制素材\庭院地面物件概念示意\generate_concept.py'
```

输出仅为脚本同目录的 `concept.png`，不改写源素材。
