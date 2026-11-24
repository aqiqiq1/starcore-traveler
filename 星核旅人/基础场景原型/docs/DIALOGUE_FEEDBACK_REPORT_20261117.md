# 三关对白、第二关解锁与声音反馈修订 — 交付报告（2026-11-17）

> 历史交付记录。旧 F5 提示仅代表当时；现版从第一关标题进入三关，见[当前交接](../../progress.md)。

第1–9节保留阶段一的独立逻辑/音量/诊断记录；第10节为正式接入与证据更正，**当前交付状态见第11节**。以下阶段一“未开始”不代表当前状态。

范围与保护：未改共享 `player.gd` / `guard` 战斗状态机 / `StarCoreInteractionRoom` / 布局 / 门墙 / 电影 / 现 Q / BGM / 旧音素材 / 旧日志 / 旧 before；无 Git 写操作。用户之前未提交的脚步与重组 5 文件修改原样保留。

## 1. 修改文件

| 文件 | 改动 |
| --- | --- |
| `scripts/level_03.gd` | 蓄力音生命周期守卫（`_charge_watch` / `_tick_charge_watch`），碎裂与常规路径清理 |
| `scripts/audio/demo_audio.gd` | `gate` 事件 −4 → **−10 dB** |
| `scripts/level03/l3_audio.gd` | `FloatWarn` −4 → **−10 dB**，`FloatSettle` −5 → **−11 dB** |
| `scripts/level_02.gd` | 中继仓完成解锁特殊四 body 的“玩家—核”力线；R/重玩重锁；稳定恢复保持 |
| `tests/dialogue_feedback_20261117/test_dialogue_feedback_20261117.gd/.tscn` | 本轮聚焦测试 |
| `tests/dialogue_feedback_20261117/capture_dialogue_before_20261117.gd/.tscn` | 修前截图 |
| `tests/dialogue_feedback_20261117/screenshots/*.png` + `MANIFEST.txt` | 四张 640×360 修前证据 |

`demo_audio.gd` 的 `player_hurt` 仍是 −5 dB、`slam`、`charge`、`reassemble`、`stone_cue` 等未改。`l3_audio.gd` 里已有的重组 A 路径与旧注释是用户先前改动，本轮未动。

## 2. L3 蓄力音被中断后不止声

根因（读码可证）：`charge_started` 才 `play_charge()`；正常 `slam_contact` / `gravity_release` / `defeated` 会 `stop_charge()`。但 `receive_player_hit()` 在 `GRAVITY_CHARGE` 或 `GRAVITY_RELEASE` 中走 `_apply_gravity_break()` → `_begin_scatter()` → 发 `shattered`，原 `_on_guard_shattered()` 只播碎裂声，没有停蓄力；HURT/其它非蓄力状态同样没有停。

修法（只改本关，不碰守卫状态机/常量/受击数）：
- `_on_guard_charge_started` 置 `_charge_watch = true`，仍在真实开始才播。
- 每个物理帧 `_tick_charge_watch()`：仍处于 `GRAVITY_CHARGE` 就不动；一旦公开的 `get_state_name()` 离开该状态，`stop_charge(0.04)` 软停并清标记。同一蓄力只触发一次，避免每帧重启 tween 永不淡出。
- `_on_guard_shattered()` 额外立即软停（碎裂发生的同一调用栈）；正常播放入口/释放/击败清 `_charge_watch`，不重复。
- 暂停（`get_tree().paused`）时 tick 直接返回；电影/挂起若只 `set_suspended` 保持 `GRAVITY_CHARGE`，不误停；若 `set_cinematic_mode(true)` 把守卫切回 ACTIVE（代码如此），则视为真实离开蓄力并停止，不再让声音吊着。

实测（Godot 4.7.2，真实输入）：
- 真实 J（异相、正面 30 px、真实 `request_attack` 窗口）→ `TRUE_HIT`，`true_marks` 0→1，命中后 **2 个物理帧（约 0.033 s）** 内 `is_charge_playing()` 变 false（0.04 s 淡出）。
- 暂停：`playing` 变 false 但 `stream_paused=true`、播放位置冻结在 0.163 s；恢复后 `playing=true`、位置 0.195 s 继续，**不是 stop**。
- 挂起（`set_suspended`）保持 `GRAVITY_CHARGE`，蓄力继续；`set_cinematic_mode` 使状态回 ACTIVE 后 3 帧内停。
- 正常蓄满释放：进入 `GRAVITY_RELEASE` 后蓄力停，`enemy_ring_count` +1。
- 守卫重置（R/重试/阶段恢复所走的同一 `reset_state`）：3 帧内停。

未验：真实 R 键在 L3 的完整场景重载只由同一状态重置覆盖，未单独按键重载；未实听 0.04 s 淡出的听感，只验证了播放状态。

## 3. 门与浮动平台降 6 dB

- `DemoAudio` `gate` 事件 −4 → −10 dB；L3 `FloatWarn` −4 → −10、`FloatSettle` −5 → −11。
- 测试直接读事件表与播放器 `volume_db`，均通过；其它事件值未变（`player_hurt` 仍 −5）。
- 未改任何原音频文件；未实听新音量平衡，只确认参数落地。

## 4. L2 中继仓首次完成解锁

规则落地：
- `_special_wall_unlocked` 只在本关 `_complete_store()` 且 `_store_bay == RelayBay`（真正完成入仓，不是开始、不是靠近）时置 true。
- `_is_line_blocked()` 只有解锁后才把这四个特殊 RID 从“玩家—核”力线里排除；锁定时按普通墙查询，普通墙/地形/符石遮挡的查询完全不变。
- 稳定恢复（跌落 `_restore_stable("fall")`、核越界 `core_out`）不清标记；R/完成页重玩走 `_reset_room_state()` 清标记；`debug_restore_stage(RELAY)` 明确建立解锁，`debug_restore_stage(START)` 重锁。
- 未改布局、未改共享 `StarCoreInteractionRoom`、未改 100 px/E/Q/四仓/门条件。

真实流程实测（不直接调解锁）：
- 初始：顶部墙射线 `(1060,270)→(1260,270)` 被 `LinkedWall` 挡住 true，地面射线 true，`unlocked=false`，四 body 注册 4。
- 只站到 RelayBay 附近（未存）：仍不解锁。
- 真实 E 从 StartBay 取核：`core.is_active()=true`，仍 **不解锁**。
- 玩家/核到 RelayBay，真实 E 入仓：刚按下、动画未完成时仍 false；等待 `_complete_store` 后 `unlocked=true`、`stable_stage=1`；同一射线变为 **false**（只跳过特殊墙），地面射线仍 true。
- 真实 E 取出 Relay 核：解锁保持。
- 再存回 StartBay：可以正常存，仍保持解锁（不重锁）。
- 跌落（`on_player_reset("fall")` 真实稳定恢复）：`stage=1`、解锁保持。
- 核越界：稳定恢复后仍 `stage=1`、解锁保持。
- 暂停菜单 `restart_requested`（R/重玩的真实信号）：`stage=0`、`unlocked=false`，特殊墙射线重新挡住。
- `debug_restore_stage(1)` 解锁、`debug_restore_stage(0)` 重锁。

限制：测试中“送核到中继仓”用玩家/核位置摆放做 setup（真实 E 存/取），没有从起点一路拖核走完 364 px；真实首次流程的物理搬运仍需试玩确认。落地/越界恢复用的是真实 `_restore_stable` 路径。

## 5. 受击缺声诊断（未换素材）

接线事实：
- `DemoAudio.play_player_hurt()` 由 `level_03._on_guard_player_struck()` 在真实 `player_struck` 后调用；事件表 `player_hurt` 指向 `assets/audio_demo_v2_20261116/player_hurt.wav`，−5 dB。
- 文件实测：0.340 s、44.1k mono、峰值 **−3.0 dBFS**、RMS **−18.9 dBFS**（−5 dB 后峰值约 −8、RMS 约 −23.9）。
- 同事件下砸 `audio_slam_v5.ogg`：0.92 s、峰值 −2.99 dBFS、RMS −20.2 dBFS（播放器 −1.5 → RMS 约 −21.7），比受击更长、更响，并在同一受击窗口附近播放（环形攻击是先结算命中、再发 `gravity_release` 播下砸；普通下砸的先后依状态帧而定），存在掩蔽风险。

运行实测（真实蓄力环命中，`RING_HIT`）：
- `player_hurt` 计数 0→1，`WorldCue1` 正在播放该流；世界池 1/6 占用，未被池抢占、未被 `stop_world`/暂停停掉。
- 保护期拒绝：走守卫真实 `_resolve_normal_strike()`，`PROTECTED`，计数不变（第二声 0）。
- 第二击：等保护结束后真实蓄力环再命中，计数 1→2，`player_hits=2`、`retry_pending=true`、`recovery_active=false`（0.15 s 反应后才开始淡黑），受击声没有被同帧切掉。

结论：当前不是“事件漏接”，也不是播放器被抢占；更可能是 **0.34 s 的短合成受击被 0.92 s 的下砸/环声掩蔽**，加上本身 −5 dB 偏轻。**未实听**，所以不能断言实际听不见，也不能把计数当成“听起来存在”。等协调核受击人声源后按方向文档换流；本轮没有叠第二条受击声、没有调大下砸。

## 6. 修前 640×360 对话画面

命令：`Godot_v4.7.2-stable_win64_console.exe --path . res://tests/dialogue_feedback_20261117/capture_dialogue_before_20261117.tscn`；四张均为 640×360，`get_viewport().get_texture().get_image()` 实帧。

| 图 | 状态 | 当前对话矩形（屏幕） | 画面观察 |
| --- | --- | --- | --- |
| `l1a_guide_meeting_dialogue.png` | L1 初遇，玩家在残响脚点，真实 F 第 1/3 页 | (100,102) 300×106，底 y=208 | 残响全身可见，面板底与人物头顶有明显间距，本帧不遮 |
| `l1b_guide_highstep_dialogue.png` | L1 高台，真实 F 第 1/3 页 | (202,102) 300×106，底 y=208 | 残响头身完整，面板在头顶上方，本帧不遮 |
| `l2_start_stele_dialogue.png` | L2 入口，真实 F 第 1/4 页 | (4,138) 300×90，底 y=228 | 玩家与残响在左下，面板在其上方，本帧不遮 |
| `l3_cinematic_echo_bubble.png` | L3 演出 ECHO/DIALOGUE 第 1/3 页，全文已显示 | (171.0,158) 246×56，底 y=214；锚点 (294.0,220) | **气泡底边压住残响精灵上半身/头**：残响精灵约 (270,186) 48×64，气泡盖住其顶部约 28 px |

L3 的几何可复核：`_echo.global_position = feet + (-26,-74)`，`offset(-24,-60)` → 精灵屏幕约 y 186–250；`_bubble_anchor_screen()` 只取 `echo.global_position + (0,-26)` = y 220，气泡底 = 220−6 = 214，所以确实盖住 186–214 的上半身。L1/L2 的 `_layout_dialog` 用 `foot − FRAME_SIZE.y − PROJECTION_LIFT − DIALOG_GAP − panel_height`，底部固定在脚点上方约 92 px，本次正常页与人物头之间仍有空隙；更长页只会向上长，不会向下遮头（但仍以真视口测试为准）。`l3_cinematic.get_echo_screen_rect()` 返回的 40×40 是测试辅助矩形，不是精灵实际 48×64 边界，报告以实际几何为准。

底部提示现状（供下一阶段按范围删）：
- 唯一仍显示在游戏画面底部的是 L3 演出 `l3_cinematic.gd` 的 `_hint` Label（`_build_ui` 创建，位置 (16,332)，608×23，文本“空格 继续 · 长按 0.6s 跳过”，随 `_set_bubble_visible` 显隐）。截图中可见。
- L1/L2 实机截图没有常驻底部键位条；`level_hud.gd` / `level_02_hud.gd` 只保留 `get_controls_text()` 兼容字符串，L2 的操作提示面板在 (160,104)，不是底部；完成页的键位句在完成面板内（`level_hud.gd` / `level_02_hud.gd` 的完成 overlay）。
- 暂停页的按键表由 `scripts/ui/pause_menu.gd` 的 `controls_rows`（各关 `_setup_pause_menu` 填充）绘制。

本轮没有改任何对白/布局/字号/逐字/底部提示，截图是非视觉逻辑修改后、视觉修改前的状态。

## 7. 未做与待协调

- 未写/未换任何对白文本、未做逐字、未改对话布局、未删底部提示、未做拟声/记录声、未换受击声、未接 BGM、未换 Q。
- `docs/DIALOGUE_FEEDBACK_DIRECTION_20261117.md` 的 NPC 全文与新源（SilentStrikeZ mumble、Joth 记录声、qubodup 受击）仍是下一阶段内容；本轮没有下载、复制或制作这些声音。
- 对白与声音新源仍待协调定稿；L3 气泡遮头与 L1/L2 不遮的结论只针对本次四张实际帧，不代表所有相机/页/分支。
- 未做真人全关试玩、未实听任何音量/音色；功能/画面/声音三项分开：本轮通过的是功能与画面几何检查，声音只到“事件与播放状态”。

## 8. 验证记录

- 聚焦测试：`TEST_DIALOGUE_FEEDBACK_RESULT passes=39 fails=0`（音量、蓄力生命周期、受击接线、L2 解锁）。
- 截图命令见 §6，四张均 640×360，运行时状态与文件名一致（L1/L2 对话真实打开、L3 bubble/echo/hint 可见）。
- 保护检查：`python .openchamber/verification/dialogue_feedback_20261117.py` → `UNCHANGED 1518 CHANGED 4 ADDED 10 MISSING 0 / OVERALL OK`；4 个变更都在本轮授权文件内，新增在 `tests/dialogue_feedback_20261117/` 与既有 `docs/DIALOGUE_FEEDBACK_` 前缀内。
- 未跑旧 214/63/全项目 suite、未覆旧日志、未启动常驻服务、未做 Git 写操作。

## 9. 已知限制 / 未验

1. 蓄力软停只用播放状态与帧数验证，未实听 0.04 s 淡出是否自然；真实 R 重载场景未单独按键验证（只验证同一 `reset_state` 路径）。
2. L2 真实送核是用位置摆放 + 真实 E 完成，没有从起点一路物理拖核；首次真实搬运的手感/碰撞需试玩。
3. 受击“被掩蔽”是基于时长/电平/池占用的技术推断，未实听；换流前不能断言听感结论。
4. 四张截图只覆盖正常页第一页；最长页、L3 击败分支、暂停/失焦/离场等状态未逐一截图。
5. 音量 −10/−11 是否合适未实听；只确认参数与其它事件未被误改。


## 10. 最终接入（2026-11-17 第二阶段）

### 10.1 本轮文件

- 对白/呈现：`scripts/narrative/guide_echo.gd`（重写分页/气泡/逐字）、`scripts/narrative/dialogue_voice.gd`（新增共用拟声 helper）、`scenes/level_01.tscn`/`scenes/level_02.tscn`（仅 pages）、`scripts/level_01.gd`/`level_02.gd`/`level_03.gd`（记录声、L2 提示、暂停表）、`scripts/level03/l3_cinematic.gd`（文本/气泡/无底部 hint/voice）、`scripts/level_hud.gd`/`level_02_hud.gd`/`level03/l3_hud.gd`（完成页键位句、L3 底部 control hint）、`scripts/ui/pause_menu.gd`（>9 行的行距/提示位置）。
- 声音：`scripts/audio/demo_audio.gd`（新受击流、记录事件/目录）、`scripts/level03/l3_audio.gd`（阶段一 −10/−11 保留）、`assets/dialogue_feedback_20261117/`（3 音节、记录、受击、manifest、evidence）、`ASSET_CREDITS.md` 第 18 节。
- 证据：`tests/dialogue_feedback_20261117/` 新 final 套件、after 截图、派生脚本；旧 39 测试未覆；修前 4 图被同名覆盖后已从会话快照恢复（见 §10.7）。`previews/dialogue_feedback_20261117/audition.html` + 节奏拼合 WAV。

### 10.2 对白与呈现

- 文本按 direction 逐字替换：L1 初遇 3 页、高台 2 页，L2 入口 4 页，L3 守卫 3 页/击败 1 页，GuideEcho 默认页同步。未自行改写剧情或术语。
- 统一 L3 风格：宽 246 px、12 px、青色说话者/浅色正文/灰色页码、页码在标题行右侧、无 F/Space 页脚；正文按**全文**预排高度，逐字只改文字不改矩形，长页不抖动。
- 34 cps 逐字：L1/L2 的 F 第一次只补全文、第二次才翻页/收起；L3 Space 同理，长按 0.6 s 跳过保留。离开/暂停/失焦/收起/切场清页并停声。
- 气泡定位改用真实 `Sprite2D.get_global_transform_with_canvas() * get_rect()`（含 −18 px 投影、48×64 精灵），优先在真实头顶上方 8 px，HUD 安全区/玩家身体阻挡时改到玩家上方或左右侧，最后夹在安全区。`get_echo_screen_rect()` 不再是旧的 40×40 辅助矩形。
- 实测（after manifest）：L1A 气泡 (127,152,246×62)，echo (226,222,48×64)，player (242,266,16×34)；L1B 气泡 (197,152)，echo top 222；L2 气泡 (8,172)，echo top 242；L3 正常/击败气泡 top 121，echo top 186；均不交叠。三个不同采样时刻（首次约 6 物理帧后、再 +8、再 +8）的 reveal 5/10/14，气泡矩形完全相同，voice 计数 1/2/3；它们是采样点，不是连续三物理帧。
- `tests/.../screenshots_after/`：L1两处 full、L2 full、L3 正常/击败 full、L3 暂停、L1A 三张不同时刻采样，均 640×360；`MANIFEST.txt` 记录气泡/echo/player 矩形、页码、revealed 字数、voice 计数、hint 状态。L3 正常/击败为局部 setup（arena + 真实 cinematic helper），页面/相机/气泡为运行时对象。

### 10.3 底部提示与暂停

- 删除 L3 演出 `_hint`（`l3_cinematic.gd` 不再创建，getter 返回空/false）、L3 HUD `_control_hint`（`show_control_hint` 保留为兼容 no-op）、L1/L2/L3 完成页键位句（`level_hud.gd`/`level_02_hud.gd`/`l3_hud.gd`）。
- L1/L2 原本就没有底部常驻键条，本轮没有“移除不存在的条”。
- L2 唯一操作提示面板实际在 (160,104)，不是底部；文本改为“存入中继仓/取出…的星核”，错误为“无法存入：…”，保留交互与目标/错误反馈，不再显示 E 键名。
- L3 世界动作提示本就是“启动/重建浮地/取核/嵌核/存入/释放核”，未加键名；GuideEcho 的提示改为“交谈”，不再显示 F。
- 暂停表：L1/L2 增加“交谈/阅读 / 翻页：F（未显完先补全文）”；L3 增加“演出继续 / 翻页：Space”“补全文 / 长按跳过：Space · 0.6s”。11 行时共享暂停页行距改为 16 px、Esc 说明下移，截图 `l3_pause_controls.png` 可见完整绑定；设置/失焦安全说明未删。按键与物理未改。

### 10.4 运行声音

- `echo_mumble_1..3.wav`：SilentStrikeZ（Freesound 389644，CC0；有损 HQ preview），各 0.120 s、48 kHz mono PCM16，原音高，截 0.440–0.560 / 1.700–1.820 / 2.900–3.020 s，8 ms 淡化，无变调/合成/叠层；播放器 −10 dB。
- `record_confirm.wav`：Joth `Menu Confirm.mp3`（CC0），0.679 s、44.1 kHz stereo PCM16，+6 dB、5/25 ms 淡化，播放器 −3 dB。
- `player_hurt_vocal.wav`：qubodup `slightscream-11.flac`（CC0，2024-08-30 起），0.330 s、44.1 kHz stereo PCM16，固定降到峰值 −6.0 dBFS、5/20 ms 淡化，播放器 −3 dB；源接近满刻度（maxabs≈0.99999988，仅 2 个 near-full-scale 样本），历史硬削波未证实，任何既有削波不会因降响恢复。旧 `player_hurt.wav` 保留但不再被事件表引用。
- 共用 `DialogueVoice`：每 3 个有效字、至少 0.14 s、不同时叠两个；标点/空白不响；补全文/翻页/暂停/离开/失焦/跳过/电影结束立即停。`get_play_count()` 仅用于测试。
- 记录声：仅在真实新稳定阶段/首激活响一次——L1 真实 checkpoint；L2 Relay/Linked 的 `_complete_store` 且 stage 提高；L3 设备/符石仓/checkpoint 且 stage 提高。延迟 0.40 s 避开 core-seat（0.65 s）尾部；初始化/恢复/setup/R/同点重复不响；R 取消待播 token。
- `ASSET_CREDITS.md` 第 18 节记录来源/许可/裁点/增益/有损标记；运行资产目录 `manifest.json` 有原/新 SHA、证据副本。

### 10.5 实测结果

- 新 final 套件：`DIALOGUE_FINAL_RESULT passes=83 fails=0`（文本/宽度、L1 逐字+F、L2 真实首运、L1/L3 记录、L3 正常/击败气泡、Space/长按、真实 J/受击/保护/R、Master、清理）。
- 自然末音尾 probe（本轮小修）：`test_echo_tail_natural_20261117` `passes=5 fails=0`。3 字页在自然显示全的一瞬末音节仍在播，0.15 s 内自然结束且播放次数不再增加；手动 F 补全文仍立即停，离开仍停并关页。GuideEcho 自然完字不再调用 `complete_reveal()`；L3 行为未变。
- 记录延迟暂停冻结（本轮小修）：`test_record_pause_20261117` `passes=15 fails=0`。L2/L3 排队 0.40 s 后真实 `get_tree().paused=true` 0.55 s，record_save 仍 0；恢复 0.10 s 仍 0；剩余时间到点后仅 1 次；再排队后 R / 稳定恢复 / 离场均取消。产品 `_queue_record_save` 已改为 `create_timer(delay, false)`，令牌规则不变。
- L2 真实首运：从 `(36,320)` 出生 → 真实移动+E 从 StartBay 取核 → **回存 StartBay**（真实入仓完成，仍锁、stage 0、record 0）→ 再取核 → 移动并将核心自然带到 Relay → 等核心进入仓座后真实 E 完成 → `unlocked=true`、`stage=1`、record_save 0→1（延迟后）。之后取出不加、同点重存不加、跌落不加、真实 R 重锁且不加。全程未瞬移 player/core。
- L3：新受击流真实 RING_HIT 计数 1、`PROTECTED` 第二声 0、第二击计数 2；真实 J 在 GRAVITY_CHARGE 命中后 2 帧停蓄力；真实 R 键停蓄力且不报保存；checkpoint 首激活记录一次、重复/恢复不响；debug setup 不响。
- 截图：`tests/dialogue_feedback_20261117/screenshots_after/` 9 张 640×360，含 L1 两处、L2、L3 正常/击败、L3 暂停、L1A 三张不同时刻采样；修前 4 图已按 §10.7 恢复，未重拍。
- 保护检查：`UNCHANGED 1508 CHANGED 14 ADDED 57 MISSING 0 / OVERALL OK`；14 个变更均在 checker EXACT 列表内，新增在 assets/tests/docs 授权前缀与新 narrative 文件。
- 未跑旧 214/63/全项目 suite，未覆旧日志，无 Git 写操作。

### 10.6 未听审 / 未验

1. 三个拟声音节、记录声、新旧受击均**没有人耳听审**；节奏/电平/时长只是技术验证，不能当作“听起来像残响/不刺/可辨”的结论。
2. L2 Linked 记录声未走完整真实联动仓流程（只测 Relay 真实流程；Linked 用同一 stage 提高路径，未端到端）；L3 设备/符石仓真实记录也未端到端（checkpoint 真实、debug 不响已验证）。
3. 受击新流的可辨性/掩蔽未实听；旧合成仍保留作对比，未叠第二声。
4. L3 正常/击败截图是局部 setup（arena、force death、cinematic helper），不是整关从头试玩；所有页/相机边缘状态未逐页截图，只对全部页面做了逐行宽度≤234 与最长页高度检查。
5. R 只按一次验证蓄力清理；未验证 R 在菜单/设置层/演出中途的所有组合。
6. 记录声 0.40 s 延迟是为避开 core-seat 的技术选择，未实听三声是否仍糊。
7. 试听页 `previews/dialogue_feedback_20261117/audition.html` 是素材/节奏参考，不是人耳验收；未接 BGM/Q/creature。
8. `l1_open_real_F` 这一测试名的首次打开实际调用 `open_dialogue()`（setup），不是原生 F 按键；后面的补全文/翻页才是真实 F 输入。报告不把首次 open 冒称按键通过。


### 10.7 修前证据恢复说明

调试期间一次旧捕获脚本重跑，曾用新布局同名覆盖 `tests/dialogue_feedback_20261117/screenshots/` 的 4 张修前图和 `MANIFEST.txt`。发现问题后，已从本轮 opencode 会话的 snapshot 对象库取回对应旧 PNG（640×360，旧 300 px 面板/旧文本/L3 头气泡+底部 hint）并恢复原名，`MANIFEST.txt` 不是原字节恢复，而是按阶段一记录文字重写（当前 1011 B / SHA256 `4038612d0b410c8f3516f3c00363e2cbc660e447011fbdc67f8a2f765c5bb3d5`），不能称整份文字字节恢复。当前 4 图内容为修前布局，不是新布局重拍；但这是一次过程失误，特此记录。最终 `screenshots_after/` 为修后图，未混用。


#### 10.7.1 修前 4 PNG 恢复的可核标识

- snapshot 会话标识：`161644fc04d38b35ecd4ac0fc929bf70ed44dbd7`；只读对象库：`C:\Users\aqiqiqi\.local\share\opencode\snapshot\161644fc04d38b35ecd4ac0fc929bf70ed44dbd7\4346e5835e5f8530c64e4483d4caa0d81241644e`（bare git，无 commit/tree/ref，仅 index 与 objects；因此没有 commit-ish，只有 snapshot 目录标识与 blob ID）。
- 恢复时按内容找到旧 640×360 PNG blob，再逐字节写回原文件名；下表 blob_sha256 与 current_sha256 相等：

| 文件 | git blob SHA1 | blob SHA256 | 当前 SHA256 | 相等 |
| --- | --- | --- | --- | --- |
| l1a_guide_meeting_dialogue.png | `13fd1ebc5a58169203a231c189487c8bfae753ed` | `7319d2b5de83893cd994fdc21dee75ee51c908afb9cfa673233b3105680b4dd5` | `7319d2b5de83893cd994fdc21dee75ee51c908afb9cfa673233b3105680b4dd5` | 是 |
| l1b_guide_highstep_dialogue.png | `f163e1877120674250a26b3603d65a1d176e3ff6` | `a17e5b78aba0db6a1c788b7f800d89959deeb2ca12b29da3553e3955024f915a` | `a17e5b78aba0db6a1c788b7f800d89959deeb2ca12b29da3553e3955024f915a` | 是 |
| l2_start_stele_dialogue.png | `e3629700b5e7a2502dd422d52ee3c70e66196125` | `556381c4090c05f8fced5f4dc2c017e663e3a3e0344e5e38b9ced53c45c9ae8e` | `556381c4090c05f8fced5f4dc2c017e663e3a3e0344e5e38b9ced53c45c9ae8e` | 是 |
| l3_cinematic_echo_bubble.png | `0434b458c8eabc84b7e3b37f74793fa57a5a47d3` | `6d026d662d9b1c5a11a36189e0d0faa7ef150f18bee3d71719d0b803864658d0` | `6d026d662d9b1c5a11a36189e0d0faa7ef150f18bee3d71719d0b803864658d0` | 是 |

- `MANIFEST.txt`：未找到可证明的旧 1004 B 原 blob；当前文件是按旧记录文字重写，SHA256 `4038612d0b410c8f3516f3c00363e2cbc660e447011fbdc67f8a2f765c5bb3d5`（1011 B）。因此只声明“4 图字节恢复 + MANIFEST 文字重写”，不声明整份目录原字节恢复。
- 本轮没有重跑 `capture_dialogue_before` 来“证明”恢复；以上 SHA 直接对当前文件与 snapshot blob 计算。

## 11. 协调最终复核与交付边界

### 已交付

- 三关定稿短对白、统一小气泡/34cps逐字、真实精灵边界避让；底部演出/控制键位句去除，世界提示仅动作名，完整操作留暂停界面。协调已实际看L1初遇/高台、L2入口、L3正常/击败、暂停及逐字采样图，所查画面不遮残响/玩家。未穷举所有镜头边缘或进行真人三关通玩。
- L2真实首运的Relay完成入仓才解锁特殊隔墙力，回存Start不算，取出和稳定恢复保持、真实R重锁；守卫蓄力被打断停声；门/浮台均降低6dB；三个残响音节、记录确认、受击人声已试装。保留重组A/脚步，旧Q与BGM不动，不提交推送。

### 独立检查（按代码阶段区分，不合并冒称最新全量通过）

- 正式接入后、两个末尾小修前：`coordinator_final_20261117.log`，`DIALOGUE_FINAL_RESULT passes=83 fails=0`，退出0。覆盖L2出生→实际移动取核→回存Start仍锁→再取自然送Relay→真实E完成解锁与计数、真实J中断/受击与保护及真实R等；首次L1开页为方法setup，不是原生F，部分战斗/演出也有setup。退出有2个ObjectDB实例警告，未逐对象归因，不称全为既存或实机必漏。
- 修L2/L3记录延迟为`create_timer(delay, false)`后：`coordinator_record_pause_20261117.log`，`RECORD_PAUSE_RESULT passes=15 fails=0`，退出0、无警告。该专项直接setup排队，验证暂停冻结剩余0.40s、恢复后仅一次及R/恢复/离场取消，不冒称又走一次完整运核。
- 最后只删除GuideEcho自然完字时强停末音，手动补全文/离开等仍立即停：协调独立`coordinator_echo_tail_20261117.log`，`ECHO_TAIL_RESULT passes=5 fails=0`，退出0、无警告。内存三字测试页在显示全时末音仍播放；随后10物理帧检查已结束、未新发音，手动F与离开停止。**探针检查间隔约0.167s，不据此声称测得0.15s上限**；运行WAV长度约0.120s另有解码证据。没有重跑83/39/15或旧suite。
- 最终持久基线保护：1522项中1508不变、14授权修改、58新增、0缺失，`OVERALL OK`。第58项是协调末音日志；未改before。保护覆盖旧音/旧Q/重组/原图及未授权玩法文件，不代替听审。
- 五个运行WAV的源/新SHA、首末0、峰值未越界和试听16个本地媒体路径已独立核；受击原源仅近满刻度2个样本，历史硬削波未证实，manifest/生成脚本/credits已统一，WAV未因此重生成。SilentStrikeZ用的是有损HQ preview，不称无损母带。

### 待验与风险

- 拟声音色/句间节奏、记录声是否仍糊、受击是否清楚且不被下砸掩蔽，均未做人耳验收，机器通过不表示已自然/悦耳。试听页仅供试听，不是批准记录。
- L2 Linked、L3设备/符石仓的真实记录反馈未逐一端到端实走，共用阶段提高路径不等于已实走；Relay与L3 checkpoint已有针对证据。
- 逐字三图是间隔采样5/10/14字，不是连续三物理帧。修前4PNG已独立与snapshot blob逐字节核同；snapshot没有commit/tree/ref时间链，旧MANIFEST只按记录重写、原字节未找回，缺口不洗绿。
- 公开前主角/Golem许可仍待核；本轮新音CC0不代表整个工程可公开分发。

### 下一步

创作者打开`scenes/level_01.tscn`按F6，从正式第一关试玩三关对白与声音；F5仍为旧main沙盒。先听`previews/dialogue_feedback_20261117/audition.html`，重点报拟声是否自然、受击能否辨清、记录/门/浮台平衡。Q等小组文件，BGM继续暂缓。只对具体反馈定向修改。
