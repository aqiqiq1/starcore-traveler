# DLC 开场说明页 · 参考核看记录（2026-11-25）

本记录只对应“两关开始时的多页操作说明面板”。实际打开过的画面见
`tests/out/ref/`（临时参考图，放在 `out/.gdignore` 下，不参与导入、不打包）。
这些外部图只用于 UI 框体的阅读方式，**不是**说明页左侧的演示素材。

## 本轮变更：左侧从示意图改为实拍

- `dlc/ui/dlc_guide.gd/.tscn` 左侧原为 160×90 代码绘制示意图，已删除。
- 现在为 **256×144 实机演示窗**，播放 **24 帧 / 8 fps** 的真实关卡循环，
  与基础 `mechanic_popup.gd` 一样使用横向帧条 + `AtlasTexture`。
- 六条帧条由 `dlc/ui/tools/capture_guide_demos.gd/.tscn` 从正式
  `trial_chambers.tscn` / `rift_workshop.tscn` 实拍，写入 `dlc/ui/demos/`：
  - `trial_gate`：真实 Q 打开金门并穿过；
  - `trial_gate_inside`：门内 Q 切相，防夹保持可穿过，离开后闭合；
  - `trial_guard_hit`：守卫既有 `GRAVITY_CHARGE` + 真实 J 命中，真伤 3→2；
  - `rift_inversion`：走进紫色反转场，自动翻相；
  - `rift_bridge`：真实 Q 让金桥实化，再 Q 消失并落到下层；
  - `rift_twins`：双守卫开场悬浮，随后金守卫蓄力 + 真实 J 命中，两条血条同框。
- 每条帧条是同目录 PNG + JSON（`frames=24`、`fps=8.0`、`frame_width=256`、
  `frame_height=144`、`crop`、`camera`、`source`、`note`）。
- 缺失帧条时 256×144 窗口显示“演示缺失”占位与页面文字，不画示意图、不报错；
  页标、F、短按空格、长按空格跳过、Esc 逻辑不变；切页重置到第 0 帧。

## 实际打开过的 UI 参考

1. **Celeste · Tutorial prompt（游戏内教学提示）**
   - 来源：<https://interfaceingame.com/screenshots/celeste-tutorial/>
   - 原图：<https://interfaceingame.com/wp-content/uploads/celeste/celeste-tutorial.jpg>
   - 证据：`tests/out/ref/celeste_tutorial.jpg`（1920×1080）
   - 实际观察：近黑/深色面板，浅色 1–2 px 边框，标题用高饱和强调色，
     按键与动作分成两行；面板贴近被教学的对象，不遮挡整个画面。
   - 可借鉴：深色底 + 单一强调色标题 + 按键行与说明行分开；信息层级靠颜色和
     留白，不靠额外贴图。
   - 不照搬：字体、Celeste 的蓝白配色、气泡尾巴造型、具体文案与教学节奏。
   - **不把这张图作为演示素材**；演示素材只来自本项目正式关卡实拍。

2. **Celeste · Paused（暂停菜单）**
   - 来源：<https://interfaceingame.com/screenshots/celeste-paused/>
   - 原图：<https://interfaceingame.com/wp-content/uploads/celeste/celeste-paused.jpg>
   - 证据：`tests/out/ref/celeste_paused.jpg`（1920×1080）
   - 实际观察：打开时世界被压暗、暂停内容居中；菜单用近黑半透明底、
     手绘感浅色边框；当前项用金黄色，其余白色；层级靠颜色而非多重卡片。
   - 可借鉴：暂停时压暗场景、近黑面板、金色标题/高亮、12 px 正文字号的可读性。
   - 不照搬：手绘边框形状、Celeste 的字体/配色/菜单布局、暂停菜单的条目数量。
   - **不把这张图作为演示素材**。

## 与本项目实现的对应

- 面板沿用已批准的 trial/rift HUD 与 `mechanic_popup.gd`：
  560×236、近黑底、2 px 灰青边框、金色标题、12 px 正文/按键行。
- 左侧演示窗口 256×144，与基础机械弹窗相同；帧条从正式场景录制，
  没有拼假动画、没有外部游戏截图。
- 翻页/跳过交互写成 DLC 共用的 `dlc/ui/dlc_guide.gd`，复用 `SkipHoldBar`。

## 未核实 / 局限

- 只核看了上述两张 Celeste UI 画面；没有逐帧核看其翻页或长按跳过的动画，
  因此“多页翻页节奏”没有直接视频证据，只用本项目 mechanic popup 的既定交互。
- 帧条是 8 fps 采样（24 帧/3 秒），不是 60 fps 录屏；动作节奏以实际采样为准。
- 未做真人可读性终审；只按本项目 640×360 实际渲染截图检查。
