# 星核 / 星核仓 像素资产升级 · 参考与落地记录（2026-11-27）

范围：只改 `assets/star_core/` 与 `assets/star_core_bay/` 的画面，以及为了让
空仓/满仓明暗成立所需的最小视觉加载（`scripts/star_core_bay_visual.gd` 的
`modulate`）。**没有改玩法、碰撞、数值、状态机、场景坐标。**

尺寸和帧布局全部保持原样：

- 星核单帧 16×16，12 帧横排 192×16；正相/负相/锁定三套都在。
- 静态回退图 16×16。
- 星核仓 base / glass / empty 均为 32×32。
- `StarCoreVisual` 的 `SOURCE_SIZE=16×16`、`SOURCE_SHEET_SIZE=192×16`、
  `FRAME_COUNT=12` 未改；`StarCoreBayVisual` 的 `PEDESTAL_TOP_Y=8`、核心
  16×16 透明窗口约定未改。

---

## 1. 实际核看的参考（先看后画）

### 1.1 CrossCode 官方 press kit：光球 / 开关

来源页：<https://www.radicalfishgames.com/presskit/sheet.php?p=crosscode>
（2026-11-27 打开；图片直链见下）

| 证据 | 实际打开/观察 | 能借鉴 | 不能照搬 |
| --- | --- | --- | --- |
| `references/3-uber-bounce-switch-puzzle-2.png`（1136×640，官方截图） | 深蓝灰石厅；关闭/待机的开关是暗色方槽/菱形槽，槽内有紫色或青色菱形嵌片；槽的几何边框与光球尺寸贴合；环境低饱和，亮色只出现在开关和光球上。 | “暗槽 + 一圈几何亮边”暗示可放入物；亮起只发生在槽/连线局部，不整屏泛光。 | 不抄俯视角度、紫/青具体配色、UI、地砖与机关造型。 |
| `references/crosscode_bounce.gif`（54 帧，440×172）及抽帧 `crosscode_bounce_sequence.jpg`（0/9/18/27/36/45）、`crosscode_bounce_16.png`、`crosscode_bounce_43.png` | 光球中心是白热像素，外面只有很短的青色菱形拖尾/碎屑，不是整团模糊光；球飞行时拖尾和球体分离成离散像素；落位/弹跳后开关才局部变色。 | 白热心 + 2–3 个分离的碎屑/短拖尾；核心与拖尾分层，不用整帧平移冒充运动。 | 不抄 CrossCode 的 16-bit 调色板、精灵像素、俯视视角、球/开关外形。 |
| `references/crosscode_bounce_sequence.jpg` | 同一 GIF 的连续抽帧：光球在画面左侧到中央移动，白心始终最亮，青色碎屑沿路径留下；开关的紫色嵌片在暗槽里保持几何轮廓。 | 12 帧里让“核心亮度”和“外层碎屑位置”分开变化；核心不随帧移动。 | 不把抽帧当素材、不描摹任何像素。 |

### 1.2 Hyper Light Drifter 官方 Steam 截图：发光装置

来源：Steam 商店页（app 257850）官方截图（2026-11-27 打开）
<https://store.steampowered.com/app/257850/Hyper_Light_Drifter/>

| 证据 | 实际打开/观察 | 能借鉴 | 不能照搬 |
| --- | --- | --- | --- |
| `references/hld_glowing_orbs_steam.jpg`（1920×1080，官方截图） | 两个巨大粉色光球嵌在暗色石/金属装置顶部；球心接近白色，粉色光晕很大且软，向周围溢光；装置本身有明确的暗色圆环/支架；环境大部分低饱和，只有装置发光。 | “暗装置框住亮核心”的层级；白热心 + 大范围局部光晕；环境让色。 | 不抄品红/绿配色、软抖动(dither)光晕、俯视构图、具体机械造型。 |
| `references/hld_glowing_core_door_steam.jpg`（1920×1080，官方截图） | 暗色门体中央有绿色光池，门框两侧是一排红/橙发光小灯；发光被暗金属框分割成局部块，不是整屏发光。 | 发光装置要有“暗框 + 局部亮块 + 地面/底部溢光”；亮部集中在装置内部。 | 不抄其灯列、门形、绿/红配色与像素颗粒。 |

### 1.3 本工程内的对照（连续性与问题定位）

| 证据 | 实际观察 | 结论 |
| --- | --- | --- |
| `screenshots/opening_l1_20261127/05_star_core_handoff.png`（640×360，旧版） | L1 电影 18.85 s、1.7× 变焦；星核在主角胸前只是一个小金色形状，和主角的金色胸带混在一起；旧 12 帧是“金盘转成竖线”的硬币，缺少内芯/切面/外环。 | 星核必须在 1.7× 下仍有“亮心 + 暗轮廓 + 环”的读法；L1 只用 0–3 帧，这四帧必须是完整球体。 |
| `references/old_core_positive_8x.png`（由 `original/star_core_positive_12f.png` 生成） | 8× 最近邻：旧 12 帧是同一枚金色圆盘逐渐转薄，只有明暗渐变，没有独立核心、没有外环、没有碎屑。 | 用户说的“纯色圆点/太简陋”属实；需要三层结构，而不是给旧盘加描边。 |
| `references/old_bay_full_8x.png`、`old_bay_empty_8x.png`（由原 base/glass/locked core 生成） | 旧 base 是底部 8 px 的白色平板，只有一条金色小十字；旧 glass 是 1 px 淡青拱形线，内部几乎全透明；满仓 = 白板 + 青线 + 紫色硬币。 | 缺少石座倒角/暗缝、金属框高光、玻璃斜反光/内侧暗角；空仓没有金环暗示。 |
| `screenshots/loom_core_wisp_20261127/01_core_before_bay.png`、`03_core_seated_lit.png`（旧版，本轮开始前实看；同名文件已被本轮新 captures 覆盖） | DLC3 640×360：空仓是暗龛 + 金色核心环，满仓时白色基座 + 玻璃罩亮起；旧星核仍像金色硬币，玻璃像一圈青色线。 | DLC3 的“暗→亮”状态机本来成立，本轮只提升星核/仓的材质层次，不改 LoomCoreBay 的状态逻辑。 |

> 说明：以上外部图片只作研究证据，放在 `references/` 并带 `.gdignore`，不会进入
> 游戏导入；没有裁切、描摹、调色或复制任何第三方像素到运行资产。CrossCode 图片
> 来自官方 press kit 页面、HLD 图片来自官方 Steam 商店页，但**未核实其再分发
> 许可**；本记录只声明“已实际打开观察”，不把它们当作可复用素材。

---

## 2. 从参考落到本轮的像素规格

### 2.1 星核（16×16 × 12 帧，三态同构）

三层，从内到外：

1. **内芯光**：2×2 白热心（`#fffadc` 附近），四向 1 px 暖色 halo；核心始终在
   画面中心，不随帧平移。
2. **切割面**：10–11 px 的 superellipse 宝石体，正面有左侧亮面、中央台面、
   右侧暗面、底部亭部；1 px 深色 girdle 线和明暗边。帧 0–3 保持宽面，满足
   L1 电影只用前四帧的现有行为；帧 5–7 收成竖立薄片；帧 8–11 再展开。
3. **外环/碎屑**：半径 6.9 px 的 1 px 金环（固定不位移、不旋转），两段亮弧
   + 两颗粒子；金环使用既有金色，不引入新强调色。负相/锁定态同样保留金环，
   让“这是星核”先于“这是哪种相性”被读出。

亮度呼吸：亮度按 12 帧一个正弦周期变化（trough 在 F08 附近），台面/金环/内芯
halo 一起变暗，但核心位置不动、轮廓不整体平移。F02 与 F08 的差异在 4× 接触表
上可直接看出。

### 2.2 星核仓（32×32 base + 32×32 glass）

- **base**：石座保持 `PEDESTAL_TOP_Y=8`（图像 y=24）；新增顶板 1 px 亮边、
  倒角、顶板下的暗缝、腰部/底脚的明暗分层、两端 1 px 黄铜嵌条。顶面中央是
  一个浅椭圆暗槽 + 暗金环，空仓时读“金环暗示”，满仓时核心盖住中心。
- **glass**：重建为 32×32 钟形罩；外圈 1 px 黄铜框（左上亮、右下暗），
  内侧 1 px 淡青玻璃唇、斜向双像素反光、左右内侧暗角，以及底部的 1 px
  黄铜窗台。**图像 x=8..23、y=8..23 的 16×16 区域保持 alpha=0**，与
  `StarCoreBayVisual` 的核心透出约定一致。
- **空/满**：`StarCoreBayVisual` 在 `occupied=false` 时把 base 调到
  `Color(0.64,0.68,0.69)`，`occupied=true` 时恢复纯白；玻璃仍由原有的
  开合 shader 控制。LoomCoreBay 自己的 `0.55 → white` 明暗和代码绘制的
  金环/缝隙/导线未改，二者叠在一起就是“仓从内部亮起，不只是核”。
- 色板：金 `#f4cd63`、青 `#5fe1e6`、既有紫、L2/L3 冷灰石族；没有新增
  强调色。暗部用暖褐/深青/深灰，不压成纯黑块。

---

## 3. 资产变更（同名覆盖；原图保留）

原图先复制到 `dlc/core_art_20261127/original/`（带 `.gdignore`），再覆盖运行时
文件。新图由 `dlc/core_art_20261127/gen_core_assets.py` 确定性生成。星核三态仍
是 Frakassets `gem_round_16x16_12f`（CC BY 4.0）的派生资源，`ASSET_CREDITS.md`
已补“2026-11-27 已修改”说明，署名义务不变。

| 运行资产 | 尺寸 | 新 SHA256（前 16） | 旧 SHA256（前 16） |
| --- | --- | --- | --- |
| `assets/star_core/star_core_positive_12f.png` | 192×16 | `ae102c24a778178a` | `282e668fa72ed504` |
| `assets/star_core/star_core_negative_12f.png` | 192×16 | `de59fa705f37e349` | `e99fab67c35cdc9c` |
| `assets/star_core/star_core_locked_12f.png` | 192×16 | `7d4f93ba6ff99006` | `1a7f8bfcb6f2c770` |
| `assets/star_core/star_core_positive.png` | 16×16 | `f8587789936c17f3` | `9a72e93bc6de4eff` |
| `assets/star_core/star_core_negative.png` | 16×16 | `7e78d4de3f24db59` | `b21b819251b1f067` |
| `assets/star_core/star_core_locked.png` | 16×16 | `aa5784eba229c0a4` | `40a36f519bc495f2` |
| `assets/star_core_bay/star_core_bay_base.png` | 32×32 | `5b1997970e235579` | `a43f68e93af9d5df` |
| `assets/star_core_bay/star_core_bay_glass.png` | 32×32 | `a5d97466bc8d02e3` | `f65d4277b7b41569` |
| `assets/star_core_bay/star_core_bay_empty.png` | 32×32 | `5b1997970e235579` | `35a4fa6deca16b74` |

`star_core_bay_empty.png` 现在是“石座 + 金环槽”的空仓预览，不再叠一层常驻
玻璃；运行时共享组件在空仓会把这块石座 modulate 压到 0.64，所以实景是暗的。

代码改动只有一处：`scripts/star_core_bay_visual.gd` 的 `_refresh_visual()`
按 `occupied` 调 base 的 `modulate`；不改 z 序、碰撞、状态机或场景。

---

## 4. 验收证据

- 640×360 实景：`screenshots/core_art_20261127/`
  - `01b_l1_core_in_flight.png`：L1 电影 18.40 s，星核从石碑飞向主角。
  - `01_l1_handoff.png`：L1 电影 18.85 s，真实 handoff。
  - `02_l3_bay_empty.png`：L3 TargetBay 空仓（暗石座 + 金环槽 + 开罩）。
  - `02b_l3_bay_locked.png`：L3 StartBay 满仓（白基座 + 金框玻璃 + 紫核）。
  - `03_dlc3_before.png` / `04_dlc3_after.png`：DLC3 真实玩法 capture
    （`capture_mechanics.tscn`，`core=288.4 bay=false` → `core=330.0 bay=true`）。
- 4× 最近邻：`star_core_12f_4x.png`（12 帧 + F00–F11 标签）、
  `star_core_bay_states_4x.png`（L3 空/满 + DLC3 前/后）。
- 断言：`dlc/core_art_20261127/verify_core_art.tscn`，0 failures；12 帧仍可播、
  11→0 循环回绕、帧数/单帧尺寸不变、空仓 dim/满仓亮、LoomCoreBay 空/满切换通过。
- 导入：`dlc/core_art_20261127/import_20261127.log`，0 ERROR。
- 三章 run_all：`run_all_trial.log`、`run_all_rift.log`、`run_all_loom.log`
  全部 exit=0 / problems=0；三份都包含 `level_01/02/03_90`，即本体三关
  90 帧各跑三遍全绿。
- DLC3 真实玩法 capture：`capture_mechanics_after.log` 的
  `FRAME 01/03/04 state=ok`，`core=288.4 bay=false` → `core=330.0 bay=true`。
- L1 开场完整测试：`opening_l1_after_core.log`，`OPENING_L1_TEST checks=133
  failures=0`，含 “first star core was handed over / real stele was touched”。

---

## 5. 未核实 / 需主人确认

1. **外部参考只做静态/抽帧观察**：没有实际游玩 CrossCode 或 Hyper Light
   Drifter 的完整关卡；HLD 的光晕是软抖动，本工程 16×16 只能做 1 px 金环 +
   离散碎屑，不能等同其柔光。若要求更强的 HLD 式溢光，需要另开屏幕后处理/
   shader 任务。
2. **没有找到可直接对照的侧视像素“星核入仓”原片**：本工程的“基座—核心—
   玻璃”空间关系仍以 `StarCoreBayVisual` 的既有三层为准；CrossCode/HLD 只
   支持“暗装置 + 亮核心 + 局部亮起”的通用读法。
3. **空仓调暗是新视觉行为**：共享 `StarCoreBayVisual` 以前空仓仍显示亮白
   基座；本轮按“空仓暗但有金环暗示”把 base modulate 压到 0.64。若主人认为
   L1/L3 的空仓应该保持原来的亮白，可只回退这一行 modulate，不影响 PNG。
4. **L1 handoff 的遮挡是既有电影位置**：星核落点在主角胸前，会和金色胸带
   重叠；本轮只保证 1.7× 下仍能看出金环 + 白心，没有改电影位置/时长。
5. **DLC3 空仓的“金环”主要由 LoomCoreBay 代码绘制**；共享 base 新增的
   金环槽在 DLC3 低位基座上也有，但被代码龛口部分遮住。若要统一的空仓
   读法，需要主人确认是否允许动 LoomCoreBay 的绘制层。
