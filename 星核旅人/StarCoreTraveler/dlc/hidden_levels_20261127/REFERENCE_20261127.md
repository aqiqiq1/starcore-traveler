# 隐藏关入口 · 呈现参考核看（2026-11-27）

任务：在两段主线场景里各放一个**可选、不挡路**的支线入口。DLC3 用现有裂隙/镜面素材做“镜面裂隙”，L3 用现有试炼碑素材做“试炼碑”。本次不新画 PNG；本记录只用于构图与读法，第三方图不进入运行资产。

## 1. 实际打开并查看的参考

### A. Hollow Knight · White Palace 王座室 lore tablet（实际游戏截图）
- 来源页：<https://hollowknight.wiki/w/White_Palace>
- 图片地址：<https://cdn.wikimg.net/en/hkwiki/images/thumb/c/c4/Screenshot_HK_White_Palace_10.png/800px-Screenshot_HK_White_Palace_10.png>
- 画面身份：White Palace 王座室，深处的 lore tablet 与周围黑暗石室；实机截图，不是宣传图。
- 研究副本：`references/hk_white_palace_lore_tablet_room.png`
- 实际观察：房间整体压得很暗，碑是画面里唯一稳定的发光物；碑立在低矮台座上，靠一块亮面把视线拉过去；周围平台/地面没有被碑挡住，玩家仍可从旁边通过。构图是“暗石包围一个亮面”，不是一块高亮矩形贴图。
- 能借鉴：入口本体用低亮度的冷石框承托一个局部亮面；提示不常驻；碑/镜放在背景层，玩家和检查点始终在前景。
- 不能照搬：Hollow Knight 的碑形、纹样、黑白高对比、房间布局和像素；本作的试炼碑是现有 26×52 青色碑，镜面是 DLC2 的青色破镜。

### B. Hollow Knight lore tablet 近景
- 图片地址：<https://cdn.wikimg.net/en/hkwiki/images/thumb/7/7c/Lore_White_Palace_1.png/400px-Lore_White_Palace_1.png>
- 画面身份：同一游戏的 lore tablet 近景；深色椭圆石体、发光刻线、低矮石座，背景是书柜/器物。
- 研究副本：`references/hk_lore_tablet_closeup.png`
- 实际观察：亮部只在石体刻线内，不是整块发光；底座有明确的接触/投影，碑不是浮在空中。背景比碑更暗，但仍有可读的横向层次。
- 能借鉴：本作试炼碑保持 1:1 原生尺寸，只加低透明青色 bloom 和细小上升火花；用 6 px 石座和地面阴影落地。
- 不能照搬：碑体轮廓、白色高光、书柜背景；本作使用自己的 `assets/tutorial_stele/tutorial_stele_cyan.png`。

### C. Bloodstained: Ritual of the Night · 彩绘玻璃/传送门读法（宣传关键图）
- 来源页（YouTube 封面所属视频页）：<https://www.youtube.com/watch?v=16itK3r7Bww>
- 图片地址：<https://img.youtube.com/vi/16itK3r7Bww/maxresdefault.jpg>
- 画面身份：Bloodstained: Ritual of the Night 的宣传关键图，背景是彩色玻璃窗/圆形花窗，不是实机玩法截图。
- 研究副本：`references/bloodstained_portal_key_art.jpg`
- 实际观察：石框/拱形内嵌圆形花窗，中心有明确的放射状分割和色块；圆形玻璃在暗色石构里有“入口/传送”的天然读法。
- 能借鉴：只借鉴“圆镜面 + 冷石框 + 细缝光”的静态构图关系，让 48×48 的青色破镜成为入口的视觉中心。
- 不能照搬：这是宣传图不是玩法证据；不采用其彩窗纹样、人物、配色或任何像素。**未核看该作实际传送门交互画面**，因此不据此声称运动/交互读法。

### D. 本工程现有画面（直接、可核看）
- `screenshots/rift_opening_20261127/01_mirror_hall_wide.png`：DLC2 镜厅实机画面；暗色拱形墙洞、木柱、壁灯和悬挂圆镜。用于确认镜面入口应嵌在冷石墙里、保持暗背景，不另造高亮门框。
- `screenshots/art_audit_20261127/after/level_03.png`：L3 城门前实机画面；天空废墟、低石栏、暖色城门。用于确认试炼碑放在城门前左侧地面时，青色碑面能从暖色城墙前读出来。
- `assets/tutorial_stele/tutorial_stele_cyan.png`、`dlc/rift_workshop/assets/sprites/mirror_face_cyan_broken_48x48.png`：实际运行素材的原尺寸/像素信息。

## 2. 落到本次实现的边界

- 两个入口都是**背景层、无碰撞**的节点；玩家/检查点/守卫始终在前。入口不改变主线路线，不新增动词，只在 56 px 内显示一次短提示，E 进入。
- DLC3 的镜面裂隙放在检查点 x=410 与 Boss 触发 x=430 之间（x=420），下半部会被检查点/玩家遮住是预期的前景关系；圆形破镜和细缝仍从上方读出。
- L3 的试炼碑放在城门前 x=2250（离终点 2460 约 210 px），原生 26×52，落在现有 CityGround 上，不使用新几何。
- 没有把 Hollow Knight 的碑形/白高光、Bloodstained 的彩窗纹样或任何第三方像素复制进运行资产。研究副本只用于内部核看。

## 3. 未核实 / 限制

- Bloodstained 的“传送门”只看到宣传图，没有取得可访问的实际交互连续画面；因此本记录只支持静态构图，不支持“原作如何开门/传送”的运动结论。
- Hollow Knight 截图来自 wiki 页面，版权归 Team Cherry；研究副本不进入运行资产、不随导出分发。许可状态未逐项核实。
- 没有对入口做新动画参考；入口自身的火花/缝隙动画是本项目按现有 `loom_fx`、`mirror_face` 语言写的程序化呈现，不声称对应任何原作的帧序列。
