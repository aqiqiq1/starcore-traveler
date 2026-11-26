# 基础 UI / 共享说明页 · UiReveal 打磨记录（2026-11-26）

## 2026-11-26 晚补充：1× 不缩放 + 本体 20×20 相位图标

- `UiReveal.PANEL_SCALE_FROM` 改为 `1.0`：只保留遮罩淡入与 5 px 上滑，
  面板不再缩放（文字不经重采样）。下方旧记录中的 0.96 数值已被本段取代；
  `ui_reveal_test` 与共享 `dlc/ui/tests/guide_test.gd` 的断言已同步。
- `scripts/ui/polarity_phase_icon.gd`：20×20 金太阳/青月像素图标；基础三关
  `CompactLevelHeader` 右上角改为该图标，旧“辉相/澜相”文字节点保留为隐藏
  数据镜像。`scripts/ui/tests/phase_icon_test.tscn` 实测 **45 / 0**：三关均为
  20×20、切换即时、每次换相只播一次 `DemoAudio.play_polarity_switch()`。
- 参考记录：`out/REF_BASE_PHASE_ICON_20261126.md`；截图：
  `out/base_phase_level01_sun.png`、`out/base_phase_level02_sun.png`、
  `out/base_phase_level03_sun.png`、`out/base_phase_level02_moon.png`；
  8× 最近邻检查片 `out/base_phase_icons_zoom8.png`。

分支 `dlc`。本轮只改基础 UI 与 DLC 共用说明页，未改 `dlc/trial_chambers`、
`dlc/rift_workshop`、`dlc/star_loom`、`start_menu`、关卡/玩法/碰撞；未 Git 提交/推送，
未导出。章内 HUD 的暂停/完成面板未碰。

## 改动文件

- 新增 `scripts/ui/ui_reveal.gd`（`class_name UiReveal`）：共用遮罩/面板入场与退场。
- `scripts/ui/mechanic_popup.gd`：接入 UiReveal；关闭时 `_open=false`、解除暂停立即生效。
- `scripts/ui/pause_menu.gd`：接入 UiReveal；暂停/恢复、焦点回交立即生效；
  设置页返回时重新入场；`force_close` 直接收束。
- `dlc/ui/dlc_guide.gd`：接入 UiReveal；F/长按空格/Esc 吞掉/关闭逻辑不变。
- `dlc/ui/tests/guide_test.gd`：同步动画断言；RiftGuide 现有 4 页由
  `get_page_count()` 动态驱动，不再硬编码 3 页。
- `scripts/ui/tests/`：基础 UI 验收测试、截图场景、本记录与证据。

## 动画规格（实际实现）

| 项 | 实际值 |
| --- | --- |
| 打开遮罩 | `modulate.a` 0→1，0.18 s，`TRANS_QUAD / EASE_OUT` |
| 打开面板 | `scale` 0.96→1，位置 y +5 px→基准，同 0.18 s |
| 关闭 | 遮罩 1→0、面板 1→0.96、位置基准→+3 px，0.12 s，`EASE_IN` |
| 暂停树 | `Tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` |
| 1× 像素 UI | 不新增缩放层级/模糊/描边；仍为 640×360 逻辑视口，面板中心为 pivot |
| 状态 | 打开/关闭/暂停/焦点都在调用当帧生效，tween 只负责视觉 |

入场使用 0.96→1 和 4–6 px 上滑（实际 5 px），没有回弹、过冲、模糊或屏幕闪白；
退场只保留 0.10–0.14 s（实际 0.12 s）的遮罩淡出和微缩。关闭期间根节点仍可见但
`mouse_filter` 全部设为 `IGNORE`，所有输入判断只看 `_open`，不会延迟恢复。

## 参考核看记录

本轮按要求先联网查看实际画面，再实现：

1. **Celeste（2018，Maddy Makes Games）暂停页**
   - 来源：<https://interfaceingame.com/screenshots/celeste-paused/>
   - 画面身份：正式游戏 2560×1440 暂停截图；世界仍可见但压暗，
     中央边框面板 + 文字行，选中行为亮黄色。
   - 实际观察：暂停不是全屏不透明新页面；世界保留、遮罩压暗、面板边界清楚；
     选中态是颜色变化，不靠放大/抖动。
   - 能借鉴：遮罩先于内容建立、面板保持原布局和焦点色；不能照搬：其字体、
     行距、发光描边与 16:9 构图。
   - 证据：`out/ref/celeste_paused.jpg`；同目录另有教程气泡
     `out/ref/celeste_tutorial.jpg`（Celeste 教程提示的实际画面，用于确认
     1× 像素 UI 的提示尺度）。

2. **Game Jolt 像素游戏暂停/设置 GIF（连续 200 帧）**
   - 来源页：<https://gamejolt.com/p/updates-and-changes-coming-soon-pixelart-cyberpunk-platformer-qk5bxhhk>
   - 原 GIF：<https://i.gjcdn.net/public-data/fireside/posts/19/170/1237420/media/pause_menu-dwm8c7qv.gif>
   - 画面身份：该 Game Jolt 帖的像素赛博朋克平台游戏暂停/设置演示；
     帖内未给出可确认的最终游戏名，按来源页记录，不冒充 Celeste。
   - 实际观察（200 帧、600×338、40 ms/帧；打开 0–24 帧与关闭 170–199 帧逐帧核看）：
     帧 2–4 蓝色斜切边框/面板先进入，世界随之压暗；帧 10 左右
     `RESUME / SETTINGS / EXIT` 才出现，整块面板横跨大半屏。关闭时
     帧 185–189 面板快速退出，帧 190 后世界恢复；退场明显快于入场。
   - 能借鉴：输入后“世界先冻结/压暗，面板再就位”的先后次序；退场比入场快，
     且关闭后游戏立即恢复。不能照搬：整块斜切面板横跨大半屏、菜单整体大位移、
     高饱和赛博配色；这些都比本项目 1× 像素 UI 更夸张，也不符合本任务
     0.18 s / 0.12 s 的保守时长。
   - 证据：`out/ref/gamejolt_pause_open_frames.png`（0–24 帧逐帧）、
     `out/ref/gamejolt_pause_close_frames.png`（170–199 帧逐帧）、
     `out/ref/gamejolt_pause_contact.png`（每 10 帧一张的总览）。仅作参考，
     不进入游戏资源。
   - 未核实：Celeste 暂停页的官方入场/退场视频未能直接取得（YouTube 抓取被
     反机器人拦截，仅取得静态官方页面图）；因此本轮时长/缩放不是从 Celeste 抄帧，
     而是按任务给定的 0.16–0.20 s / 0.96 规格，并用上述连续 GIF 的“压暗先于面板、
     退场快于入场”次序做保守取舍。

外部参考图只放在 `out/ref/` 的 `.gdignore` 证据目录，不参与导入/打包，不作为
游戏素材；没有复制其像素、配色、字体或布局。

## 测试

运行（Godot 4.7.2，工程目录 `StarCoreTraveler`）：

```powershell
$godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . res://scripts/ui/tests/ui_reveal_test.tscn
& $godot --headless --path . res://dlc/ui/tests/guide_test.tscn
& $godot --headless --path . --import
& $godot --headless --path . res://scenes/level_01.tscn --quit-after 90
& $godot --headless --path . res://scenes/level_02.tscn --quit-after 90
& $godot --headless --path . res://scenes/level_03.tscn --quit-after 90
```

结果：

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 基础 UiReveal / 机械弹窗 / 暂停页 | **67 / 0**，exit 0 | `ui_reveal_test.log` |
| DLC 共用说明页（含动画同步） | **103 / 0**，exit 0 | `../../dlc/ui/tests/guide_test.log` |
| 导入 | exit 0，0 SCRIPT/Parse/ERROR | `out/import_ui_reveal.log` |
| 基础三关 90 帧 | 三关 exit 0，0 ERROR/WARNING | `out/level_0*_90.log` |

基础测试实际覆盖：

- 打开当帧 `is_open()==true`、`get_tree().paused==true`；遮罩从 0、面板从 0.96、
  y +5 px 开始。暂停树中等待 0.22 s 后遮罩=1、面板=1、位置回基准，tween 结束。
- 关闭当帧 `is_open()==false`、`paused==false`，但 0.12 s 退场仍在播放；
  0.16 s 后根节点隐藏、面板回到 0.96 / +5 px；再次打开正常。
- 机械弹窗 F 翻页/关闭在动画期间和动画结束后都有效。
- 暂停页打开后“继续”按钮获得焦点，动画结束后焦点不丢；恢复后再次打开焦点回到
  “继续”；设置页返回后焦点回到“设置”；`force_close` 取消 tween 且立即解除暂停。
- DLC guide：trial 的打开/长按关闭、缺失演示重开/F 翻页/F 关闭都附带动画断言；
  rift 按 `RiftGuide` 当前页数动态走完并用 F 关闭，游玩恢复移动正常。

## 截图（均 640×360 实机，error=0）

运行：

```powershell
& $godot --path . --position 60,60 res://scripts/ui/tests/capture_ui_reveal.tscn
```

- `out/base_pause_open_mid.png` / `base_pause_open_end.png` / `base_pause_close_mid.png` / `base_pause_closed.png`
- `out/base_mechanic_open_mid.png` / `base_mechanic_open_end.png` / `base_mechanic_close_mid.png` / `base_mechanic_closed.png`
- `out/dlc_guide_open_mid.png` / `dlc_guide_open_end.png` / `dlc_guide_close_mid.png` / `dlc_guide_closed.png`

实际核看：中间帧可看到面板整体比结束帧略小、略低，遮罩较浅；结束帧回到原布局；
关闭帧遮罩变浅、面板微缩，关闭后画面无残留。暂停页布局、焦点高亮、机械弹窗
256×144 演示窗和说明页文字/页码均未改。

## 本体结算页（补充：三关完成页也走同一套出场）

`level_hud.gd` / `level_02_hud.gd` / `level03/l3_hud.gd` 的 `show_completion(true)`
现在调用 `UiReveal.play_overlay_open()`：遮罩所在 `ColorRect` 的 `modulate.a`
0→1、内含面板 `0.96→1` 并从下 5px 归位，0.18 s ease-out。页面在请求当帧就是
`visible`/`_completion_active`，按钮可用、焦点照常落地；隐藏当帧立即生效，
只把数值复位（无退场动画），不会出现“点了没反应”的空档。

- headless 断言：`completion_reveal_test.tscn`，覆盖第一/二/三关，
  **33 / 0**（当帧激活、从 0 开始、按钮立即可用、焦点在淡入中落地、中间帧
  0<α<1、结束 1.0、隐藏当帧、再次打开重新淡入）。
- 实机截图：`capture_completion_reveal.tscn`（第一关开场有信箱动画，截图只取二/三关），
  `out/l2_completion_mid.png` / `out/l2_completion_settled.png` /
  `out/l3_completion_mid.png` / `out/l3_completion_settled.png`，均 640×360、error=0。
  中间帧可见整页偏透明、按钮文字尚未压稳；结束帧布局与原先一致。

## 局限 / 未做

- 只做了 640×360 实际渲染截图和 headless 状态断言，未做真人整关节奏/手感终审。
- 参考未取到 Celeste 官方暂停转场的连续视频；具体 0.18/0.12 s 来自本任务规格，
  外部 GIF 只用于确认“先压暗、面板后就位、退场更快”的次序。
- `RiftGuide` 的 4 页内容与 `rift_elements` 演示属于另一个 DLC 任务；本轮未改
  `dlc/rift_workshop`，只把共享 guide 测试改为读取实际页数，避免与其冲突。
- 章内 HUD 的暂停/完成面板按任务要求未碰。
