# 裂隙工坊 · 实现与验证记录（2026-11-25）

分支：`dlc`（未切分支、未提交、未推送、未导出）。
工程目录：`D:/godot game/星核旅人/StarCoreTraveler`
Godot：`D:/Godot/Godot_v4.7.2-stable_win64_console.exe`

## 新增文件（全部在 `dlc/rift_workshop/`）

| 文件 | 说明 |
| --- | --- |
| `rift_workshop.tscn` / `.gd` | 1600×360 主场景：三段、双守卫、完成/失败/R |
| `rift_hud.gd` | 紧凑标题、目标、相性、事件行、恢复黑幕、完成页、双项暂停页 |
| `rift_inversion_field.tscn` / `.gd` | 24×120 紫色反转光幕，进入只翻一次、离开可再用 |
| `rift_phase_bridge.tscn` / `.gd` | 64×10 金/青相性光桥，同相可站、异相消失、防夹 |
| `rift_polarity_wisp.tscn` / `.gd` | 16×16 双态 wisp：正弦悬浮、2.2 s 换相、3 s 推/拉、J 一击 |
| `rift_audio.gd` | DLC 内 5 条生成音效的播放器（不改 DemoAudio） |
| `rift_fog.gd` | DS03 之上的紫色雾 + 代码绘制浮屑 overlay |
| `assets/sprites/polarity_wisp_16x16_8f.png` | 生成：128×16，4 帧 × 金/青两态 |
| `assets/rift_fog_640x360.png` | 生成：640×360 紫色雾 |
| `assets/audio/*.wav` | 生成：inversion / bridge / wisp_hum / wisp_pop / complete；峰值已归一化 |
| `tools/gen_assets.py` | 上述图片与 WAV 的生成脚本（无网络、无第三方采样；WAV 写出时做峰值归一化） |
| `tools/check_audio_peaks.py` | 只读峰值/时长核对工具（-3 dBFS 一次性音效、-9 dBFS hum） |
| `REFERENCE_PASS_CUE.md` | 本轮“门开启提示 / 桥消失反馈”的逐帧参考核看记录 |
| `DESIGN.md` / `REFERENCE.md` | 章节设计、参考核看记录 |
| `tests/*` | 本目录全部测试、日志、截图、repro 脚本 |

改动的基础文件只有 `scripts/start_menu.gd`：新增 `RIFT_SCENE_PATH`、`RIFT_RECT`、
`_rift_button`、`_on_rift_pressed()` / `_restore_after_failed_rift()`、
`get_rift_button()` / `is_rift_entry_available()`，并在原有各启用/禁用/焦点链处
追加“若存在且可见”的分支。开始/设置/退出/试炼逻辑未改。

未改：`level_01/02/03` 场景与脚本、`project.godot`、`export_presets.cfg`、
`scripts/narrative`、`assets` 运行资源（`.import` 内容哈希仍与 HEAD 一致，
`git diff --numstat` 对这些文件为 0/0）、`scripts/audio/demo_audio.gd`、
`dlc/trial_chambers` 的内容。

## 运行命令

```powershell
# 一键：导入 + 4 个测试 + 4 个 90 帧 + 删目录证明（会暂时移动 dlc/rift_workshop）
powershell -NoProfile -ExecutionPolicy Bypass -File dlc\rift_workshop\tests\run_all.ps1

# 单项
$godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . res://dlc/rift_workshop/tests/mechanics_test.tscn
& $godot --headless --path . res://dlc/rift_workshop/tests/route_test.tscn
& $godot --headless --path . res://dlc/rift_workshop/tests/title_test.tscn
# 先临时改名 rift_workshop.tscn，再跑缺失分支
& $godot --headless --path . res://dlc/rift_workshop/tests/title_missing_test.tscn

# 640×360 实机截图（不要加 --headless）
& $godot --path . --position 60,60 res://dlc/rift_workshop/tests/capture_visuals.tscn

# 导入 / 90 帧
& $godot --headless --path . --import
& $godot --headless --path . res://dlc/rift_workshop/rift_workshop.tscn --quit-after 90
& $godot --headless --path . res://scenes/level_01.tscn --quit-after 90
& $godot --headless --path . res://scenes/level_02.tscn --quit-after 90
& $godot --headless --path . res://scenes/level_03.tscn --quit-after 90
```

## 本轮结果（`run_all.ps1`，全部 exit=0，ERROR/Failed=0，WARNING=0）

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 导入 | exit 0，0 错误 | `import.log` |
| 机制测试 | **94 / 0** | `mechanics_test.log` |
| 真实输入路线 | **37 / 0** | `route_test.log` |
| 标题入口（存在） | **34 / 0** | `title_test.log` |
| 标题入口（缺失） | **14 / 0** | `title_missing_test.log` |
| 新章 90 帧 | exit 0，0 错误 | `rift_90.log` |
| 基础三关 90 帧 | 三关均 exit 0，0 错误 | `level_01_90.log` 等 |
| 删除整个 DLC 后 level_01 90 帧 | exit 0，0 错误 | `level_01_deleted_90.log` |
| 640×360 截图 | 7 张，均 640×360 error=0 | `capture_visuals.log`、`out/` |

实际数值摘要：

- 反转光幕：走入 `triggers=1` 且变辉相；在内部停 60 帧仍 `1`；内部 Q 不计数；
  离开至 x=237 再进入 → `triggers=2`，回澜相。
- 光桥：辉相站金桥 `solid=true / layer=1 / y=280`；切澜相后 `solid=false /
  layer=0`，落到下层 `y≈340`（未触发恢复），可继续走动；身体在 10 px 桥体内
  切回同相时 `deferred_reform>0`，离开后桥才实体化；再次上桥 `y=280`。
- 检查点：x=1030 记录；掉到 y=500 → 恢复淡出/淡入 → 回到 `x=1030, y=280`。
- Wisp：默认 2.2 s / 3.0 s；同相时脉冲为 pull（实测后 1 帧 vx=+90.0，朝 wisp），
  异相为 push（vx=-62.5，背离）；J 一击 `is_alive=false`，其他 wisp 仍存活。
- 双守卫：金守卫 3 次真伤 → defeated → 章节记录；此时完成核心仍暗、未开完成；
  青守卫 3 次真伤 → 两只都倒 → 核心变亮、完成面板“裂隙封闭 · 用时 00:07”。
- 失败：两次 `player_struck` → 恢复 → 玩家 x=1100（竞技场入口）、受击数归零、
  两守卫回 ACTIVE、可继续移动。
- R：回 x=40、澜相、计时 <1 s、检查点清除、wisp 复活、双守卫复位、无暂停/完成锁。
- 路线（真实按住右/跳 + 在石台按 Q）：回廊尽头 x=633.3（y=279.9 高台）→
  金桥落点 x=773.2 → 青桥落点 x=883.3 → 第二金桥 x=1003.7 → 检查点 x=1043.6 →
  竞技场 x=1099.5 → 双守卫 6 次真伤 → 完成点 x=1543.6 → 面板“用时 00:23” →
  E 回 `res://scenes/level_01.tscn` 且 StartMenu 存在。

## 截图（均实际渲染 640×360，`out/`）

- `inversion.png`：真实走进 InversionA 的瞬间，紫幕 + “相性反转 · 辉相”事件行；
- `bridge_solid.png`：辉相站在金桥上，桥体亮起；
- `bridge_gone.png`：同一位置按 Q 后金桥消失、身体已下坠，前方青桥亮起；
- `wisp.png`：PolarityWisp 脉冲前的蓄力环（站在 LandingA）；
- `twins.png`：竞技场中金/青双守卫同框，各自血条；
- `completion.png`：“裂隙封闭 · 用时 00:03”（截图会话的真实计时）；
- `title_rift_button.png`：标题菜单“试炼场”下方“裂隙工坊”，焦点高亮。

`out/.gdignore` 让截图不参与资源导入。

## 验证方法说明 / 局限（不夸大）

- 反转、光桥、检查点、路线行走均是真实玩家输入/真实碰撞与状态；不是静态图冒充。
- 双守卫的 6 次真伤由真实 `attack_hit_window` → `guard.receive_player_hit()` 结算；
  为避开 3 s 引力周期的等待，使用 guard **既有** `debug_force_gravity()` 进入蓄力
  （与试炼章路线测试同一先例），未改守卫伤害、射程、节奏或状态机。
- `completion.png` 为画面取证使用 `debug_force_death()` + `defeated.emit()`；
  真实 3+3 真伤路线由 `route_test.tscn` 证明。
- wisp 的推/拉方向用真实脉冲后的 1 帧速度核看；没有做长时间手感的盲测。
- 桥下安全层是刻意的保底：掉下去落在 y≈340，可走回石台重试；它也让熟练玩家
  可以沿下层走到终点再跳上高台（较慢），属于已知设计取舍，见 DESIGN.md。
- 未做真人整关节奏/可读性终审；像素呈现只按 640×360 实机截图核看。
- 已知跨测试影响：`dlc/trial_chambers/tests/title_test.tscn` 仍断言
  “trial focus_next loops back to start”，而本章按“试炼场下方”的顺序把裂隙按钮
  接在试炼场之后，因此该旧断言会失败 1 项。按任务约束未修改 trial_chambers 任何
  文件；新的焦点环由本章 `title_test.tscn` 覆盖。
- `git status` 会把许多既有 `*.import` 标成 modified；已抽查并用
  `git hash-object` 对比索引 blob 一致，`git diff --numstat` 为 0/0（仅 stat
  cache/行尾标记），未对 assets 运行资源做内容修改。本轮没有任何 git add/commit/push。

---

## 2026-11-25 全玩法打磨轮

本轮只改 DLC 呈现与测试；基础三关的场景/碰撞/数值/门/守卫/紫晶/石壳未改，
`scripts/start_menu.gd` 未改。分支仍为 `dlc`，未提交、未推送、未导出。

### 音频

5 条 WAV 由 `gen_assets.py` 重新生成，写出时按峰值归一化；时长与内容不变
（hum 仍精确 1.000 s，播放端仍 0..data/2-1 循环）：

| 文件 | 实际峰值 | 时长 | 播放增益 | 最终峰值 |
| --- | --- | --- | --- | --- |
| sfx_inversion.wav | -3.00 dBFS | 0.550 s | 0.0 dB | -3.0 dBFS |
| sfx_bridge.wav | -3.00 dBFS | 0.420 s | 实化 -2.0 / 消失 -4.0 dB | -5.0 / -7.0 dBFS |
| sfx_wisp_pop.wav | -3.00 dBFS | 0.340 s | 击破 -4.0 / 脉冲 -12.0 dB | -7.0 / -15.0 dBFS |
| sfx_wisp_hum.wav | -9.00 dBFS | 1.000 s | -12.0 dB | -21.0 dBFS/只 |
| sfx_complete.wav | -3.00 dBFS | 1.900 s | 0.0 dB | -3.0 dBFS |

核对命令：`D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/check_audio_peaks.py`
（输出 `AUDIO_PEAK_RESULT PASS failed=0`）。同一 Q 按下的 3 座桥仍先合并成 1 次桥音，
不会三条叠成爆音；hum 只有玩家 250 px 内且存活时才播放。

### 呈现

- 极性门开启态：8×88 轮廓内新增 3 条 4×1 px 近白横线，每条上方 3 px 箭头，2.2 s
  自下而上循环，两端淡入淡出；关闭态仍是实体亮场 + 横向火花刻度。碰撞/防夹/API 未改。
- 相性桥消失：新增 0.18 s 白热顶边 + 9 个 1×2 px 上浮碎片 + 底沿余辉；实化保留原
  0.22 s 白闪。`solidity_changed` 仍在碰撞切换当帧发出，Q 不延迟。
- 双生守卫：进入竞技场后两只先用 `set_suspended(true)` 悬浮 0.8 s，HUD 事件行
  “双生守卫苏醒 · 金 / 青”，计时结束同一帧一起解除；暂停会保留剩余开场时间。
  血量、攻击、真伤、巡逻未改。
- wisp 击破：0.14 s 白色 2×2 核心 + 四向 1 px 爆点（随后原有 0.34 s 六片碎屑）；
  蓄力环仍为脉冲前 0.45 s；推力/拉力/命中规则未改。

### 本轮测试结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 导入 | exit 0，0 ERROR/WARNING | `import.log` |
| 机制测试 | **100 / 0** | `mechanics_test.log` |
| 真实输入路线 | **37 / 0** | `route_test.log`（corridor 635.4 → 三桥 773.3/883.4/1003.7 → 检查点 1043.7 → 竞技场 1099.6 → 完成点 1543.6，用时 00:24） |
| 标题入口（存在） | **34 / 0** | `title_test.log` |
| 标题入口（缺失） | **14 / 0** | `title_missing_test.log` |
| 新章 90 帧 | exit 0，0 ERROR/WARNING | `rift_90.log` |
| 基础三关 90 帧 | 三关均 exit 0，0 ERROR/WARNING | `level_01_90.log` 等 |
| 删除整个 DLC 后 level_01 | exit 0，0 ERROR/WARNING | `level_01_deleted_90.log` |
| 640×360 截图 | 11 张，均 640×360 error=0 | `capture_visuals.log`、`out/` |

新增/更新的截图：

- `out/gate_closed.png` / `out/gate_open.png`：裂隙工坊金门的关/开两态，开启态可见上浮箭头；
- `out/bridge_solid.png` / `out/bridge_gone.png`：金桥实体 / Q 后消失（0.18 s 碎裂余辉）；
- `out/twins_intro.png`：0.8 s 开场悬浮 + HUD“双生守卫苏醒 · 金 / 青”；
- `out/twins.png`：开场结束后两只同时激活；
- `out/wisp_burst.png`：击破爆点（取证用 `kill()`，真实 J 击破由机制测试与路线覆盖）；
- `out/completion.png`：完成后页面。

机制测试新增的断言：桥消失 `dissolve>0`、桥实化/消失两侧各触发一次桥音、击破爆点
`>0`、开场两只同时 suspended 且 HUD 事件行正确、开场结束后同帧解除。

### 正作审计（只读）

- 导入与三关 90 帧：0 ERROR/WARNING（见上表）。
- 640×360 实测截图：`out/audit_title.png`、`audit_level_01.png`、`audit_level_02.png`、
  `audit_level_03.png`（`audit_base_levels.tscn`，只加载/按键，不改基础文件）。
- 实际看到：标题“开始游戏”有金色焦点框，“设置/退出游戏”为低对比灰字，而 DLC 的
  “试炼场/裂隙工坊”是常显描边按钮，视觉层级不完全统一；第二关“释放星核”与
  “E 交谈”、第三关“送核入符石台”可读；第一关开场是黑边过场、HUD 暂隐。
  这些均属既有基础设计，本轮未改；未发现需要立即修的客观 bug。
- 局限：未做正作整关手感/节奏人工试玩，只覆盖出生点/开场与既有测试路线。

---

## 2026-11-25 真实 J / 双守卫完整重生 / 开场说明

### 真实 J 伤害：实际失败点

- 先用 `Input.parse_input_event` 真实物理键 J 复现：在异相、GRAVITY_CHARGE、
  正面 22 px 时，`attack_started` / `attack_hit_window` 各 1 次，
  `receive_player_hit()` 返回 `TRUE_HIT`，真伤 0→1。**输入与 hit 分发本身没有断。**
- 实战失败点有三个，均已复现：
  1. **守卫引力场没有接到玩家外力**：原关卡 03 通过 `add_player_force_provider(_guard)`
     把 `sample_player_force()` 接到 `apply_external_force()`；试炼场和裂隙工坊都漏了
     这一步。异相蓄力时不会被吸进 36 px 的 J 射程，38/42/48/56/70 px 全是 `MISS_RANGE`。
  2. **朝向是旧的**：背对守卫按 J 时 `forward_gap` 变成负值，返回 `MISS_BEHIND`。
  3. **规则没有在 DLC 内讲清**：必须异相 + 蓄力 + 36 px 内；无效命中只在 mechanic popup
     里讲过，DLC HUD 没有反馈。
- 双守卫分发实测正常：同一真实 J 近处金守卫 `TRUE_HIT`、远处青守卫 `MISS_RANGE`；
  单测青守卫时摇杆也返回 `TRUE_HIT`，不是只结算金守卫。

### 修复

- `rift_workshop.gd`：每物理帧把两只守卫的 `sample_player_force()` 求和后
  `apply_external_force()`，异相吸近、同相弹开；不改守卫射程/伤害/状态机。
- 真实 J 按下时，竞技场内 140 px 内自动面向最近存活守卫（只改 facing）。
- `attack_hit_window` 读取两只守卫的 `receive_player_hit()` 返回；非真伤结果给出
  `SHELL_SHATTER / SAME_PHASE / MISS_RANGE / MISS_BEHIND / BLOCKED` 短提示。
- `_retry_combat()` 改为**两只都完整重生**：各自出生点、满 3 格、`0/2`、完成核心熄灭；
  恢复结束后重新计 0.8 s 开场悬浮，再同时唤醒。即使先击败一只，另一只造成的失败/
  坠落也让两只一起回来。R 仍是整章重开。
- 新增共享 `dlc/ui/dlc_guide.tscn/.gd` 3 页说明；`RiftWorkshop.show_intro_guide`
  默认 true，现有自动测试在 `add_child` 前设 false。

### 本轮测试结果（`run_all.ps1`，全部 exit 0，0 ERROR/WARNING）

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 导入 | exit 0，0 错误 | `import.log` |
| 机制测试 | **121 / 0** | `mechanics_test.log` |
| 真实输入路线 | **37 / 0** | `route_test.log` |
| 标题入口（存在） | **34 / 0** | `title_test.log` |
| 标题入口（缺失） | **14 / 0** | `title_missing_test.log` |
| 新章 90 帧 | exit 0，0 错误 | `rift_90.log` |
| 基础三关 90 帧 | 三关均 exit 0，0 错误 | `level_01_90.log` 等 |
| 移走 `dlc/rift_workshop` 后 level_01 90 帧 | exit 0，0 错误 | `level_01_deleted_90.log` |
| 真实 J（共享 `dlc/ui/tests`） | **23 / 0** | `../ui/tests/real_j_damage_test.log` |
| 开场说明页（共享） | **81 / 0** | `../ui/tests/guide_test.log` |
| 说明页演示 | 3 页均真实关卡帧条 24 帧 / 8 fps | `../ui/demos/rift_*.png` |
| 640×360 说明页 | 两关各 3 页，均 640×360 | `../ui/tests/out/*_guide_*.png` |

机制测试新增覆盖：

- 先击败金守卫，再让青守卫造成两次受击 → 恢复结束 0.8 s 悬浮 → 两只 ACTIVE、
  各 3 格、`0/2`、完成核心暗、玩家可移动；
- 先击败金守卫，再坠落 → 同样两只完整回来；
- 原有失败/R/双守卫真伤路线继续通过（121 项 0 失败）。

### 未做 / 局限

- 真实 J 测试仍用 `debug_force_gravity()` 把守卫推进既有蓄力态（避开 3 s AI 周期），
  但攻击是真实物理 J 事件，命中由守卫自己的 `receive_player_hit()` 结算。
- 未做真人整关节奏/可读性终审；说明页只核看 Celeste 两张静态画面，未核看其翻页动画。
- 标题菜单两个 DLC 入口的视觉层级未改：需要动 `scripts/start_menu.gd`，按约束先报告。

---

## 2026-11-26 环境音乐接入 + 反馈打磨（本轮）

分支 `dlc`；未切分支、未提交、未推送、未导出。只改 `dlc/rift_workshop/`（含测试）
与共用的 `dlc/trial_chambers/chapter_ambience.gd`。`scripts/start_menu.gd`、`dlc/ui`、
`dlc/audio` 源文件、`dlc/star_loom` 和基础三关均未改。

### 音乐

- `Ambience` 节点（`track_name = rift_ambience`，`autoplay = false`）复用
  `dlc/trial_chambers/chapter_ambience.gd`：`.ogg` → `.wav` → 静音，运行时解析，
  不 preload；在流副本上设 `AudioStreamOggVorbis.loop = true`；音量 **-20 dB**；
  暂停页 `stream_paused`，完成页 0.7 s 淡出，回标题停止，R 从第 1 帧重开；
  说明页打开期间不播。
- 文件：`dlc/audio/music/rift_ambience.ogg`，80.000 s，解码峰值 -7.72 dBFS，
  最终峰值约 -27.7 dBFS；首尾样本差 -27.9 dBFS（经 -20 dB 增益约 -48 dBFS）。
  共享音乐测试覆盖真实播放/循环/暂停（见 trial 侧 `ambience_test.log`，52 / 0）。

### 反馈修正（三处客观问题）

1. **最终 “2 / 2” 被覆盖**：原代码先写“青守卫已倒下 · 2 / 2”，下一行立刻被
   “双生守卫已倒下 · 裂隙核心开启”替换，玩家看不到最终计数。现合并为
   “双生守卫已倒下 · 2 / 2 · 裂隙核心开启”（2.4 s），截图
   `out/completion.png` 左上可见。
2. **双守卫下砸完全无声**：`slam_contact` / `gravity_release` 原本是 `pass`，
   而试炼章和基础第三关都有下砸音。现由 DLC 内 `rift_audio.gd` 运行时只读加载
   已批准的 `assets/level03_prototype/audio_slam.ogg`（-4 dB，60 ms 内两只守卫
   合并成一次），不改 DemoAudio/基础音频。
3. **恢复黑幕期间光灵嗡鸣又响**：`_begin_recovery()` 关了 hum，但 `_process()`
   下一帧又按距离重新打开。现在 `_recovery_active` 期间保持关闭，恢复结束后
   再按距离恢复。

另新增 `RiftPolarityWisp.is_hum_playing()` 只读访问器供测试使用。

### 本轮测试结果（全部 exit 0）

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 导入 | exit 0，0 ERROR/WARNING | `import.log` |
| 机制测试 | **121 / 0** | `mechanics_test.log` |
| 真实输入路线 | **37 / 0** | `route_test.log` |
| 标题入口（存在） | **34 / 0** | `title_test.log` |
| 标题入口（缺失） | **14 / 0** | `title_missing_test.log` |
| 新反馈测试 | **15 / 0** | `polish_test.log` |
| 新章 90 帧 | exit 0，0 ERROR/WARNING | `rift_90.log` |
| 基础三关 90 帧 | 三关 exit 0，0 ERROR/WARNING | `level_0*_90.log` |
| 移走 trial+rift 两章后 level_01 90 帧 | exit 0，0 ERROR/WARNING | `level_01_deleted_90.log` |

`polish_test.tscn` 覆盖：首次击败显示 “金守卫已倒下 · 1 / 2”、最终行保留
“2 / 2”、完成核心点亮、下砸音真实播放且 60 ms 合并、靠近光灵有 hum、
坠落黑幕期间 hum 保持关闭、检查点复活后 hum 恢复。

### 截图（均 640×360，`out/`）

新增/更新：`ambience_state.png`（测试脚本读取真实播放器值：`rift_ambience.ogg |
80.00 s | vol -20.0 dB | loop on | playing yes | pos 0.19 s`）、
`failure_retry.png`（两次 `player_struck` → 黑幕 → 回竞技场入口，两只守卫满血、
事件行“失败 · 回竞技场入口”）、`completion.png`（最终 2 / 2 + 核心开启）。
其余 10 张门/桥/浮灵/双守卫截图同前，均 error=0。

### 跨任务协同

- 标题菜单第三行 `星核织机` 由另一个任务加入。本目录的 `title_test.gd` 与
  `title_missing_test.gd` 已改为“下一个可见入口”断言，不再硬编码
  rift → start；本关仍为 34 / 14 项 0 失败，未改 `scripts/start_menu.gd`。

### 未做 / 局限

- 未做真人听感；音乐循环接缝只有数值 + 引擎状态证据。
- 基础三关只读审计：标题 + 三关 640×360 截图在 `out/audit_*.png`，
  基础脚本/场景 diff 为 0；标题的 DLC 行视觉层级与第三入口属于另一个任务。

