# 星核织机 · 实现与验证记录（2026-11-26）

分支：`dlc`（未切分支、未提交、未推送、未导出）。
工程：`D:/godot game/星核旅人/StarCoreTraveler`
Godot：`D:/Godot/Godot_v4.7.2-stable_win64_console.exe`

## 新增 / 改动

| 位置 | 内容 |
| --- | --- |
| `dlc/star_loom/star_loom.tscn` / `.gd` | 960×360 单厅首领战：3 阶段、3 段攻击、2 受击重置、R、完成页 |
| `dlc/star_loom/loom_node.gd` | 环绕极性节点（2.6 s 换相，异相才可打掉） |
| `dlc/star_loom/loom_core.gd` | 96×96 织机、护盾环、暴露菱形、受击闪 |
| `dlc/star_loom/loom_bullet.gd` | 慢速追踪弹 |
| `dlc/star_loom/loom_sweep.gd` | 横扫光带 |
| `dlc/star_loom/loom_wisp.gd` | 裂隙浮灵（原创 16×16） |
| `dlc/star_loom/loom_fx.gd` | 0.55/0.65/0.80 s 预警、车道、织线 |
| `dlc/star_loom/loom_hud.gd` | HUD、事件行、恢复黑幕、完成页、暂停页 |
| `dlc/star_loom/loom_audio.gd` | 10 条生成 WAV；音乐播放器 -6 dB、代码内 loop |
| `dlc/star_loom/loom_guide.gd` | 共享 guide 的三页 `loom` 数据 |
| `dlc/star_loom/assets/` | 生成的 5 张 PNG + 10 条 WAV；无外部素材 |
| `dlc/star_loom/tools/gen_assets.py` | 全部图像/音效的程序化生成 |
| `dlc/star_loom/tools/capture_loom_demos.tscn/.gd` | 从正式 BOSS 场景实拍 3 条演示帧条 |
| `dlc/star_loom/tests/` | 机制/路线/标题/缺失/说明/音乐/截图/日志 |
| `scripts/start_menu.gd` | 只加第三个 DLC 入口：`LOOM_SCENE_PATH`、`LOOM_RECT`、`_loom_button`、`_on_loom_pressed()`、`is_loom_entry_available()`，并追加到已有启用/禁用/焦点链分支 |
| `dlc/ui/demos/loom_*.png/json` | 3 条 24 帧 / 8 fps / 256×144 实机演示帧条 |

未改：`project.godot`、`export_presets.cfg`、基础三关场景/脚本/数值、
基础 `assets/`、`scripts/audio/demo_audio.gd`、`dlc/ui/dlc_guide.gd`、
`dlc/trial_chambers` 与 `dlc/rift_workshop` 的玩法/资产。
`dlc/audio/music/loom_boss.ogg` 由音乐 agent 提供，本任务只读取/接入，未改
`dlc/audio` 下任何文件。

## 运行命令

```powershell
# 一键：导入 + 机制/路线/标题/缺失/说明 + 3 个 90 帧 + 基础三关 90 帧 + 删目录证明
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_all.ps1

# 单项
& $godot --headless --path . res://dlc/star_loom/tests/mechanics_test.tscn
& $godot --headless --path . res://dlc/star_loom/tests/route_test.tscn
& $godot --headless --path . res://dlc/star_loom/tests/title_test.tscn
# 先临时改名 dlc/star_loom/star_loom.tscn，再跑缺失分支
& $godot --headless --path . res://dlc/star_loom/tests/title_missing_test.tscn
& $godot --headless --path . res://dlc/star_loom/tests/guide_test.tscn

# 640×360 实机截图（不要加 --headless）
& $godot --path . --position 60,60 res://dlc/star_loom/tests/capture_visuals.tscn

# 真实音频播放/循环/暂停（不要加 --headless）
& $godot --path . --position 60,60 res://dlc/star_loom/tests/music_test.tscn

# 重新生成说明页演示帧条（不要加 --headless）
& $godot --path . --position 60,60 res://dlc/star_loom/tools/capture_loom_demos.tscn
```

## 本轮结果（`run_all.ps1`，全部 exit=0，0 ERROR / 0 引擎 WARNING）

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 导入 | exit 0，0 错误 | `import.log` |
| 机制测试 | **83 / 0** | `mechanics_test.log` |
| 完整路线 | **29 / 0** | `route_test.log` |
| 标题入口（存在） | **42 / 0** | `title_test.log` |
| 标题入口（缺失） | **16 / 0** | `title_missing_test.log` |
| 开场说明 + 3 条 24 帧演示 | **27 / 0** | `guide_test.log` |
| 真实音乐播放/循环/暂停/最终峰值 | **16 / 0** | `music_test.log` |
| 新章 90 帧 | exit 0，0 错误 | `star_loom_90.log` |
| 基础三关 90 帧 | 三关均 exit 0，0 错误 | `level_01_90.log` 等 |
| 移走整个 `dlc/star_loom` 后 level_01 90 帧 | exit 0，0 错误 | `level_01_deleted_90.log` |
| 640×360 截图 | 10 张，均 640×360 error=0 | `capture_visuals.log`、`out/` |

本任务还临时对既有 DLC 跑了回归（日志在 `tests/external/`，未改它们的玩法）：

| 项目 | 结果 |
| --- | --- |
| trial · gate | 32 / 0 |
| trial · route | 46 / 0 |
| trial · title | 25 / 0 |
| trial · pause/title | 5 / 0 |
| trial · ambience（并行 pass） | 52 / 0 |
| rift · mechanics | 121 / 0 |
| rift · route | 37 / 0 |
| rift · title | 34 / 0 |
| rift · title_missing | 14 / 0 |
| rift · polish（并行 pass） | 15 / 0 |

## 实际覆盖

### 机制（`mechanics_test`，83 项）

- 真实向右移动越过 x=430 才启动首领；初始休眠、节点 2、核心受护。
- 真实物理 J：同相节点无伤/弹开；Q 后异相 J 打掉节点 A；节点 B 同样；
  两节点清空 → 核心暴露，HUD「核心 0 / 3」。
- 真实物理 J 打核心：同相 0 伤；异相 3 次真伤，每次后核心换相，第三次进入
  阶段 2；阶段 2 节点重生、核心重新受护、HUD「阶段 2 / 3」。
- 阶段 2 攻击池 = 追踪弹 + 扫带；阶段 3 = 三招齐全；每招预警 ≥0.3 s，
  且真实生成追踪弹 / 光带 / 1–2 只浮灵。
- 真实 J 清掉召唤浮灵。
- 受击：第 1 次计数；第 2 次进入恢复淡出/黑屏/淡入；结束后回 x=420，
  阶段 1、两节点、核心 0/3、受击 0、可继续移动；音乐继续。
- 暂停：Esc 打开暂停页并暂停树，再 Esc 恢复。
- R：回 x=40、计时 <1 s、阶段 1、休眠、受击/核心归零、完成页隐藏、音乐停止。
- 阶段 3 真实 J 清节点 + 3 次核心真伤 → 完成页
  「织机停转 · 用时 mm:ss」；玩家移动锁定；E 回 level_01 且标题菜单打开。
- 音乐：加载、播放、代码 loop、-6 dB 播放器、长度 61.7 s；完成/ R 停止。

### 完整路线（`route_test`，29 项）

从 x=40 真实走到入口，三个阶段的每一次节点击破与核心真伤都是真实物理 J；
阶段切换由章节自己的 3 真伤规则发生，不走 `debug_set_stage`。完成后 E 回标题。
本路线关闭攻击（攻击/受击覆盖在机制测试），节点角度用 debug 摆位保证确定性。

### 标题（`title_test` / `title_missing_test`）

- 星核织机按钮：y=286、112×20、STONE、在裂隙工坊下方、640×360 内、
  可键盘/鼠标；焦点链 6 项
  `start → settings → quit → trial → rift → loom → start`，上下左右一致。
- 标题层级：试炼场/裂隙工坊/星核织机三个 DLC 行统一
  `modulate = (0.82, 0.86, 0.86, 1.0)`，三者一致且仍 FOCUS_ALL；基础
  「开始游戏」行保持未染色。布局、热区、焦点链和开始/设置/退出逻辑未改。
- Enter 与鼠标点击都真实切到 `star_loom.tscn`；原开始/设置行仍工作。
- 缺失分支：按钮存在但隐藏/禁用/FOCUS_NONE；焦点环自动跳过，rift→start；
  开始行仍可聚焦。

### 说明页（`guide_test`，27 项）

- 复用 `dlc/ui/dlc_guide.tscn`，3 页标题/页码/按键/页脚正确，demo id 为
  `loom_nodes` / `loom_core` / `loom_attacks`，均 24 帧 / 8 fps。
- F 翻页、长按空格关闭、关闭后树恢复；缺失 demo 目录时显示「演示缺失」，
  三页文字仍可读。

### 音乐（`music_test`，16 项，非 headless）

- `loom_boss.ogg` 实际加载并播放，播放位置从 1.21 s 前进到 2.01 s；
- 代码设置 `AudioStreamOggVorbis.loop = true`（`.import` 仍是 loop=false），
  seek 到 61.11 s 后 1.4 s 内回绕到 0.80 s 且继续播放；
- 播放器 -6.0 dB；源峰值 -8.05 dBFS → **最终峰值约 -14.05 dBFS**；
- 长度 61.71 s；
- Esc 暂停时位置 0.81 → 0.81 保持，恢复后继续前进；
- 截图 `out/music_playback.png`（640×360，真实战斗画面）。

## 截图（均 640×360，`out/`）

| 文件 | 实际状态 |
| --- | --- |
| `entry.png` | 入口左侧，织机休眠，HUD「向右进入织机厅」 |
| `nodes.png` | 两节点一上一下、护盾环、HUD 节点 2/2、启动事件行 |
| `core.png` | 两节点停转，金色暴露菱形，HUD 核心 0/3 |
| `stage.png` | 真实第三次核心真伤后阶段 2，节点重生，事件行「阶段 2 / 3 · 节点重生」 |
| `sweep_warning.png` | 扫带预警：地面紫色车道 + 右端虚线带 + 「预警 · 横扫光带 · 跳起」 |
| `sweep.png` | 扫带实体从右向左进入画面 |
| `summon.png` | 召唤浮灵（大白眼紫色浮灵）与扫带同框，无受击 |
| `completion.png` | 「织机停转 · 用时 00:07」+ E/Enter 提示，HUD 核心 3/3 |
| `title_loom_button.png` | 标题第三个 DLC 按钮「星核织机」聚焦 |
| `music_playback.png` | 音乐测试中的真实战斗画面（配合 `music_test.log`） |

`out/.gdignore` 让截图不参与资源导入。

## 实现说明 / 已知取舍

- 共享 `L3Player` 的受击在完成页同帧取消攻击时可能让攻击贴图多留一帧；
  本章把「第三阶段最后一次真伤 → 完成页」延后到当前 J 挥击结束，避免在
  自己的 hit-window 回调里取消挥击；路线/机制测试均无 ERROR。
- 节点是纯目标，不做接触伤害；压力来自扫带、追踪弹、浮灵。
- 2 次受击整场共享，不按阶段恢复（任务硬规则）；阶段 1 只有追踪弹，
  阶段 2/3 逐步加入扫带/浮灵。
- 机制测试的受击重置用 `apply_enemy_hit()`（所有弹幕/浮灵共用的真实受击入口）
  触发，而不是等随机弹命中；弹幕生成/扫带/浮灵的接触代码另有测试。
- 说明页 3 页通过 `loom_guide.gd` 子类提供：共享 guide 的 `PAGES` 是 const，
  在不改 `dlc_guide.gd` 的前提下，用既有 `_page_data()` 虚函数 + 运行时
  `set_script()` 注入；页面/翻页/跳过/缺失降级全部复用原实现。
- 未做真人整关节奏/可读性终审；像素呈现按 640×360 实机截图核看。
- 参考核看以静态图/短 GIF 为主，没有 Ikaruga / Cuphead 连续视频；0.3 s
  预警的连续运动证据不足，见 `REFERENCE.md` 的边界说明。
- 未 Git add/commit/push，未导出。
