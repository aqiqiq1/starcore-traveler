# 第二关重建 + 统一地面接入（2026-11-13）

历史快照（2026-11-13）：当时正式 L1/L2 已接入、守卫移出 L2，第三关未制作。当前三关从 F5 已接通，状态见[当前交接](../../progress.md)。保留以下首版布局与验证结论，不视为现版全量验收。

## 文件与入口

- 正式 L2 F6：`scenes/level_02.tscn`
- 正式 L1 F6：`scenes/level_01.tscn`（完成页仍进入 L2）
- 新 L2 脚本：`scripts/level_02.gd`；HUD：`scripts/level_02_hud.gd`
- 多屏仓：`scripts/level02_bay.gd` + `scenes/level02_bay.tscn`（只扩展释放点边界，共享仓规则未改）
- 生成地形：`assets/bridge_stone_v1/generated/`（用 `source/build_block.py` CLI 原生像素输出）
- 柱脚：`assets/bridge_stone_v1/columns/doric_column_{tall,broken,base}_basesquare.png`
- 新 art PNG 均未改；Godot 为 `generated/` 与 `columns/` 添加 `.import` 元数据以支持 `res://` 引用。
- 捕获：`tools/bridge_ground_capture.tscn/.gd`
- 截图：`screenshots/level02_rebuild_20261113/raw/01_l1_ground.png`、`02_l2_initial.png`、`03_l2_linked_combo.png`；02 已重捕，可见 80,320 的 F 石碑且不自动弹页。

## L1 正式接入

- `StartGround` / `HighPlatform` / `FarBank` 三块原地形 `draw_visual=false`，各挂 `centered=false / position 0,0 / Nearest / scale 1` 的新 PNG：1024×64、336×144、496×64。
- 原碰撞、block_size、节点位置完全不变；出生、人物、对白、符石、恢复点、出口、相机未动。
- 三张现有柱场景改为新平底柱脚 PNG，offset/脚点/摆位不变；`World/Decorations` 仍保留原 10 件摆位。

## L2 空间与路线（1792 px）

- 地面 y320 连续；相机跟随，limits 0..1792。
- 起始仓 128、中继仓 352：A 安全初运，两仓同屏，无坑/敌人/符石。
- 低廊 464..720：20 px 净空（y300..320），只容 16 px 核；玩家跳上 268 高的 48 px 桥墩，再走 5 段 22 px 石梁，梁间 10 px 真实空隙用于施力。桥墩/梁均使用同一新石材，无整张图盖缝。
- 联动仓 960；符石 1040,150；石栅高台 1080..1240，顶 240、底 300，下方保留 20 px 核通道；左端 1040..1080 为 40×12 薄挑沿。
- 最终仓 1568；出口 1680；右侧 112 px 缓冲。
- 全程单活动核；中继/联动仓只记录与恢复，只有最终仓锁定、关联记录/符石已实际落定且玩家到出口才完成。

## 联动与恢复

- `BayRuneLink` + `RuneStoneField` + `PolarityLinkVisual` 真实时序保留：E 接受读取活动核自身极性 → 灯先变 → 脉冲 → 首次亮起结束才提交实际力；Q 只改玩家；取核记录/符石保持。
- 新增两个恢复点：中继仓完成（stable 1）与联动仓完成（stable 2）。玩家死亡/核越界回到最近已完成仓：玩家位置、唯一核所在仓、仓记录、关联符石一致。
- 恢复前取消在途脉冲/亮起；新增的 `restore_committed()` / `restore_committed_state()` 只用于恢复已提交状态，不改变默认时序。
- 稳定记录按 stage 前进；同一中继/联动仓再次完成不同相性时更新当前 stage 的最新有效 phase，不沿用第一次；更早仓不能把 stage 2 回退到 1。
- 出口统一由一个 `is_exit_gate_ready()` 判定：最终仓 LOCKED + 联动仓有记录 + 符石实际已激活/已落定 + 记录相性与石相性一致；取最终核或记录/石未完成即关闭，不依赖 `initial_positive`。
- R/暂停重开仍是整关重开：清两/四仓记录、核回起始仓、取消脉冲/亮起、玩家回出生；完成后 R 同样重开。
- HUD 底行写明“失败回最近稳定仓 · R 整关重来”；中继/联动入仓显示“尚未通关”。安全初运的 HUD 明确“把星核送入中继仓”，不是泛泛的“E 存入空仓”。

## 输入与石碑

- L2 恢复 raw `_input` → `_player.handle_key_event()` 转发；左 Shift 位置与同向双击由正式关卡重新拥有。暂停/完成/离场/echo 不转发；暂停/失焦/重开清 movement latches。
- 恢复 `scenes/tutorial_stele.tscn` 载体于 `(80,320)`，保留 F 主动阅读；`tutorial_stele.gd` 新增默认 true 的 `auto_open_on_focus`，L2 设 false：靠近只显示“F 阅读”，不自动弹页。4 短页只讲释放/相性/中继/低廊真缝/联动记录与恢复，无战斗/新剧情。
- 暂停时石碑 suspended，恢复后回“F 阅读”；R/失败恢复会清页。未新增 NPC。

## 守卫

- L2 scene 已无 `Guard` 节点；Player 使用基础 `player.gd`，无 J 攻击；暂停说明无战斗行。
- 旧 `scenes/enemies/polarity_golem_guard.tscn` 与敌人脚本保留。未来 L3 门前需要迁回：原场景位置 `(344,264)`、`world_left=244/right=388`、`floor_y=264`、`patrol 260..376`、`pursuit 244..388`、初始辉相、3 HP、8 秒重组；这些只是历史参数，本轮未在 L3 实装。
- L2 完成页只保留“返回主界面 / 重玩本关”，不跳不存在的第三关。

## 关键证据

- `tests/test_bridge_ground_rebuild.tscn`：55/0，L1 三块碰撞/新图尺寸、四仓/单核/链接路径/长度/无 Guard/恢复 setup。
- `tests/test_level_02_route.tscn`：24/0，从出生真实输入完成：释放→推动→中继 E→低廊推/跳/缝拉→联动 E→脉冲亮石→取核→石栅走廊→跳+借力上 240 高台→拉核→最终 E→走出口；无传送绕点；安全初运 HUD 明确“中继仓”。
- `tests/test_level_02_checkpoint.tscn`：49/0，核越界回中继、跌落回联动、同仓二次不同 phase 更新稳定记录、无符石跳不上 240、Esc 暂停冻结/恢复、最终仓取核出口关闭/先到出口不结算、最终仓锁定但无记录/未激活不能结算、R 取消在途脉冲并清记录。
- `tests/test_level_02_input.tscn`：31/0，真实 InputEventKey 下 A/D=100、左 Shift+D=160、右 Shift 不跑、同向双击跑、暂停/失焦清缓存不误跑、R 完成后可走；F 石碑打开/暂停/重开冒烟。
- `tests/test_level_flow_rebuild.tscn`：10/0，L1 完成页真实按主按钮进入 L2；L2 独立完成页 setup 后真实按“返回主界面”回真实 L1 标题。
- 日志：`tests/logs/level02_rebuild_route.log`、`level02_rebuild_checkpoint.log`、`level02_rebuild_input.log`、`level_flow_rebuild.log`、`level02_route_stdout.log`、`bridge_ground_capture_stdout.log`。
- 保护：`tools/bridge_ground_protection.py`，77 项基线；授权变化为 L1/L2 scene、L2 script/HUD、三张柱 scene、link/rune/tutorial_stele 的小型 additive 方法；`unauthorized=0`。

## 备份

从仓库中的游戏项目根目录看，备份位于`基础场景原型/项目归档/关卡改版前_20261113/L2_unified_ground/`（即本Godot工程内部，不是上级同名项目归档）。含9个实际覆盖文件的逐字节副本与`MANIFEST.json`（含SHA256）。为恢复石碑F-only选项另备份`scripts/tutorial_stele.gd`到同目录，并写`MANIFEST_addendum_tutorial_stele.json`；原9项与MANIFEST未覆盖。

## 2026-11-14 交付漏项修复：备份树被 Godot 类扫描

- 现象：备份目录无 `.gdignore`，Godot 扫描后旧 `class_name` 把 `RuneStoneField/BayRuneLink/Level02/Level02HUD/TutorialStele` 的缓存路径指到备份，出现 “RuneStoneField hides a global script class”。
- 修复：新增 `项目归档/.gdignore` 隔离整棵备份树；备份旁新增 `README_RESTORE.md` 说明恢复方式。原 `MANIFEST.json`、10 个备份脚本/scene 字节未改；未改玩法、未重命名全局类、未删备份或整份 `.godot`。
- 正常重扫：`Godot_v4.7.2-stable_win64_console.exe --headless --editor --import --quit --path .`，退出码 **0**，日志 `tests/logs/godot_class_cache_rescan_20261114.log`。
- 缓存验收：`tools/verify_class_cache.py` 通过；5 类均只指正式 `res://scripts/...`，无任何 `项目归档` 引用，无重复 class；10 个备份内容 hash 全一致（`tests/logs/class_cache_verify_20261114.json`）。
- 同因 UID 检查：5 个正式脚本与备份 `.uid` 均不同、无重复；未删任何 UID 或缓存文件。
- 载入验收：L1/L2 headless 各退出码 0；`test_bridge_ground_rebuild` **55/0**（`tests/logs/bridge_ground_rebuild_after_cache_rescan_20261114.log`）。
- 用户 GUI 编辑器当时在运行，未强杀；若旧内存里的错误仍显示，请关闭并重新打开工程（不改未保存场景）。

## 看图与局限

- 实机图已看：L1 新三块石材/暗部替代旧土；L2 初始两仓同屏、低廊与缝可读；后半联动图显示活动符石、空联动仓、核在石栅下、玩家在高台顶。
- 后半联动截图为分段 setup 定帧（非通关）；不是单帧完整地图。
- 未做人工连续试玩；路线由真实输入自动跑通，手感/难度需用户试玩。
- 240 高台借力需要“先跳、后借力/换相”的操作；无符石时普通跳上不去已断言。若用户觉得操作窗过窄，应调布局而不是改共享力参数。
- 高台/低廊的美术仍是较整洁砌体，不是大面积坍塌；无新假可站平台。
- 出口现有美术只有 open/completed 两态；取最终核后完成条件与 HUD 会回“未就绪”，但没有新增第三张“关闭门”图。若需要实体关门视觉，应另批门美术。
- 未制作第三关、未做存档/选关、未改全局 project.godot。

## 协调者独立复核

- 已打开全部三张真实图（含补回入口石碑后的02），检查材质暗部、核通道/真缝、关联石与柱脚；观察仍偏规整砌体，最终观感/节奏待创作者试玩。
- 审查L2流程/恢复/出口、自动路线与输入测试，发现并安排修正raw键盘转发漏项、同仓换相恢复旧记录、出口缺关联条件与入口石碑被移除四处集成问题；当前代码与新增聚焦证据已复核。
- 独立运行`test_level_02_input`得31/0，`test_level_flow_rebuild`得10/0，均进程退出0；前者失焦项为直接调用失焦处理器，不冒充真实OS焦点切换。日志另存`C:/Users/aqiqiqi/AppData/Local/Temp/opencode/l2_rebuild_coordinator_input.log`与`l2_rebuild_coordinator_flow.log`。
- 独立保护检查77项、授权变化10/未授权0；原9份备份逐项SHA256一致；新平底三柱上部像素与原柱图一致。L1场景与改版前逐行diff仅三张新纹理、关闭旧绘制与三个视觉子节点，原几何/人物/机制参数未变。
- 出生到出口24项实输入路线、49项恢复/联动及55项地形集成为工程执行，协调者已审代码和日志，未重复全套、未人工通关。不能把自动路线当手感或完整三关Demo验收。
