# L3 战败/跌落 恢复过渡报告（2026-11-16）

## 范围

仅 L3 本地战败与自动跌落恢复呈现。保留既有 L2→L3 真衔接、明红受击 shader、160 px/s 远离击退、0.15 s 反应、0.60 s 保护、第二击待机 0.15 s 与两击重打；未改 L1/L2、共享/实验 player、守卫规则、音频、电影、门墙、原资产。未新增无敌、检查点、死亡文字、血花或长动画。

## 实现

- `scripts/level_03.gd`：新增本地恢复状态机。第二击 0.15 s 反应完整结束后，0.25 s 淡黑；遮罩实际 alpha 达到 1.0 时才调用一次既有 `_retry_combat()` 或既有稳定点恢复；黑场保持 0.10 s，再 0.35 s 淡入，alpha 归 0 后才交还移动与守卫。重置计数/重置 alpha/重置位置可测。
- `scripts/level03/l3_player.gd`：只加本地钩子。共享 player 在 kill line 调 `reset_to_spawn("fall")` 时，先冻结并请求过渡，不先传送；黑场时再由同一钩子执行既有复位一次。未改 `player.gd` 或实验 player。
- `scripts/level03/l3_hud.gd`：新增全屏黑遮罩，位于普通 HUD（顶栏/目标/引导/提示）之上、完成页之下；独立暂停 CanvasLayer 16 仍在遮罩之上。
- 过渡期间：J/Q/E/移动/重复伤害拒绝，守卫挂起；Esc 暂停菜单可见且过渡时钟随 `SceneTree.paused` 冻结，继续后接着走。R、暂停返回、完成、失败离场、失焦均会清理或正确恢复；淡入结束清一次性输入，不把 E/确认键变成操作或跳跃。
- 授权内测试适配：`test_flow_hurt_20261116.gd` 与 `test_level03_revision.gd` 只增加等待真实过渡完成的异步等待，保留原断言。

## 测试（实际运行）

| 项目 | 结果 | 日志 |
|---|---|---|
| 新恢复专项 | **84 pass / 0 fail**，exit 0 | `tests/level03/test_l3_recovery_20261116.log` |
| 旧 159 受击/流程（含适配） | **164 / 0**，exit 0（原 159 项保留，新增 5 项过渡检查） | `tests/level03/test_l3_recovery_flow_hurt_adapted.log` |
| 旧 194 revision（含适配） | **196 / 0**，exit 0（原 194 项保留，新增 2 项） | `tests/level03/test_l3_recovery_revision_adapted.log` |
| 感谢页/重玩 | **47 / 0**，exit 0 | `tests/level03/test_l3_recovery_demo_finish.log` |
| L3 载入 | **34 / 0**，exit 0 | `tests/level03/test_l3_recovery_load.log` |
| 新 before/checker | 1381 unchanged / 5 changed（全部授权）/ 14 added（含本报告与日志，全部授权）/ 0 missing；OVERALL OK | `tests/level03/test_l3_recovery_protection.log` |

专项覆盖：真实守卫首击不重生；真实第二击先红/位移，再淡黑；重置 alpha=1.0 且在 ARENA_SPAWN；0.10 s 黑场；淡入后人物原色/可移动；过渡中 J/Q/E/移动/第三击拒绝；Esc 时钟冻结；自动跌落（真实走下台沿）在 kill line 截获；arena 稳定阶段保留；失焦完成后无黑/无守卫锁；R 快重开；菜单返回后无残留；只执行一次 reset。

说明：旧1371的5个历史`tests/logs`覆盖问题仍保留FAIL，旧before未改。本次新checker只针对新恢复授权建立起点，不是撤销旧失败；旧checker续查误写/按原范围重建的更正见本报告末节与brief，不能声称原字节未改。实现者未跑旧L2广测。

## 画面/连续帧

- 目录：`screenshots/l3_recovery_20261116/`（旧图未覆盖）。
- 关键帧：`a01_first_hit_no_reset.png`、`a02_second_hit_red_pending.png`、`a03_fade_out_partly_dark.png`、`a04_black_reset.png`、`a05_fade_in_partly_light.png`、`a06_after_fade_in_can_move.png`；自动跌落 `b01`–`b04`；暂停冻结 `c01`/`c02`；R `d01`。
- 连续条带：`strip/` 66 帧，`MANIFEST.txt` 记真实 `ms`/alpha/相位/重置/位置；`transition.gif`（56 帧、640×360）与 `transition_review.png`；`fade_alpha.csv`、`ANALYSIS.json/txt`。
- 实测：条带总 681 ms；首帧已 alpha=0.150（约在淡出开始后 0.04 s）；首次 reset 在 `f020` 224 ms，记录 `reset_alpha=1.0`，位置 `(1520,252)`；`fade_in` 自约 312 ms 开始，至 681 ms 归 0。配置为 0.25/0.10/0.35 s；逐帧存图与采样间隔让黑场读数约 0.09 s，实际逻辑仍按 0.10 s 计时。
- 像素核对：`a04_black_reset.png` 最大通道值 0（全黑）；`c01`/`c02` 暂停前后像素差 0（时钟冻结）。

以上均为状态 setup（竞技场/台沿），非整关通关；第二击头条序列用真实守卫命中，跌落/暂停/R 等用守卫自身 `player_struck` 信号或固定摆位进入同一过渡。画面不代表人工手感验收。

## 未验/剩余

- 未做真人整关与主观手感/节奏试玩；未做真实 OS 焦点切换（测试直接调用现有焦点处理函数）。
- 自动跌落在共享 kill line（y>430）才截获，此时人物已在 640×360 视口下方约 0.1 s；“走出画面后淡出”未提前到画面内。未改 fall 规则。
- 未接音频；未改受击 shader/L2/L1/共享 player/守卫。
- `--verbose` 下 revision 测试退出时有 4 个音频对象泄漏警告（测试 harness 既有音频释放路径，功能 exit 0）；未改音频。
- 未提交、未推送。

## 参考边界

协调前置实看记录：Terraria 原版旧多人实录复活段 `previews/player_hurt_20261116/refs/terraria_respawn_cut_1541-1543_contact.png`（1542.3 仍 slain，1542.4 突切地表，原例无渐暗）。本轮按用户明确要求使用本项目黑场遮复位再淡入，不照搬长等待/突切，也不声称原例采用相同动画。未复制第三方音像/像素。

## 完成状态

实现与本地验证到此；请协调独立核关键帧/连续条带与独立专项后再决定后续。

## 协调独立复核与更正

- 独立专项84/0，`RECOVERY_TEST_SUMMARY pass=84 fail=0`/`RESULT: PASS`/退出0，无脚本或解析错误；新日志`test_l3_recovery_coordinator.log`。是真守卫关键命中+明确setup的引擎测试，不是人工整关。
- 独立1386基线：1381不变/5授权修改/15授权新增/0缺失，OVERALL OK。5处修改是3个L3源与2个异步等待测试，L2/共享玩家/守卫/门墙/音频均未再改。旧1371保护历史日志问题不因此洗绿。
- 已看正常视口连续条带总览，核manifest reset前位置未变、alpha1时才到(1520,252)、淡入归0并解除挂起；独立PIL核a04全黑最大通道0。164/196/47/34为审工程完整摘要/日志，无必要全量重跑；相关新日志错误关键词扫描无命中。未真人整关/未独立OS失焦听审。
- 音频成果复用不重造：保留6原声副本与12合成候选。协调修正音频AUDIT、README/manifest说明与试听页中的旧“无失败候选/过场未实现”文字，音频二进制与播放脚本未改、新声仍未接。已打开本地试听页，将A/B预选failure/respawn，未自动播放。
- **续查误写更正**：协调先沿用旧上下文写入已有`FLOW_HURT_AUDIO_BRIEF_20261116.md`及旧checker路径，后发现已有报告/基线即停止原任务重做。旧before未动，运行源码未因此改。旧checker按保存的REVIEW明确范围重建，5旧日志FAIL保留；原brief/checker原字节无法由仅哈希基线恢复，**不宣称原文已恢复**。本轮新范围、参考、起点均另存`L3_RECOVERY_BRIEF`/`l3_recovery_before`，不将新基线用作历史通过证明。
- 当前可交F6试玩本地L3过渡；跌落在原kill line后才淡黑，有短暂出画空景仍如实保留。全屏时长/主观观感待创作者反馈，音色由用户试听后选择。未提交推送。
