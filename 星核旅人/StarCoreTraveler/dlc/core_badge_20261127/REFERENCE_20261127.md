# 星核/结算标识修正 · 参考实看记录（2026-11-27）

本轮只改素材与标识，不动玩法数值。参考用于两件**新呈现**：结算页城门徽记、
浮动平台启动装置的核；星核去金环/去 +/− 是减法，按主人指定边界执行。

## 1. 外部实际打开/查看

| 来源 | 身份 | 实际观察 | 能借鉴 | 不能照搬 |
| --- | --- | --- | --- | --- |
| `https://store.steampowered.com/api/appdetails?appids=1145360` → `https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1145360/ss_c0fed447426b69981cf1721756acf75369801b31.1920x1080.jpg`（2026-11-27 打开并下载实看） | Hades（Supergiant Games）官方 Steam 截图 | 左侧竖排祝福/纪念品栏：每个图标是深色石质方牌 + 1 px 金线边框 + 单一金色符号；图标尺寸很小，仍靠“外框 + 中央剪影”读出身份，没有大面积发光。左下有红色生命条与圆形小图标。 | 32×32 结算徽记也用“深石底 + 细金线 + 单一城门剪影”；金色只做轮廓和少量高光，不靠内部光球。 | 不抄 Hades 的菱形/竖排布局、红黑配色、具体祝福符号或手绘透视。 |
| `screenshots/hud_refs/hades_guidb_mission.jpg`（项目内既有外部参考，已实看） | Hades 实机 HUD 截图 | 顶部任务行左侧有一枚很小的金色菱形徽记，深色底、细金边，文字紧跟其后；大面积暗场里它仍是一个清楚的“任务标记”。 | 结算徽记放在 400×210 面板右上角，尺寸 32×32，和标题/按钮分离；仍能被一眼认作“章末标记”。 | 不照搬 Hades 的菱形轮廓和字体。 |
| `screenshots/hud_refs/deadcells_vitals.jpg`（项目内既有外部参考，已实看） | Dead Cells 实机 HUD 截图 | 左下生命/装备图标是深色方框 + 亮边 + 像素剪影；小图标不靠渐变，靠 1–2 px 轮廓区分。 | 徽记的城门只用 1–2 px 金线，石面只做 1 px 斜角高光；不引入软渐变。 | 不抄 Dead Cells 的方形装备槽和红绿配色。 |

### 未核实 / 失败记录

- `https://hollowknight.fandom.com/wiki/Category:Charms` 页面文本可打开，但图标是
  lazy-load 的 `data:image/gif` 占位；直接下载 `static.wikia.nocookie.net` 的
  `HK_Notch.png` 被 Cloudflare 拦截（返回挑战页，不是图片）。**没有把该 wiki 图标
  当作已核看证据**。Hollow Knight 只作为“圆形护符图标”的候选，不进入本轮设计依据。
- 没有实际游玩 Hades / Dead Cells；上述结论只来自截图，不推断其源码、数值或关卡。

## 2. 从参考落到本轮规格

1. **结算城门徽记**（`assets/ui/icons/completion_gate_emblem_32.png`）：
   - 32×32、最近邻、1:1；深冷石圆牌（`#0d1517`/`#1b2528`/`#2b3537`/`#485558`），
     1 px 斜角高光在左上、暗边在右下；
   - 金线城门：两根 2 px 柱、半圆拱、门槛、顶部小 keystone；门洞保持暗色，
     不填金色、不画中心光球，所以不会读成星核或守卫核心；
   - 石牌外留 1 px 空隙，再画一圈 1 px 淡金细光（四向略亮）；
   - 放在六个结算面板的右上角 `(356,12)`，不移动标题/按钮。
2. **浮动平台启动装置**：保留 `fixed_core_inactive.png` 的石拱壳；用代码在其
   中央画暗色插座盖住旧紫球，再放入共享 `StarCoreVisual`（16×16、12 帧）。
   未启动 = `star_core_locked_12f`，启动 = `star_core_positive_12f`；尺寸/帧数
   与共享核一致。
3. **自由核去环/去符号**：`gen_core_assets.py` 删除固定 1 px 金环；壳层只留
   切面、内芯光和两颗轨道碎屑。`StarCoreCarrier` 删除 `PolarityMark` 节点；
   `StarCoreVisual` 不再画 +/− 徽记。仓体的金环（`core_bay.gd`/base PNG）保留。
4. **核色 = 所供门的相性**：DLC2 月门、DLC3 第二道月门都改用
   `star_core_negative_12f`（澜相/青）；`core_positive=false` 是场景固定值，
   玩家 Q 只改变推/拉方向，不改变核色。

## 3. 证据

- 生成器：`gen_completion_emblem.py`
- 徽记：`assets/ui/icons/completion_gate_emblem_32.png`
- 断言：`verify_core_badge.tscn`（40 项）
- 截图：`screenshots/core_badge_20261127/`（640×360 与最近邻 4× 裁剪，逐张实看）
