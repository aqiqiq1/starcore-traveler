# DLC2 开场电影参考记录（2026-11-27）

## 实际看过的证据

| 来源 | 身份 | 实际观察 | 证据 |
| --- | --- | --- | --- |
| https://wikirby.com/wiki/Dark_Mind | 《Kirby & The Amazing Mirror》Dark Mind 条目（官方美术 + 实机截图） | 镜世界实体从人形变为巨大眼球：黑色巩膜、金色/橙色虹膜、竖瞳、火焰状外圈；两手各持一面六角镜。 | `C:\Users\aqiqiqi\AppData\Local\Temp\opencode\refs\dark_mind_spirit.png`、`katam_intro7.png`、`darkmind_form2.png` |
| https://cdn.wikirby.com/e/e3/K%26TAM_Dark_Mind_Battle_Form_2.png | 第二形态实机战斗画面 | 眼球占据画面右上方，中央竖瞳与亮虹膜在暗底上最亮；镜面/火焰边框把视线压向瞳孔。 | 同上 |
| https://cdn.wikirby.com/f/f5/KatAM_Intro7.png | 第一形态开场实机画面 | 两面手持镜与人物分列左右，中央是暗色主体；先读两面镜，再读核心眼。 | 同上 |
| https://pixelguides.org/chrono-trigger/the-kingdom-of-zeal-and-mt-woe/ | 《Chrono Trigger》Zeal Palace / 走廊实机（256×224 / 256×256） | 走廊是冷蓝绿石构压到近黑，靠竖向柱、门洞压边和青色灯带读出空间；王座厅则用暖棕石、紫地毯和更亮的金边。两者都把金饰控制在一两像素的细线。 | `dlc/art_audit_20261127/references/ct_zeal_corridor.png`、`ct_zeal_palace_hall.png`、`ct_zeal_throne.png`（研究副本） |
| https://www.vgmuseum.com/mrp/stage-sotn.htm | 《SotN》Marble Gallery 实机 | 暗石面用 1 px 顶边亮线、底边暗缝和柱头/柱基建立体块；大面积暗面留白，细节只在边界。 | `dlc/art_audit_20261127/references/sotn_marble_gallery_01.png`、`_02.png` |

## 能借鉴

- 镜/眼同体：先给暗镜框，再让瞳孔在镜心亮起，最后两面盘从左右依次亮。
- 暗巩膜 + 亮虹膜 + 竖瞳的高对比读法；眼眶比眼白更暗，眼睑线用 1-2 px 深边。
- 两面盘对称分布，先金后青，符合本章 Boss 的金/青面盘语言。
- 极暗工坊用“横向木梁 + 垂链 + 地面冷光带”建立房间尺度：链节用 4×6 / 6×4 的交替描边，镜面用两根短链吊在梁下，避免大圆盘悬空。
- 镜面/面盘的外圈加 1 px 冷亮边、内侧加 1 px 暗环；相位波用 5–7 px 的低 alpha 填充弧带 + 1 px 弧脊，而不是两条细线。

## 不能照搬

- 不复制 Kirby 角色、六角镜造型、橙红火焰配色或 Boss 动作。
- 不复制 Zeal 的王座、魔法阵、具体门形、灯带布局或原游戏像素；也不把 SotN 的钟柜/雕像搬进工坊。
- 本片使用本章自己的 `mirror_boss_128x112_8f.png` 边框与 48×48 金/青面盘；眼睛、眼睑、链、木梁、地面与相位波为原创绘制。

## 未核实项

- 未取得“眼睑逐帧张开”的连续视频；开合曲线是按参考的最终眼形与瞳孔关系自行设计的。静态帧只能支持“暗底亮瞳、竖瞳、镜框包裹”的结论。
- 镜面/心跳声为程序化原创音，不是游戏原声。
