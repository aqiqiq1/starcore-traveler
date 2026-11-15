# 第一关「断桥庭院」编辑说明

本说明对应可玩初版，不是最终美术/手感定稿。完整场景：

**2026-11-13地面接入更新**：三块地形保留原`block_size`与碰撞，关闭旧`draw_visual`，由各自`GroundVisual`子Sprite显示`assets/bridge_stone_v1/generated/`新同族石材；柱脚已换平底。整根移动地形时视觉与碰撞一起移动；若修改尺寸，必须用`assets/bridge_stone_v1/source/build_block.py`生成相同尺寸PNG并更新引用，不拉伸图片，也不单独拖动碰撞子节点。具体证据见`LEVEL02_REBUILD_20261113.md`。

`res://scenes/level_01.tscn`

在 Godot 4.7.2 打开工程 `基础场景原型/project.godot`，双击该场景后按 **F6** 运行。F6 默认先进入集成开始菜单（不切独立主页场景），点“开始游戏”后才淡出标题、下移镜头并跑入；按 **F5** 仍进入原 `scenes/main.tscn` 原型，默认入口未改。

## 1. 场景里有什么

| 节点 | 作用 | 拖动/修改什么 |
| --- | --- | --- |
| `World/StartGround` | 起点地面 | 整个 `LevelTerrainBlock` 节点；`block_size` 是唯一宽高来源 |
| `World/HighPlatform` | 高台与左侧挡墙 | 同上；不要把子 `CollisionShape2D` 单独拖走 |
| `World/FarBank` | 大坑对岸安全区 | 同上 |
| `World/Player` | 主角与出生点 | 节点位置就是出生脚点；静态预览已配置 idle 第 0 帧与辉相护符 |
| `World/Player/Camera2D` | 跟随相机 | `limit_left/top/right/bottom` 就是相机边界 |
| `World/IntroEnd` | 开场自动短跑的终点 | 移动 Marker2D 即改交还控制的位置 |
| `World/GuideEchoMeeting` | 第一处「守望者残响」固定显现（原叙事碑位置） | 整根移动；`pages`、`near_range` 可改；无碰撞/力场 |
| `World/GuideEchoHighstep` | 第二处「守望者残响」固定显现（原机制碑位置） | 同上；两处是同一残响的不同共鸣点，不跟随 |
| `World/RuneStoneHigh` | 高台符石 | 整根移动；`initial_positive`、`field_range` 等用 Inspector |
| `World/RuneStonePit` | 大坑符石 | 整根移动；默认参数与 `RuneStoneField` 一致 |
| `World/Checkpoint` | 坑前恢复点 | 节点位置是复活脚点；`trigger_size` 是触发区；外观为已批准双态 PNG，脚底锚点 (20,35) |
| `World/Exit` | 第一关出口 | 节点位置是门口；`trigger_size` 是触发区；`label_text` 可改；外观为已批准双态 PNG，脚底锚点 (38,99) |
| `World/Guide` | 仅编辑器辅助线（不是残响 NPC） | `pit_guide_rect` 只是大坑示意框，不参与碰撞/触发；残响是独立的 `GuideEcho*` 节点 |
| `World/Decorations` | 静态庭院石柱装饰 | 每个子节点都是一件可拖动/复制/删除的 `Sprite2D` 石柱；位置就是脚底中心，无碰撞 |
| `Background` | 可见背景层 | 子 `TextureRect`/渐变的位置、大小、`modulate` 均可改 |
| `HUD` | 正式中文 HUD | `Level01HUD`，不是 `PrototypeHUD`；菜单/设置/过渡期间运行时隐藏 |
| `StartMenu` | 集成开始菜单/设置/转场控制 | 运行时代码构建 UI；**编辑器里不显示**，不遮挡搭关 |
| `MenuCamera` | 过渡用临时 `Camera2D` | 位于世界上方 (320,-180)，无世界 limits；只用于菜单→关卡的向下镜头 |

`Level01` 根节点 Inspector：`intro_max_duration`（开场自动跑最长 1.5 秒，仅作安全上限）、`intro_run_speed_ratio`（开场自动跑速度比例，初值 0.75，即 `0.75 × 160 = 120 px/s`；范围 0.5–1.0，不改普通玩法速度）；以及 `Start Menu` 组的 `enable_start_menu`、`menu_title_fade_duration`、`menu_camera_pan_duration`（初值 2.2 秒）、`menu_settle_duration`、`menu_camera_start_position`。生产默认 `enable_start_menu = true`；自动玩法测试在 `add_child()` 前把它设为 `false`，只测旧跑入/玩法，不改变生产默认。

## 2. 地形：贴图和碰撞同源

地形用 `LevelTerrainBlock`（`StaticBody2D` + `@tool`）：

- 节点原点 = 地形**左上角**。
- `block_size` 同时决定绘制尺寸与子 `CollisionShape2D` 的矩形尺寸；会按 16 px 网格取整。
- 移动整个节点，贴图与碰撞一起移动；改 `block_size` 后运行会重新同步。
- 子 `CollisionShape2D` 由脚本维护，不要单独拖动或改它的形状；否则下次运行会被 `block_size` 覆盖。
- 复制整个平台节点是安全的：改动其中一个 `block_size` 时，脚本会先为该实例隔离共享的碰撞形状，不会连带改变兄弟平台。
- `draw_visual` 可临时关闭显示；`collision_enabled` 可临时关闭碰撞，但正式关不要用它做隐藏墙。

## 3. 出生、开场与相机

- 出生点就是 `World/Player.position`。运行时根脚本会记录这个位置并让玩家从这里开始。
- 开场会自动向右跑，到 `World/IntroEnd.position` 或 `intro_max_duration` 结束，然后直接交还控制，不显示交还提示。自动跑使用 `intro_run_speed_ratio`（初值 0.75）配合奔跑动画，目标速度 120 px/s；普通操作的 walk 100 / run 160、跳跃和符石规则不变。
- 自动跑不向全局 `Input` 注入假按键；暂停、失焦、R 重置都会清掉这个临时移动锁存。暂停/失焦发生在开场时，会直接交还控制，不会在窗口回来后偷偷继续跑。
- 相机是 `Player` 的子节点，`limit_*` 是真实配置源。`World/Guide` 在编辑器里画出相机边界、开场路径和大坑示意；运行时不绘制辅助线。
- 改相机边界后，检查出口/标题 HUD 是否仍在安全区，避免相机卡在墙里或看到地图外。
- 相机边界只控制镜头。扩展地图时，还要检查 `Player.world_left`、`world_right`（人物横向边界）和 `kill_y`（掉落恢复线），否则可能出现“镜头看得到，但人物走不过去”。

## 3A. 开始菜单、设置与镜头下移

- **同一场景，不切主页**：`StartMenu` 是 `level_01.tscn` 根下的 `CanvasLayer`（layer=20），运行时由 `scripts/start_menu.gd` 构建 V1 静态 UI 纹理和真实热区。没有独立 home 场景、没有重复背景、没有加载换图。场景里 `StartMenu` 的运行时根默认不可见，故编辑器仍直接看到 World 布景；`MenuCamera` 只是根下的一台临时相机，不移动/缩放 World。
- **初始菜单**：World、Player、HUD 全部隐藏；World 处理暂停，Player 不跑入、不被物理更新。只有实际 `Background/CloudRuinsDS03` 屏幕固定动态背景持续动画。菜单只显示 V1 临时字标、开始游戏、设置、退出游戏；不露地形/人物/残响提示/符石/HUD。
- **开始顺序**：一次点击或 Enter 后按钮锁定，标题组 `menu_title_fade_duration`（初值 0.35s）淡出；再显示真实 World，用临时无 limits 的 `MenuCamera` 从 `menu_camera_start_position`（初值 (320,-180)）平滑下移 `menu_camera_pan_duration`（初值 2.2s，SINE ease in/out）到原 Player 相机的正常屏幕中心 (320,180)；停稳 `menu_settle_duration`（初值 0.15s）后交回原 `_begin_intro`，保留原跑入、IntroEnd、出生点和最终相机 limits。过渡中 Player/HUD 始终隐藏，进入跑入同一帧才显示。
- **输入/暂停安全**：菜单内 R 忽略；Esc 只关闭设置，主菜单不进入暂停，也不绑定退出；过渡期间 Esc 或窗口失焦会暂停整个 SceneTree（含 DS03 背景）并暂停 Tween，必须手动 Esc 恢复，不会跳镜头或提前入场；转场中 R 也忽略。进入跑入后恢复既有规则（Esc/失焦结束自动跑，R 整关重开并重播跑入），不会回菜单或重播镜头。重载场景重新从菜单开始。
- **退出游戏**：设置下方居中的第三入口，热区 (284,212) 72×20，12px Fusion Pixel 青灰字，弱于开始游戏，不加大面板。初始焦点仍是开始；Tab/Shift+Tab 与上下键在 开始→设置→退出→开始 循环，反向也可达。鼠标点击或键盘选中后 Enter 调用 `SceneTree.quit(0)` 结束**当前游戏进程**；不设 Esc 退出、不加确认弹窗。退出被接受后立即锁定三个热区，防双击/重复 Enter；开始淡出时退出与标题组同一 `_fade_group` 一起淡出。设置打开、显示确认 pending、开始转场、跑入/游戏中（`phase != menu`）分别由 `_settings_open`/`_display.is_pending()`/`_start_locked`/`_quit_locked`/phase 守卫拦截；关闭设置焦点回设置，不自动跳退出。F6 运行只会停止这次游戏运行，不会关闭 Godot 编辑器或辅助进程。
- **设置**：主音量 0–100% 像素滑条 + 百分比 + 返回，并新增“显示模式：窗口/全屏”“窗口分辨率”和“应用”。音量仍绑定真实 `AudioServer` Master：0 静音，100 恢复 0 dB；缺失/损坏/越界值安全 clamp 到 0–100，配置是独立的 `user://audio_settings.cfg`（不是游戏进度）。显示设置是独立的 `user://display_settings.cfg`，不合并音量文件；选择只形成待应用草稿，点“应用”才改变真实窗口，然后出现约 10 秒“保留显示设置？”确认（保留/恢复原样），确认才写入；超时、Esc、释放场景或异常退出会恢复上次有效 mode/size/position/缩放。首次无配置时默认保持 1280×720（屏幕容不下才回退到更小的安全候选/小窗），不会因大屏直接升到 1920/2560；用户已确认保存的 1920×1080/2560×1440 在当前屏幕仍能容纳时继续尊重。窗口选项只启用当前屏幕工作区能容纳的 16:9 整数倍（本机 1920×1032 工作区可选 640×360、1280×720；1920×1080/2560×1440 禁用并写明原因）；全屏使用 `Window.MODE_FULLSCREEN` 的桌面无边框全屏，不切换显示器物理模式，分辨率选项在全屏时禁用并注明仅窗口模式。内部逻辑画布始终 640×360，根 Window 用 VIEWPORT/KEEP/INTEGER 缩放，非 16:9 窗口留黑边；退出全屏后保留上一次窗口目标尺寸。窗口失焦会取消滑条拖动，但不冻结显示确认的绝对时间倒计时。设置打开时背景继续动画，不能开始游戏或让输入进入 World。当前项目没有音乐/音效资产，设置面板不代表已有可听内容。
- **资源边界**：UI 纹理在 `assets/menu/`，由 `tools/build_main_menu_ui.py` 从已批准 V1 overlay 降采样并绘制焦点/设置图；退出入口的两张附加透明图层由 `tools/build_main_menu_quit.py` 单独生成，原首页三张 PNG 字节不变；不烘焙背景，不改原 V1 预览、DS03 脚本/参数/素材、项目默认入口、Player/地形/机关/碰撞。显示规则在 `scripts/ui/display_options.gd`，真实窗口/确认/回滚在 `scripts/ui/display_settings_controller.gd`，像素选项按钮在 `scripts/ui/pixel_menu_button.gd`；说明见 `assets/menu/README.md`。
- **编辑预览**：菜单根在编辑器不构建显示；`MenuCamera` 不是游戏相机，运行时才启用。打开场景看到的仍是 World 布景、地形、Player 出生位置和真实相机 limits。不要为了菜单去改 `World/Player/Camera2D` 的最终 limits 或添加黑幕。

## 4. 两处守望者残响（原两块石碑已移除）

- 场景节点：`World/GuideEchoMeeting`（(250,300)，原叙事碑）、`World/GuideEchoHighstep`（(735,300)，原机制碑）。二者实例化同一 `scenes/narrative/guide_echo.tscn`，使用同一 288×64 / 6 帧 / 48×64、脚底锚 (24,60)、4 fps 的残响图（`assets/guide_echo_20261113/guide_echo_idle_6f.png`）；它们是同一「守望者残响」的两个固定显现点，不是两个 NPC，也不跟随玩家。
- **载体与显现（2026-11-13）**：每个实例脚下常驻一座灰色石碑（复用 `tutorial_stele_grey.png` 的纯 `Sprite2D`，`(-13,-52)`、Nearest，无碰撞、无输入、不进 `tutorial_stele` 组，**不是** `TutorialStele` 组件）。残响挂在它上方的 `EchoProjection`（上抬 18 px），初始 alpha 0；距碑脚 ≤96 px 淡入 0.25 s、>112 px 淡出 0.20 s、中间迟滞保持，淡出途中走回平滑反向。远处只有碑，靠近才出现，F 交谈范围不变（56/66），进入显现范围不会自动开页。
- 第一关不再有 `TutorialStele` 外壳，也不再有“阅读石碑”输入或机制碑。脚本中的 `get_narrative_stele()` / `get_mechanism_stele()` 只是旧名兼容 alias，返回 `GuideEcho`，**不代表石碑仍存在**；新代码请用 `get_narrative_guide()` / `get_mechanism_guide()`。
- 直接移动整根 `GuideEcho*` 节点。`pages` 是 `PackedStringArray`，Inspector 可直接增删；`near_range` 是提示距离，`leave_margin` 是离开余量。每个实例在场景里写了自己的 3 页台词。
- 交互：接近只显示短「F 交谈」提示，**不会自动打开**；按 F 才开第 1 页，再按 F 翻页，末页 F 收起；离开范围关闭，回来可重听。`echo` 键重复被忽略。对话不暂停、不锁移动、不要求读完才能过关。
- 对话为屏幕空间 `CanvasLayer`，用当前相机把残响世界坐标换算为屏幕坐标并夹在 640×360 内；面板在残响/玩家人体上方，不遮落脚点。正文/说话者 12 px Fusion Pixel；若改屏宽/安全区，检查 `prompt_hud_safe_top`。
- 暂停、开场自动跑入、菜单/移镜、完成、返回标题、失焦时由关卡挂起残响并清页；暂停中待机/提示/对白冻结、F 不翻页。R/落坑恢复清旧页，重玩仍可交谈。残响无 `CollisionObject2D`、无力场，不影响符石射线或平台。
- 第二关仍使用自己的石碑 6 页，本轮不替换。

## 5. 符石与力的唯一入口

两颗 `RuneStoneField` 都使用默认规则：范围 160 px、内安全 16、满力 52、外缘渐弱 40、满加速度 2400；同相斥、异相吸；中心线被地形遮挡则无力。正式关在 `level_01.gd` 的**单个物理入口**对所有符石采样并求和一次，再交给玩家；不要给某一颗符石另写一套 `apply_external_force`。

- 两颗初始都是 `initial_positive = true`（辉相，金）。
- 正式关设置 `auto_hint_in_range = false`，不显示原型的小 +/−；识别靠金/青外观、护符与 HUD 的「辉相/澜相」。
- 移动符石请移动整根节点，`Visual` 子节点保持在原点。范围/初态/加速度可在 Inspector 改，但改默认力参数会影响整关手感，需重新跑可达性。
- 当前路线：高台前切澜相（吸引）登台，再切辉相（排斥）向右；大坑中先澜相被吸过去，接近/越过坑心后切辉相向右弹出。实际方向始终相对符石，不是无条件向右加速。
- 本版脚本明确接入两颗符石和一个恢复点；移动、改参数会直接生效，但复制新增符石/恢复点后仍需接入关卡脚本，不要以为画面中出现了就已经参与逻辑。

## 6. 恢复点、失败与 R

- `Checkpoint` 是坑前初值；玩家进入触发区后，最新恢复点成为该节点脚点，并显示「恢复点已激活」；外观同时从 `checkpoint_inactive.png` 换成 `checkpoint_active.png`。
- 恢复点图片是 40×36，按 1 源像素 = 1 逻辑像素绘制，脚底锚点 (20,35)；不要缩放、调色或镜像图片。节点位置仍是复活脚点，碰撞只有原有 40×72 的 `Area2D` 触发区，图片没有物理实体。
- 掉落超过 `Player.kill_y`（场景里是 430）会回到最近恢复点；不会重播整段开场。
- R 是整关重开：回 `Player` 出生点、恢复辉相、清完成状态和恢复点，并重播开场。`Player.allow_self_reset` 在正式关为 `false`，由关卡统一处理 R。
- 恢复策略是第一版初值，不是存档系统；后续若要改成分段检查点，可直接加多个 `Checkpoint` 节点并调整关卡脚本的选择逻辑。

## 7. 出口与重玩

`Exit` 是 `Area2D`。玩家进入触发区才完成第一关；完成面板显示「第一关完成 / 断桥庭院 · 你抵达了出口 / 按 R 重新开始」。完成只结算一次，出口触发会在完成时关闭；R 会清完成状态并重开。它不表示第二关已经完成。

出口门使用已批准的 76×100 双态 PNG（开放/完成），位置由节点脚底决定；「出口」中文字样仍由 `level_exit.gd` 用现有 `label_text` 画在上方。触发区只在编辑器显示虚线，不混入正常画面。门洞中央是透明的，可以看到门后的背景；图片没有物理实体，不改变原有 36×76 的 `Area2D` 触发区。

两张门图按 1 源像素 = 1 逻辑像素、Nearest、白色 `modulate` 绘制，脚底锚点 (38,99)。完成时只换金态图片，不新增动画、粒子、锁门或星核开门规则。旧占位导出 `gate_width`、`gate_height`、`activated_color` 已移除；当前场景没有序列化这些属性，节点位置、触发范围与玩法不受影响。视觉尺寸以 PNG 原生尺寸为准，要调整位置请移动整个节点，不要缩放贴图。

恢复点与出口的运行图来源、哈希和透明区见 `assets/checkpoint_exit/README.md`；两态切换与 R 复位由 `tests/test_checkpoint_exit_art.tscn` 专项检查。

## 8. 背景与编辑器可见性

- `Background` 是 `CanvasLayer`（`layer = -10`），固定在屏幕空间，不随相机滚动，作为远景使用。
- 当前可见背景是 `Background/CloudRuinsDS03`，实例自 `scenes/backgrounds/cloud_ruins_ds03.tscn`。它是一套 640×360 屏幕固定、Nearest、白色显示的原生 Godot 动态背景：天空云、两座完整断桥、后方三组小遗迹、两层 1278px 周期云海、浮石与云面投影都按 DS03 的分层顺序在引擎内实时绘制。没有 HTML/WebView/预录视频，也没有碰撞、触发或输入。
- **G1/G2 两座大桥绝对固定**：桥面、横梁、柱、拱、墩始终使用 DS03 的整数偏移，不随云、暂停、R 或时间移动。**只有 G3/G4/G5 后方小遗迹轻浮**，公式幅度/周期/相位仍为 0.35/18/0.8、0.30/22/1.1、0.45/20/0.15。
- 原生 640×360 不能显示网页 2× 画布上的 ±0.5 逻辑 px。组件因此把三组小遗迹量化为两个相邻原生像素：中性/正半周为 0，网页负半周（公式 < -0.25）为 -1；实际峰峰值 **1 逻辑 px**。网页的正半周 +0.5 没有原生对应状态，原生中心在正半周与网页相差 0.5px。这是有意的局部量化差异，不是把幅度放大到 ±1，也没有改全局分辨率、stretch、PixelSnap 或相机。
- 云海/天空只向右：天空云 3.6/6.2 px/s，主/近云海 4.2/7.2 px/s；主/近云海保留 1278px 周期和相邻两份绘制，出画/接缝处没有透明缝。浮石四组、五档投影及低浮石下 5px 旧斑运行时过滤均按 DS03。两层云海之后分别是 `arch_stone`、`SeaNear`、静态石屑和浮石；**两桥都在 `SeaMain` 之前**，没有旧 `island_overlay` 回盖。
- 编辑器里组件是 `@tool`，只显示确定的 **t=0 静态预览**，不会在编辑器里播放整套动画；运行 F6 时才连续推进。相机/World 不会因为背景而缩放或移位。状态探针日志 `tests/logs/ds03_editor_preview_probe.log` 记录 `editor_hint=true`、`time=0.000`、`processing=false`、`sea_main_phase=0`。
- 运行中 Esc 暂停会冻结背景时钟，恢复不跳时；R 整关重开会通过玩家 `reset_performed("level_restart")` 把背景时钟归零，重新载入场景也会从 t=0 开始。菜单或镜头过渡期间 Esc/窗口失焦暂停同样冻结 DS03 时钟与 Tween；恢复后继续原进度。组件自己监听这个既有信号，没有改 `level_01.gd` 的玩法逻辑。
- `Background/CloudRuinsV7` 仍保留但已 `visible = false`，只作旧静态对照；旧的 `Background/Sky`、`FarRuins`、`NearRuins`、`Mist`，以及 `World/PitCloudBack`、`PitCloudFront`、`PitCloudGlow` 也都只隐藏、参数未删。**不要重新显示叠在 DS03 上**，否则会重新出现旧色/旧静态云。
- 背景运行资源在 `assets/backgrounds/cloud_ruins_ds03/`：`art_assets/` 8 张 + `common/` 16 张，共 24 张 PNG 与 DS03 源逐字节相同；另有运行时配置副本和 `source_manifest.json`。组件布局数据在 `scripts/backgrounds/cloud_ruins_ds03_data.gd`，由 `tools/import_ds03_background.py` 从只读 DS03 配置生成；不要手改生成文件或调色/缩放/重画 PNG。说明见该目录 `README.md`。
- 旧 `assets/map/background2.png`、`background4.png` 与默认 `scenes/main.tscn` 原型本次未改。F5 仍进入旧 main，正式第一关 F6。
- `Player` 场景现在自带 idle 第 0 帧、辉相护符和 glow 的静态预览；正式关 `show_head_polarity = false`，运行时不显示头顶 +/−。
- 两处 `GuideEcho*`、符石、恢复点、出口和地形在编辑器里都能看到；残响场景自带 48×64 帧表预览，运行时代码再构建提示/对白 CanvasLayer。`Guide` 的辅助线只在编辑器绘制，运行时隐藏，且它不是残响 NPC。
- 打开场景时出生点在画面左外侧（为了「从左侧跑入」），把 2D 视图往左拖一点即可看到 `Player` 与出生标记。

## 9. 改完必须重新检查的可达性

1. 高台顶面要比起点地面高 **超过普通跳跃高度**（约 64 px；当前 80 px），否则普通跑跳就能上去，吸引教学失效。
2. 高台符石要在高台左侧/边缘附近，玩家从地面能进入 160 px 范围且中心线不被挡墙挡住；登台后同相排斥应把玩家推向右，而不是推回坑里。
3. 大坑要使普通跑跳无法直接越过（平地奔跑跳跃理论距离约109px，本坑落岸更低，需要按实际落差复测；当前坑宽256px），且坑内符石位置允许「先吸引、后排斥」。当前自动测试在选定起跳条件下第60/70物理帧切换均能落岸，第50帧过早失败；不是所有起跳点、跑速都共用一个固定秒数。改符石或坑宽后要重新试。
4. 恢复点必须在坑前安全平台上；出口必须在对岸地面或可站立平台上，触发区脚点与地面高度一致。
5. 改地形后确认相机边界没有把出口/恢复点挡在屏幕外，且 `Guide.pit_guide_rect` 只是示意，别把它当成实际碰撞。

## 10. 测试与截图

```powershell
# 2026-11-12 残响接入与全关可读性聚焦测试（推荐本轮先跑）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_art_guide_pass.tscn
# 三张 GUI 定帧（第一关残响/对白、第二关守卫/缝/新字、台下高台）
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_art_guide_pass.tscn

# 第一关完整流程 + 编辑/失败/暂停/重载检查（实例内关闭开始菜单；旧用例已同步 GuideEcho 接口，但本轮只 check-only，未运行整套）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_level_01.tscn

# 集成开始菜单端到端：真实鼠标/键盘、设置滑条/返回、转场时序/暂停/失焦、R/重载
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_level01_start_menu.tscn

# 显示设置专项：无窗口时测候选筛选/坏配置/pending/确认/超时符号逻辑；GUI 运行再测真实窗口/全屏/缩放点击
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_display_settings.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_display_settings.tscn

# 已确认全屏→应用窗口→鼠标/Esc/超时/释放回退必须回真实全屏（GUI）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_display_mode_mapping.tscn

# 显示设置真实窗口截图（GUI；脚本定帧，临时窗口/配置并恢复）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_display_settings.tscn

# 同一默认实例：真实 Enter 开菜单 → 原跑入 → 读碑/借力/跨坑/恢复点 → 真实出口 → R
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/menu_to_exit_smoke.tscn

# 相关既有回归（历史命令保留；旧用例已同步 GuideEcho 接口，本轮只 check-only，未重跑旧全套）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_runner.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_tutorial_stele.tscn

# 真实引擎截图（GUI；脚本定帧，不是人工连续试玩）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_level01.tscn

# 石柱装饰专项：纹理/manifest/锚点/接地/无碰撞/重载
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_doric_decorations.tscn

# 石柱装饰截图（GUI；脚本定帧）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_doric_decorations.tscn

# V7 背景资产/旧层保留参考（V7 节点已隐藏，由 DS03 接替可见背景）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_background_v7.tscn

# DS03 动态背景专项：24 图/配置/原生量化/实际渲染/暂停/R/重进
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_ds03_background.tscn

# DS03 编辑器预览状态探针（headless editor；检查 t=0、不处理动画）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit --path "D:\godot game\星核旅人\基础场景原型" res://tests/ds03_editor_preview_probe.tscn

# DS03 纯背景与第一关接入截图（GUI；脚本定帧，非人工连续试玩）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_ds03_background.tscn

# 恢复点/出口图片专项：哈希/尺寸/锚点/门洞透明/两态/R
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_checkpoint_exit_art.tscn

# 恢复点/出口实机截图（GUI；脚本定帧，非人工连续试玩）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_checkpoint_exit_art.tscn

# 集成开始菜单实机截图（GUI；脚本定帧，非人工试玩；旧截图保留）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_level01_start_menu.tscn

# 新增退出游戏首页截图（GUI；只写 menu_with_quit.png/_2x，不覆盖旧截图）
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_menu_quit.tscn

# 真实退出进程：headless 鼠标 + 独立 GUI 键盘；子进程自行 exit 0
& "D:\minic\envs\2024212971\python.exe" tests\run_menu_quit_subprocess.py

# 截图布局/2x/UI外背景核对（Python）
& "D:\minic\envs\2024212971\python.exe" tests\verify_menu_capture.py
```

日志在 `tests/logs/`；截图在 `screenshots/level_01_01_start.png`、`level_01_02_pit.png`、`level_01_03_complete.png`，说明见 `screenshots/MANIFEST_LEVEL01.txt`。DS03 背景专项日志为 `tests/logs/ds03_background_test.log`，纯背景/接入截图为 `screenshots/ds03_godot_background_only.png`（640×360）及 `ds03_bg_t*.png`、`ds03_level01_start/pit/exit.png`，说明见 `screenshots/MANIFEST_DS03_BACKGROUND.txt` 和 `ds03_capture_manifest.json`（脚本定帧，非人工连续试玩）。其中 `ds03_godot_background_only.png` 是给后续主界面美术的纯背景参考，不含人物/地形/HUD。恢复点/出口专项日志前缀为 `tests/logs/checkpoint_exit_art_`，实机截图为 `screenshots/checkpoint_exit_warm_01..04*.png`，说明见 `screenshots/MANIFEST_CHECKPOINT_EXIT_ART_WARM.txt`；其中完成态第 04 张只是视觉状态检查，不是真实通关证据。旧的 `checkpoint_exit_01..04*.png` 是本次柱式暖灰石色统一前的外观证据；旧的 `level_01_01..03` 截图是接入新恢复点/出口图之前的画面，均不作为当前外观证据。自动测试通过不等于手感、节奏或美术已被创作者接受，最终仍需人工完整试玩。

集成开始菜单截图：`screenshots/menu_level01_initial.png`、`menu_level01_settings.png`、`menu_level01_camera_mid.png`、`menu_level01_camera_settled_before_entry.png`、`menu_level01_playable.png`，每张另有精确 2× NEAREST 的 `_2x.png`；说明见 `screenshots/MANIFEST_MENU_LEVEL01.txt`。这些是两入口时期的历史截图，保留不覆盖。当前三入口首页截图是 `screenshots/menu_with_quit.png` 与 `menu_with_quit_2x.png`，说明见 `screenshots/MANIFEST_MENU_QUIT.txt`。两者都是运行中 Godot 640×360 根视口捕获（设置截图用真实滑条/临时配置，结束后恢复 Master），不是人工试玩。`tests/verify_menu_capture.py` 输出 UI 布局/2x/UI 外背景核对的 JSON 到 `tests/logs/menu_capture_verify_*.json`。真实退出验证日志前缀为 `tests/logs/menu_quit_subprocess_`，记录鼠标/键盘输入后子进程自行退出的 return code。

显示设置截图：`screenshots/display_settings_01_panel_1280.png`（扩展设置页，真实 1280×720 窗口）、`display_settings_02_pending_640.png`（640 窗口待确认倒计时）、`display_settings_03_pending_fullscreen.png`（1920×1080 桌面全屏待确认）、`display_settings_04_bars_1400x900.png`（临时非 16:9 窗口，整数 2× 与黑边），另有 640×360 逻辑帧 `display_settings_05_panel_logical.png`、`display_settings_06_pending_logical.png`。说明见 `screenshots/MANIFEST_DISPLAY_SETTINGS.txt`；1400×900 仅用于审黑边，不是可选分辨率，本机未实测 1920×1080/2560×1440 窗口或 2K/4K 显示器，不宣称已有 2K 屏幕。

## 11. 庭院多立克石柱装饰（静态、无碰撞）

- `World/Decorations` 下现有 10 件：高柱3、断柱2、柱座2、倒落段3。全部是 `scenes/decorations/doric_column_{tall,broken,base,fallen}.tscn` 的实例，根节点为静态 `Sprite2D`。
- 根节点原点 = **脚底中心**。高柱/断柱/柱座/倒落的 `offset` 已固定为 `(0,-54)`、`(0,-41)`、`(0,-12)`、`(0,-11)`；在 2D 视图里拖动整个实例，落点 y 应与脚下地形顶面一致（起点地面/对岸 `300`，高台 `220`）。不要单独改子节点，场景没有子节点。
- 实例 `z_index = -1`，画在玩家、残响、符石、恢复点与出口后方；它们没有 Collider、`Area2D`、脚本或受力采样，也不是可站立平台。不要给装饰添加碰撞来“修脚”，也不要把断柱/倒落段摆进坑里当桥。
- 复制实例会保留场景引用与 `z_index`；删除直接删节点。位置真实保存在 `scenes/level_01.tscn`，运行时不重新生成、不随机重摆，也不使用 `flip_h` 制造变体。
- 贴图为批准 V4 的局部 RGB 细化，按 **1 源像素 = 1 逻辑像素**、Nearest 显示；源路径、SHA256、alpha bbox 与 `foot_anchor` 见 `assets/doric_columns/README.md` 和 `source_manifest.json`。不要缩放或 tint 单件来“调整”构图，优先移动位置。
- 摆位时保持起跳点、坑内、落岸缓冲、符石/恢复点/出口清爽；高台只放低残件。当前起点叙事段、长平路、高台安全中段和对岸出口前各有一组，具体节点名见场景树。
- 专项测试日志：`tests/logs/test_doric_decorations.log`；实际引擎截图：`screenshots/doric_01_entry.png`、`doric_02_walkway.png`、`doric_03_far_bank.png`，说明见 `screenshots/MANIFEST_DORIC.txt`（脚本定帧，非人工连续试玩）。
- 专项中的数量/位置断言记录本轮摆位快照。手动调整后，先按新布局检查接地、目标可见性和完整通关，再核对失败是否只是旧快照过期；不要为了通过坐标断言回退自己的摆位。
