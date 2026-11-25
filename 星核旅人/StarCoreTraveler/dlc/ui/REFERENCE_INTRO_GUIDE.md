# DLC 开场说明页 · 参考核看记录（2026-11-25）

本记录只对应“两关开始时的多页操作说明面板”。实际打开过的画面见
`tests/out/ref/`（临时参考图，放在 `out/.gdignore` 下，不参与导入、不打包）。

## 实际打开的画面

1. **Celeste · Tutorial prompt（游戏内教学提示）**
   - 来源：<https://interfaceingame.com/screenshots/celeste-tutorial/>
   - 原图：<https://interfaceingame.com/wp-content/uploads/celeste/celeste-tutorial.jpg>
   - 证据：`tests/out/ref/celeste_tutorial.jpg`（1920×1080）
   - 实际观察：近黑/深色面板，浅色 1–2 px 边框，标题用高饱和强调色，
     按键与动作分成两行；面板贴近被教学的对象，不遮挡整个画面。
   - 可借鉴：深色底 + 单一强调色标题 + 按键行与说明行分开；信息层级靠颜色和
     留白，不靠额外贴图。
   - 不照搬：字体、Celeste 的蓝白配色、气泡尾巴造型、具体文案与教学节奏。

2. **Celeste · Paused（暂停菜单）**
   - 来源：<https://interfaceingame.com/screenshots/celeste-paused/>
   - 原图：<https://interfaceingame.com/wp-content/uploads/celeste/celeste-paused.jpg>
   - 证据：`tests/out/ref/celeste_paused.jpg`（1920×1080）
   - 实际观察：打开时世界被压暗、暂停内容居中；菜单用近黑半透明底、
     手绘感浅色边框；当前项用金黄色，其余白色；层级靠颜色而非多重卡片。
   - 可借鉴：暂停时压暗场景、近黑面板、金色标题/高亮、12 px 正文字号的可读性。
   - 不照搬：手绘边框形状、Celeste 的字体/配色/菜单布局、暂停菜单的条目数量。

## 与本次实现的对应

- 本项目的面板沿用已批准的 trial/rift HUD 与 `mechanic_popup.gd`：
  560×236、近黑底、2 px 灰青边框、金色标题、12 px 正文/按键行。
- 左侧 160×90 示意图全部用 `draw_rect` 画 1× 像素门/紫幕/光桥/守卫色点，
  没有引入外部 UI 图片、没有改基础弹窗。
- 翻页/跳过交互写成 DLC 共用的 `dlc/ui/dlc_guide.gd`，复用 `SkipHoldBar`。

## 未核实 / 局限

- 只核看了上述两张 Celeste 画面；没有逐帧核看其翻页或长按跳过的动画，
  因此“多页翻页节奏”没有直接视频证据，只用本项目 mechanic popup 的既定交互。
- 未做真人可读性终审；只按本项目 640×360 实际渲染截图检查。
