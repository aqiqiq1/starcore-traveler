# 石地脚步技术准备阶段报告（2026-11-17）

> 注：§1–5 保留为技术准备阶段的真实边界（当时不发声、无素材）；正式接入结果见 **§6**：6 条脚步 + 重组 A 已接入，B 仅试听，Q 阻塞未替换，BGM 未接。全部仍未人耳听审。

> 本阶段**只做技术准备**：新增脚步声观察 helper 与局部测试，不改正式绑定、不改现 `DemoAudio`、不产任何新声音/素材、不接 BGM/重组/Q。没有音效接入完成，也没有听审结论。Git `f9915e2` 工作树未回滚，未做任何 Git 写操作。

## 1. 参考与帧选择

- 已读 `docs/AUDIO_MOVEMENT_BRIEF_20261117.md` 与根 `AGENTS.md`；协调的 `docs/AUDIO_MOVEMENT_DIRECTION_20261117.md` 已存在（脚步 6 变体/2 声部/走 -18、跑 -15/`reassembly` A/B/Q 暂缓），本阶段只提供其 §3 所说的“技术阶段观察节点的实际落脚事件”。
- 实际查看放大联系图 `C:/Users/aqiqiqi/AppData/Local/Temp/opencode/walk_run_contacts_20261117.png`：walk/run 均 10 帧；walk 0/5 为两只脚交替的**着地**帧，run 1/6 为前脚放下、后腿收起的**落脚**帧（run 0/5 前脚还偏高）。保留协调初选 **walk 0/5、run 1/6**，每循环两次。没有把这条项目帧判断说成外部游戏结论。
- 实测节奏与帧表一致：walk 每 5 帧 / 9 fps ≈ 0.556 s；run 每 5 帧 / 14 fps ≈ 0.357 s。测试在 60 Hz 下观察到 walk 间隔 33–34 ticks、run 21–22 ticks。

## 2. Helper（仅技术相位，不发声）

- 新增 `scripts/audio/player_footstep_audio.gd`（`class_name PlayerFootstepAudio`）。
- 只读公开接口：`get_state_name`、`get_anim_frame`、`get_anim_frame_count`、`is_on_floor`、`get_move_input_axis`、`global_position`；可选 `get_anim_restart_count`、`is_input_override_active`、`is_in_hit_reaction`、`is_completion_locked`。没有读私有字段、没有改物理/状态机/输入。
- 信号：`footstep_candidate(anim, frame, marker_index, world_position, speed)`。**不播放 placeholder、不创建 AudioStreamPlayer、不引用任何声音文件、不警告缺素材**。下阶段 bank 可直接连这个信号。
- 触发条件：只在 `walk`/`run`、`is_on_floor()`、输入轴超过阈值、真实水平位移同时满足时，在动画帧**进入**接触帧时发一次；不拿 `state_changed` 当每帧落脚。
- 排除：站立、顶墙（瞬时位移≈0）、原地左右抖按（窗口速度不足）、跳跃/下落、平台带移但无输入、受击滑行/输入覆盖、暂停、菜单/完成/复活锁。暂停依赖 `attach_to()` 后继承 player 的 `PROCESS_MODE_PAUSABLE`，菜单的 player 禁用也会让 helper 一起停。
- 防抖/防双：动画切换或 restart 的首个采样只作 baseline；帧进入接触帧才发；每物理 tick 最多一条；`min_step_interval_s=0.16`；大位移（>40 px/tick）视为 setup/teleport 重置 baseline；跨帧/循环通过“上次帧到当前帧的跨越集合”检测并测试。
- 阈值（可在 inspector 调，测试读取实际值）：`min_input_axis=0.12`、`speed_window_s=0.10`、`min_speed=25.0`、`min_instant_speed=15.0`、`min_step_interval_s=0.16`、`teleport_reset_distance=40.0`。
- 生命周期/启用：`bind_player()` 只绑定；`attach_to(player)` 把节点挂到 player 下，随 player 释放。`set_enabled_check(Callable)` 供关卡把“当前是否正常玩法”传进来；`set_enabled(bool)` 也可用。没有 autoload、全局单例或对其它关卡的改动。

**实际行为需知**：新动画/restart 的第一个采样不发。因此从静止起步的 walk 首个 0 接触不作为起步音，稳态序列从 `5,0,5,0…` 开始；run 从 `1,6,1,6…` 开始。稳态每循环两次成立。若下阶段希望“起步瞬间也落一脚”，应在 bank 阶段用 min-interval/速度门槛另定，而不是本阶段擅自改。

## 3. 局部测试与实测

- 新增 `tests/audio_movement_20261117/test_player_footstep_audio.gd/.tscn`；用真实 `l3_player.tscn` + 测试自建石地/墙（setup），真实 InputMap 动作与 player 的 `handle_key_event`（左 Shift）驱动。没有改关卡/player 场景。
- 命令：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  res://tests/audio_movement_20261117/test_player_footstep_audio.tscn --fixed-fps 60
```

- 结果：**100 项通过 / 0 失败，退出码 0**；日志 `tests/audio_movement_20261117/run_footstep_20261117.log` 与 `.console.log`。控制台**无 ScriptError、无 ERROR/WARNING、无 ObjectDB 泄漏**（本测试完全没有播放音频）。
- 实测数据：
  - walk（190 ticks）：5 次，帧 `[5,0,5,0,5]`，间隔 `[33,34,33,33]` ticks，速度窗口 100.0。
  - run（190 ticks）：7 次，帧 `[1,6,1,6,1,6,1]`，间隔 `[21,22,21,22,21,21]` ticks；首次加速期 52.5，之后 160.0。
  - 站立、停步、顶墙（输入保持、位置被挡）、左右抖按、跳跃/下落、落地无输入、暂停、generic input override、completion lock、受击反应/滑行、无输入位置漂移：**0 次**。
  - 走/跑切换与换向：所有相邻间隔 ≥ 21 ticks（≥0.16 s 门槛），无机关枪；切换确实跨过 walk/run。
  - 启用回调：开 1、关 0、再开 2；关时无排队补播。
  - 释放 player 后 helper 一并失效。
- 跨帧/循环：`_crossed_markers` 单测 `4→6` 跨过 5 报 `[5,6]`，`9→0` 环绕只报 `[0]`；稳态 190 ticks 的多循环无重复同帧。

测试限制（如实）：测试里的“平台带移”用无输入位置漂移模拟，“菜单/完成/复活锁”用 input override/completion lock 模拟；没有跑真实移动平台或真实菜单场景。没有测听感、没有测脚步素材（本阶段没有素材）。

## 4. 文件与检查

- 新增：`scripts/audio/player_footstep_audio.gd`；`tests/audio_movement_20261117/`（test、scene、两份本次日志）；本报告。
- 未改：`DemoAudio`、`l3_audio`、`level_01/02/03`、`project.godot`、player/实验 player、任何声音/图片/旧 12 候选/旧日志、BGM。
- Checker `.openchamber/verification/audio_movement_20261117.py`：**OVERALL OK**，1453 未变 / 0 改 / 7 新增（含协调已有的 `AUDIO_MOVEMENT_DIRECTION` 与本报告）/ 0 缺失。before 未动。
- 未跑旧 214/全项目 suite；未写 `tests/logs`；无 Git 提交/推送。

## 5. 待下一阶段（不属本阶段完成）

- 脚步素材/6 变体 bank、走 -18/跑 -15、pitch、2 个独立小声部、三关本地回调绑定：等待素材源与协调的最终单套规格；本阶段只有收集器/信号。
- 重组 A/B（倒放汇聚 / 独立滑移）0.60 s、Q 参考与最多 2 候选、试听页：均未制作/未接入。Q 因参考尚未听辨而暂缓；BGM 明确不接。
- 本阶段没有“音效接入完成”或“听审通过”的结论。


## 6. 正式接入阶段（2026-11-17 同日续）

> **边界更新**：§2 的“不发声 / 不创建 AudioStreamPlayer / 无素材”只描述上一技术准备阶段，仍然是当时真实边界；本阶段已把同一 helper 扩成局部 2 声部 bank。当前运行状态以本节为准，§1–5 保留作阶段记录，不抹掉原 100 项准备验收。

### 6.1 实际接入

- **脚步 6 变体**：`assets/audio_movement_20261117/footstep_stone_1..6.wav`，来自 Fantozzi（qubodup 代传 OGA）Stone L1–3/R1–3 FLAC（CC0 1.0），单声道 44.1 kHz PCM16，首尾 3/5 ms 淡化，峰值统一只降到 **-9 dBFS**（不硬抬弱条）。派生参数/源新 SHA/证据见 `SOURCE_MANIFEST.json`、`source_evidence/`、`previews/audio_movement_20261117/generate_movement_audio.py`。
- **局部 bank**：同一 `scripts/audio/player_footstep_audio.gd` 内部 2 个 `AudioStreamPlayer`（Master，PAUSABLE），保留原 `footstep_candidate` 信号与 walk0/5、run1/6 标记。6 变体顺序轮换、无立即重复；walk -18 dB/pitch 1.0，run -15 dB/pitch 1.05。不占 DemoAudio 的判伤/警示池，无全局单例。
- **三关绑定**：`level_01/02/03.gd` 各自把 helper `attach_to` 到本关 player，并用本地 `_footstep_allowed` 回调限制 intro/menu/completed/reset/recovery/cine/pause；菜单/完成/恢复/电影/重开/离开时调用 `stop()` 截断尾巴；暂停依赖树暂停冻结 bank voices；关卡/player 释放时 helper 随释放。未改共享 player/实验 player/guard 物理。
- **重组 A（默认）**：`assets/audio_movement_20261117/reassembly_A_reverse.wav`，0.60 s，峰值 -6 dBFS；取 heavy shatter 0.14–0.60 s 有效碎块段倒序 + 短低中频 Kenney 落定（相对 -20 dB），避开初始下砸和静尾，不做整段倍速/末端爆炸。`scripts/level03/l3_audio.gd` **只改** `REASSEMBLE_PATH` 指向 A；旧 6 源文件/charge/slam/float/seat 的路径与音量不变，旧 `audio_reassemble.ogg` 保留。
- **重组 B（仅试听）**：`reassembly_B_pauliuw.wav`，0.60 s，-6 dBFS；pauliuw `stone_rock_or_wood_moved.mp3`（CC0，工程已有）原速 + 轻落定/淡尾。该文件实际解码 **0.456 s**，研究记录另写 0.558 s，已在 manifest/页面写明两值；B 不进 runtime。
- **Q 明确阻塞**：没有制作/替换 Q，没有改 `polarity_switch_v2.wav` 或 DemoAudio 的 Q spec，没有改白闪/玩法。Outland 参考只进本地试听页，音轨内容未听辨。
- **BGM 未接**：无新音乐、无音乐播放器/总线/菜单；本页不放 BGM。
- 新试听页 `previews/audio_movement_20261117/audition.html`：Q 标记“不满意/本轮暂未替换”，Outland 视频相对路径 `../audio_movement_refs_20261117/refs/video/...`，按钮定位 205.5 s、213.0 s 自动停，禁自动播，明确未听辨/可能人声/禁分发；6 条单步 + 按真实 0.556/0.357 s 排的走/跑串（预览归一化，不是 runtime 混音）+ 重组旧/A/B；低音量、一次一条、停止、双击。没有复制 70 MB 视频，没有抽商业音。
- credits 追加 §17（脚步/A/B 源与派生）；旧 v2/6 OGG/研究目录/旧试听页未覆。

### 6.2 实际测试

- **Helper 银行回归（工程报告）**：`tests/audio_movement_20261117/test_player_footstep_audio.tscn`（`--fixed-fps 60`）**101 项 / 0 失败**。上一版 100 项中的“helper 无播放器/无流”断言已按本阶段授权替换为“2 声部/6 变体/Master”并新增银行加载检查；其余相位/排除/暂停/生命周期检查保留。日志 `run_footstep_20261117.log/.console.log`。headless Dummy 退出时有 **12 ObjectDB** 警告；与上一轮 Dummy 残留现象相近，但本轮12个未逐对象复核，不称已完整归因或全是既存。工程正常 WASAPI capture 未记录此警告；这不等于所有实机路径均无残留。
- **正式绑定集成**：`test_audio_movement_integration.tscn` 只跑一次正常 60 Hz（headless，`--quit-after` 仅防挂）**63 项 / 0 失败**，无 ScriptError/无警告。实测：
  - L1 **真实开始菜单** 按住移动 0 声；点击真实开始按钮、走完 intro 0 声；随后真实 walk 4 声/run 5 个 run 接触（帧 1/6），walk -18/1.0、run -15/1.05，6 变体无立即重复；停/跳 0；真实出口完成 0；真实“进入第二关”切场后旧 helper 随 L1 player 释放。
  - L2 L1 切场后的真实 walk/run；LinkedWall 前停住（x=1074，墙左 1080）墙推 0；暂停内 0、语音 `stream_paused`；Master mute 下仍走 Master 路由（结构检查，不是听感）；释放 L2 后 helper 释放。
  - L3 walk/run；受击反应 0；两击恢复 cover 0、恢复后恢复；**重组普通等待碎石 0**、教学重组 1、第一次真伤 1、第二次真伤 1、末次 lethal 0（共 3 次，不重复）；末次不重组；最终入城 0 脚步。少量 setup：`debug_setup_*`、直接 `receive_player_hit`、位置瞬移、L2 释放后直接实例化 L3（非完整正常路线），已注明。
- **正常视口连续帧**：`capture_footstep_alignment.tscn` 在**非 headless 窗口**（640×360 视口）用真实 L1/相机/player + 测试状态 overlay 捕获 3 帧 walk 接触 + 3 帧 run 接触：
  - `tests/audio_movement_20261117/screenshots/walk_contact_0..2.png`：overlay 显示 `walk frame 5 / step #1 / variant 0 / -18 dB / pitch 1.00 / voices 1/2`。
  - `run_contact_0..2.png`：`run frame 1 / step #2 / variant 1 / -15 dB / pitch 1.05 / voices 1/2`。
  - `capture_manifest_20261117.json` 记录 step tick、capture tick、anim/frame/marker、variant、volume、pitch、plays、player state/frame/x/on_floor；实际打开图片核对。**不是听审**；只是“真实落脚帧与音事件/银行状态对齐”的画面证据。capture 无 ScriptError/无警告。
- Checker `audio_movement_20261117.py`：**OVERALL OK**，工程阶段1453 基线 = 1448 未变 / 5 授权改 / 48 新增 / 0 缺失；before 未动，无 Git 写操作。试听页在 previews（Git 忽略），本轮落脚截图在 tests/audio_movement_20261117/screenshots（不在 previews），runtime 证据副本在 assets。

### 6.3 未完成 / 待听审

- **脚步 6 变体、重组 A、重组 B 全部未人耳听审**；音量、pitch、轮换节奏、A/B 语义关联都只是实现/机器测量。A 是默认，B 仅试听页；不能称 A 听感优于 B。
- **Q 仍阻塞**：参考画面已核但音轨未听辨，未制作新 Q；当前 Q 仍是用户不满意版本。
- **BGM 未接**；本页不含 BGM，无新音乐系统。
- B 的实际解码长度 0.456 s 与研究记录 0.558 s 不一致，已保留两值并以实际解码为准；没有做时间拉伸去凑 0.558。
- 走起步首帧 0 仍不播（技术准备阶段的防切换重音策略保留）；稳态 walk0/5、run1/6 每循环两次。若创作者要起步落一脚，需在后续 bank 试听阶段再调，不在本轮擅自改。
- 本轮未跑旧 214/全项目 suite；只在 `tests/audio_movement_20261117/` 保存新日志。L2/L3 的完整正常路线不是本集成测试的全流程，部分用 setup；没有把 setup 画面当玩家正常路径。

## 7. 协调独立复核与交付边界

- 独立正式绑定专项完整跑到`MOVEMENT_INTEGRATION_SUMMARY pass=63 fail=0`、退出0，无ScriptError/无警告。日志`tests/audio_movement_20261117/coordinator_integration_complete_20261117.log`。覆盖真开始菜单→intro→走跑/跳→L1完成按钮进L2、L2真墙推/暂停/Master路由、L3受击恢复/普通与真伤各一次重组/末次不组/城内完成静音；后段setup边界仍按第6节，不称人工全关。
- **首跑更正**：协调首次误加`--quit-after 3600`，该参数按process帧而非物理帧计，正常headless在C段前退出0，没有summary，`coordinator_integration_20261117.log`仅为中止记录，不算63通过。随后去掉该参数，仅用shell超时保护完整跑一次；不是为“洗过”改断言。测试本身固定写`run_integration_20261117.log`，完整复跑重生成了这份本轮报告日志；工程原始console日志仍保留，独立完整console另存，不覆旧轮次tests/logs。
- 独立读8条WAV：6步44.1k mono PCM16、0.3171–0.3719s/峰值-9dBFS；A/B各0.6000s/峰值-6dBFS；全部首末0、削波0、SHA与manifest一致。pauliuw同路径本地soundfile实际21888/48000=0.456s，研究0.558保留为冲突记录、不抹旧值。
- 独立1453项局部保护：1448不变/5授权修改/50新增/0缺失，OVERALL OK。共享player、守卫/门墙/复活物理、DemoAudio/Qspec、旧音/音乐未被本轮替换；Git索引为空，无Agent暂存/提交/推送。
- 已审helper与三关diff、重组仅路径换A、源/许可与派生清单；试听HTML的12个本地媒体链接均存在，静态检查无缺失。已打开全部6张正常视口落脚图及manifest：画面walk5/run1与单次事件一致。**这些只是落脚附近的相邻渲染帧，0/1有同一physics tick，不是完整走跑周期动画或实机音画录屏，不作为完整连续动画或听感验收。**
- **交付**：三关石地脚步与重组A可试玩，B仅对比；`previews/audio_movement_20261117/audition.html`可双击，前段Outland按钮定位205.5–213.0s。Q仍不满意且因参考声音未听辨暂停，BGM按用户要求不接；素材合法性来源核查不替代听审/全工程公开许可。
- 下一步创作者试听走/跑音量与重组A/B，并听参考片段能否辨清切换起音/尾音；在得到真实听感或明确的新方向授权之前，不再凭画面/频谱制作第三版Q。
