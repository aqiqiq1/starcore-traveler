# 音效第二版：三关接线与试听阶段最终报告（2026-11-17）

> **最终状态：12 条 SFX 已试装接线（9 条旧候选 + Q/J/大石壳碎裂 3 条新 CC0 派生）；2 首 BGM 仅本地试听副本、未接 runtime。全部未人耳听审，未做混音/正式音频验收。** 本轮没有新音乐系统、没有新总线、没有改共享玩家/守卫/门/电影/地图/玩法。

## 1. 实现与文件

### 1.1 DemoAudio（仍是同一接口、同一池）

- `scripts/audio/demo_audio.gd`：事件从 9 条扩到 **12 条**；Q/J/碎裂不再保留空接口，已转成真实文件与 spec，旧的 reserved 占位方法/计次/警告已删除。
- 保持原结构：只用 Master 总线；世界 6 声部 `PROCESS_MODE_PAUSABLE` + UI 4 声部 `PROCESS_MODE_ALWAYS`；池满复用轮转槽位；惰性加载；`_exit_tree` 停世界声、UI 可收尾。
- 新增 3 条 spec（运行时音量）：
  - `polarity_switch` → `polarity_switch_v2.wav`，-6 dB
  - `swing` → `swing_v2.wav`，-6 dB
  - `shell_shatter` → `shell_shatter_heavy_v2.wav`，-3 dB
- 原 9 条 spec、文件名、音量均未改。

### 1.2 三条新音的来源与派生（机器测量，不是听感）

源与证据：`docs/AUDIO_DEMO_V2_SOURCE_APPROVAL_20261116.md`；生成脚本 `previews/audio_demo_v2_20261116/generate_new3.py`；参数/源 SHA/新 SHA/CC0 说明/证据副本在 `assets/audio_demo_v2_20261116/NEW3_DERIVATION.json` 与 `source_evidence/`。

| 事件 | 输出 | 源 | 处理 | 结果 |
| --- | --- | --- | --- | --- |
| Q | `polarity_switch_v2.wav` | PWL `bell_ding1.wav`（CC0）+ Bobjt `gem-gather-stereo.wav`（CC0） | 首个清楚起音（0.0345s）前 4.5ms 起裁 0.52s、尾 55ms 淡出；gem 在起音后 40ms、相对主铃 -12 dB；单声道 | 0.520s / -6.0 dBFS 峰值 / RMS -31.7 dBFS；无旧反向滑音 |
| J | `swing_v2.wav` | artisticdude `swishes/swishes/swish-9.wav`（CC0） | 保留原 0.197s 空挥；单声道、首 2ms/尾 8ms 淡化 | 0.197s / -6.0 dBFS / RMS -21.0 dBFS；无金属撞击层 |
| 大碎裂 | `shell_shatter_heavy_v2.wav` | Spring Spring（Julie Damsgaard）`break_stone.wav`（CC0）+ Kenney `impactMining_000`（CC0） | break_stone 96k→44.1k 多相重采样，24Hz 高通，保留 1.12s 首段与碎块尾、120ms 软收尾；Kenney 首击取 0.22s、低通 1.2k、相对峰值 -9 dB；最终归一到 -3.0 dBFS | 1.120s / -3.0 dBFS / RMS -20.9 dBFS；未加长爆炸/长混响 |

- 三条均为 mono 16-bit PCM 44.1 kHz WAV，首/末采样 0，峰值未触顶；旧 12 候选、旧 6 OGG、研究源目录均未覆盖。旧 Q/J/碎裂候选只在 `previews/audio_demo_v2_20261116/old/` 作只读 A/B 副本，不接 runtime。
- 运行时使用 Godot 默认 WAV 导入（一次性、不循环；本项目默认 QOA 压缩）。试听页播放的是原始 PCM WAV，因此页面听感与游戏内导入流可能有细微压缩差异，A/B 时以同一页面的旧/新文件为准。
- 证据副本：4 张源页截图 + CC0 1.0 deed HTML + Kenney License 文本（`source_evidence/`，previews 被 Git 忽略故随 runtime 保存）。credits §16B 只追加这 3 条源/派生说明。

### 1.3 接线点（全部仍然是一次性真实事件）

- **Q（三关）**：只在玩家真实换相时响。用 `polarity_changed` + 玩家 `get_polarity_toggle_count()` 判定：真实 Q 计数器递增；初始 spawn/重开/恢复把计数器归 0，脚本 `set_polarity_state` 只发信号不递增，因此都不响；暂停/输入锁/电影/恢复中 Q 被原逻辑拒绝，不发信号。
- **J（仅 L3）**：`L3Player.attack_started`（`request_attack()` 成功才 emit）；冷却、已有挥击、完成锁、暂停、恢复/电影内均不响。
- **碎裂（仅 L3）**：`guard.shattered` 一次一条；`true_damage_dealt` 不接音，避免同击双播。普通碎裂、引力扣格、末次不重组都保持原状态机（未改 guard）。
- 原 9 条接点不变：UI、E 取/入仓（所有 bay）、`field_committed`、accepted 受击、`insert_started`、完成、L3 `_begin_recovery`、L3 fade-in 起点；L1/L2 只保留 respawn、不叠 failure（协调已接受）；L1 无 BayRuneLink，不硬加 link（已接受）。

### 1.4 试听页

- `previews/audio_demo_v2_20261116/audition.html`：沿用旧试听页的暗色/金色样式；包含 3 项旧/新直接对比（旧波形只读复制在 `old/`）、其余 9 条已接音量表、2 首 BGM 完整本地副本（`bgm/`）。
- 相对路径、双击离线打开；不自动播放；任一播放会暂停其他；BGM 默认音量 0.25；有“停止全部”。17 个 `src` 路径已逐一核对存在。
- 页面明确写：BGM 仅试听、不接 runtime；不声称无缝（能量接近不等于无缝）；不声称无人声已验；全部未听审。

## 2. 实际测试

- `tests/audio_demo_v2_20261116/test_audio_demo_v2_20261116.gd` 在旧 suite 上扩充一次运行（没有多帧率重复、未跑旧 suite、未写 `tests/logs`）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  res://tests/audio_demo_v2_20261116/test_audio_demo_v2_20261116.tscn --fixed-fps 60
```

- 结果：**214 项通过 / 0 失败，退出码 0**；日志 `tests/audio_demo_v2_20261116/run_audio_demo_v2_20261117.log`（脚本自写）与 `.console.log`。测试中**无 ScriptError、无游戏逻辑异常**。**不能把退出时的 74 ObjectDB warning 全部归因于既有现象**；见 §2.1 的定向归因结果。
- **§2.1 泄漏定向 probe（不是全套重跑）**：新增极短 `tests/audio_demo_v2_20261116/probe_leaks.tscn/.gd`，同一命令重复运行：
  - `--headless` Dummy，不播放：**0**；DemoAudio 单条：**0 / 2 / 0**（三次）；6 条：**0 / 7 / 0**（三次）；10 条：**0 / 11**（两次）；30 条：**0**（两次）。
  - 同样 `one / six / ten` 改用正常 WASAPI 后端（非 headless）：**全部 0**。
  - 只实例化 L3 + 加载/释放旧 bank、不播放：**0**；旧 bank 播放 `charge`/`slam` 后释放并 free：**0**（四次）；L3 setup 节点本身：**0**。
  - 测试末尾核对：`_clear_levels()` 对仍在场的 L3 会调用旧 `l3_audio.release_streams()`；第 H 节手动 `queue_free()` 的那台 L3 没有补调旧 bank release，但上面的旧 bank 播放/释放 probe 为 0，**没有证据表明旧 bank 会让 74 倍增**。`DemoAudio.release_streams()` 会 stop 全部池、清 `_streams` 并置空 `player.stream`；服务节点本身保留到进程退出（autoload 正常生命周期）。
  - 出现残留时，对象只有 `AudioStreamPlaybackWAV`（每个在飞声部一个）和一个共享 `AudioStreamWAV`（引用计数=在飞声部数）；未看到 `DemoAudio` 服务节点、`AudioStreamPlayer` 节点或旧 bank 被确定性持有。`DemoAudio.release_streams()` 已 stop 全部池并清 `_streams`/`player.stream`。
  - 结论边界：这符合 **headless Dummy 后端在退出前没有回收在飞 playback** 的时序残留；计数随运行变化，不是“每播一条必然漏”。正常 WASAPI 探针为 0。**74 的逐对象构成没有用全套 verbose 复核**（按要求不再跑全套），不排除其中混有旧 bank/UI/测试 harness 的同类待回收 playback；`l3_audio`/guard 未改、未做长诊断。测试末尾若需要干净 Dummy 退出，可后续在 `release_streams` 后 stop→等待→再 stop/release，本次没有为追 warning 改产品/共享系统。
- **Q 三关**：L1 初始 0、真实 Q +1、R 重开 0、真实坠落 0；L2 初始 0、Q +1/+2、坠落 0；L3 新关初始 0、Q +1、R 0、恢复 cover 内 Q/J 均 0、恢复脚本相性 0、恢复后 Q +1。
- **J**：真实 J 恰好 1 声；同一挥击/冷却内第二次 J 0；暂停中 J 0；恢复 cover 内 J 0。
- **碎裂**：普通真实 J 碎裂 = 1 声且不扣格；引力真伤 = 1 声（不与 true_damage 双播，扣 1 格）；第二次真伤 = 1 声；第三次/末次 lethal = 1 声，死亡不再补第二条；三次格数 0/1/2/3 与原逻辑一致，末次不重组。
- **原 9 条关键保留**：UI 禁用/启用与真实 Button/PixelMenuButton 不双播；L2 真实 E 取 3/入仓 3/link 1/complete 1 并真实进 L3；L3 accepted 受击/保护拒绝、failure 在恢复入口、respawn 在 fade-in 起点、gate 在 insert_started、暂停世界冻结/UI 可响、Master 0% mute、切场世界池 0、关卡释放世界池 0、池上界 6/4。
- **旧验收的替换说明**：上一版 156 项中的“Q 不响（reserved）”和“无 reserved 占位”断言已按用户本轮授权替换为“Q 真实触发 1 次、初始/重置/恢复 0 次”和“三条已是真实文件、无占位机制”；不是删除验收。
- Checker：`.openchamber/verification/audio_demo_v2_20261116.py` 现为 **OVERALL OK**（协调已把 `scripts/start_menu.gd` 路径改对；before 未改）。旧 12/旧 6/研究源/贴图/守卫/电影/门/地图未改；无 Git 写操作。

## 3. 启动

- 游戏：Godot 4.7.2 打开 `基础场景原型/project.godot`，运行 `scenes/level_01.tscn`。
- 测试：见 §2 命令。
- 试听：双击 `previews/audio_demo_v2_20261116/audition.html`。

## 4. 待听审 / 待定

1. **全部 12 条与 2 首 BGM 均未人耳听审**；本轮只做了来源许可核对、文件/时长/峰值/无削波/派生参数与事件计数。Q/J/碎裂是否“清亮/锋利/更重”仍需创作者亲耳判断。
2. **BGM 未选定**：首选 `forest_2`（2:16.97，pads/bells 描述）、备选 `Contemplation`（2:00.06）；仅试听页本地副本。不声称能量接近即无缝，不声称无人声已验，未接 runtime。
3. `gate_rise.wav` 1.10s 与门板 0.14+1.0=1.14s 的 0.04s 差未做时间伸缩，门动画未改。
4. 本轮未跑全项目旧 suite；只跑新增的 214 项。
5. L1/L2 failure 未接、L1 link 不硬加：按协调接受的现状保留。

## 协调独立关键复核（2026-11-17）

- 独立新专项`AUDIO_DEMO_V2_SUMMARY pass=214 fail=0`/退出0，无ScriptError，日志`tests/audio_demo_v2_20261116/coordinator_20261117.log`。以真实键鼠/游戏信号的计数与播放器状态验证；部分战斗后两格是明确setup判定，不冒充人工全关或声音设备听审。
- 独立1402项局部保护：1395不变/7授权修改/50授权新增/0缺失，OVERALL OK；7个修改为project/credits/三关接线/StartMenu/PixelMenuButton。checker原StartMenu路径笔误已据实际路径纠正，不改before；旧各轮日志证据缺口不由新局部基线洗绿。
- 独立读取3新WAV：44.1k/单声道，0.520/0.197/1.120s，峰值-6/-6/-3dBFS，削波0，哈希逐一匹配派生清单；其余9运行WAV与旧已批准试装候选9/9逐字节一致。源码未引用preview作为运行音源；新源许可/派生证明随运行目录保留。
- 协调已实际看作者页截图/源清单，并以浏览器重开Spring Spring原页核CC0与break_stone文件；HTTP403访问失败不当成功证据。来源说明/机器指标不是听感合格结论；音乐首尾电平接近不证明无缝。
- 独立214退出同样有**74个ObjectDB实例警告**。已要求定向probe，工程报告WASAPI新bank短探针0残留，Dummy重复时残留不稳定且对象是播放中的AudioStreamPlaybackWAV/共享流；未复跑全套verbose，**74逐对象构成仍未完整归因**。不拿旧单cue4例断言74全是既存，也不据此声称实机必有持久泄漏。probe记录见下文/新测试目录，未因此改旧系统。
- Git索引仍为空，无暂存/提交/拉取/变基/推送。可直接F6正式level_01开始试声音；试听页已在文件面板打开，可双击本地HTML（不需常驻服务器）。Github完整操作指南`docs/AUDIO_DEMO_V2_GITHUB_STEPS_20261116.md`；BGM两首仅候选未接，主角/Golem许可待核仍是公开分发边界。
