# 二三关衔接 · 主角受击 · 音频试听：实施与验收报告（2026-11-16）

**最终协调结论**：运行衔接/受击可交继续试玩；159功能关键检查独立通过，受击shader正常态重复乘纹理已另修并独立实渲差0。音频已补齐至12条候选+6旧副本与试听页，但未接入/未听审。1371保护因5个旧测试日志被重写仍FAIL，不作全量通过结论。最新实际核验与证据更正见`FLOW_HURT_AUDIO_REVIEW_20261116.md`“协调最终核验与交付”，以下实施阶段记录保留。

状态：**A/B 已实现并通过本轮新建关键检查；C 仅技术检查，未接入、未听审。** 未实现未批准的“全屏渐暗/重生过场”。未提交、未推送。

## 1. 根因与改动

### A. L2 → L3

- 根因：`Level02HUD` 完成页只有主按钮“返回主界面”+“重玩本关”，主脚本无 next 信号；`LevelFlow` 只有 01/02 路径。
- 改动：
  - `scripts/level_02_hud.gd`：完成页按 L1 已批准样式改为“进入第三关”（STONE，110,86,180,28）主按钮 + “重玩本关”(32,126) / “返回主界面”(208,126) 并排 OPTION；新增 `next_level_requested`；Tab/上下焦点环、Enter/Space、提示“Enter 进入第三关 · R 重玩 · Esc 暂停”；三个按钮统一禁用/释放焦点。
  - `scripts/level_02.gd`：新增 `_next_level_started` 一次接受/防双点；主按钮处理只在校验 `_completed` 后清输入、关闭暂停态并调用 `LevelFlow.start_level_03`；重玩/返回保持原路径；重玩后重新启用完成页按钮。
  - `scripts/ui/level_flow.gd`：最小新增 `LEVEL_03_PATH` / `start_level_03`，原 01/02 方法未改。
  - `scripts/level_03.gd`：入口释放一次性动作并用既有 3 tick 输入保护，防止完成页的 Space/Enter 在 L3 第一帧变成跳跃。
- 结果：真 `change_scene_to_file` 到 `level_03.tscn`，出生 (40,320)、核心/装置/守卫初态、A/D 可动，确认键不携带。

### B. 主角受击（仅 L3 本地层）

- 根因：
  1. 原受击仅 `modulate(1,0.62,0.55)`，是对原像素做乘法，深色衣服/暗像素几乎看不出色相变化；不是“没有受击”而是可见性不足。
  2. 引力环把守卫 `_facing` 当远离方向；玩家在守卫背后时会被朝错误一侧推。
  3. `level_03._on_guard_player_struck` 第二击同帧 `_retry_combat()`，`reset_to_spawn` 立即清掉 0.15s 反应/红/速度，第二击的受击表现被擦掉。
  4. 暂停曾无条件 `_clear_retry_pending()`：第二击已判定失败后，玩家在 0.15s 窗口 Esc 再恢复即可取消该次必定的当前战斗恢复（hits=2 继续打）。已改为暂停保留已判定 pending（计时被 tree.paused 冻结），只清红/反应/速度；恢复时先执行一次既有 `_retry_combat`。R/返回/重玩仍各自覆盖并清 pending，不重复 retry。
  5. 从 L2 完成页按 Space 时，按键仍处于同一次输入分发中，`LevelFlow` 的释放发生在 L3 第一帧之前不够早，跳跃会被锁存。
- 改动：
  - 新增 `scripts/level03/l3_player_hurt.gdshader`：只作用于角色 `CharacterSprite`，保留原纹理/亮度细节与 alpha，命中时清晰变红，0.15s 末尾 0.05s 淡回；不染护符/相性标/光晕/敌人/HUD/全屏。
  - `scripts/level03/l3_player.gd`：L3 子类安装本地材质；`receive_enemy_strike` 在入口按守卫实际位置修正远离方向（环背后也正确）；设置/推进红色计时；新增 `clear_hit_feedback()` 供暂停/电影/切场/完成/重置清理；`reset_to_spawn`、`lock_completion_input`、`lock_for_cinematic` 清红；不改共享 `player.gd`、实验玩家、守卫、音频、城门墙。
  - `scripts/level_03.gd`：把 `_guard` 作为只读取位置来源传给玩家；第二击改为 `_retry_pending`：先保留已有 0.15s 反应（取玩家当前剩余反应时间），pending 期间不接受第三击，随后执行原 `_retry_combat`，无额外复活停顿；暂停保留已判定 pending（只清红/速度），恢复时必执行一次 `_retry_combat`；R/返回/电影/失败恢复/完成/返回切场按各自路径清 pending 与红/速度/短锁。
- 保留：160 px/s 水平真实速度、0.15s 反应、0.6s 保护、真实碰撞、两击重打、前段进度/已看教学；未新增上抛、alpha 消失、闪烁或传送。

### C. 音频

- `previews/audio_review_20261116/` **未重做、未覆盖**，只做只读技术检查（见第 4 节）。`assets/level03_prototype/*.ogg`、`l3_audio.gd`、runtime 音频均未改。

## 2. 改动文件

- `scripts/level_02.gd`
- `scripts/level_02_hud.gd`
- `scripts/ui/level_flow.gd`
- `scripts/level_03.gd`
- `scripts/level03/l3_player.gd`
- 新增 `scripts/level03/l3_player_hurt.gdshader`
- 新增 `tests/level03/test_flow_hurt_20261116.gd` / `.tscn`
- 新增 `tests/level03/capture_flow_hurt_20261116.gd` / `.tscn`
- 新增 `screenshots/flow_hurt_audio_20261116/`（截图、按真实时间采样的受击帧、GIF、接触表、像素检查、生成脚本）
- 新增本报告 `docs/FLOW_HURT_AUDIO_REPORT_20261116.md`

## 3. 参考与边界

- 协调者已实际联网核看 Terraria 连续 399.0–400.1s：Mojo 25→11、14 伤害、向左退、短暂变暗闪烁后恢复；证据 `previews/player_hurt_20261116/refs/terraria_hit_399-400.1_contact.png` / 同名 GIF。
- 本实现只借鉴“受击当刻明确位移 + 短反馈 + 保护期不连推”，未复制人物/音效/血液/伤害数字。**纯红来自用户明确要求**，不声称录像确认了纯红闪光。未复制第三方像素/声音。

## 4. 实际测试与证据

### 4.1 功能（headless，全部实跑）

| 测试 | 结果 |
| --- | --- |
| 新增 `tests/level03/test_flow_hurt_20261116.tscn` | **159/159 PASS** |
| `tests/level03/test_level03_revision.tscn`（L3 原 194 检查） | **194/194 PASS** |
| `tests/level03/test_l3_demo_finish.tscn`（感谢页 47 检查） | **47/47 PASS** |
| `tests/test_level_02_input.tscn`（L2 输入 21 检查） | **21/21 PASS** |

新检查覆盖：
- L2 完成页三按钮文本/样式/位置/Tab/上下焦点/提示；真实鼠标“重玩本关”回 (36,320) 且 stage=0；真实鼠标“返回主界面”到真 Level01 标题。
- 真实鼠标、真实 Enter、真实 Space 三条路径进入真 `Level03`：单一 L3 实例、(40,320)、地面、idle、辉相、守卫 ACTIVE、装置初态、无红、无攻击、无跳、无 R、无 E；真实 D/A 可动。
- 红/位移/保护的正面证据全部来自守卫真实普通下砸或真实环释放；保护期边界只调用守卫自身 `_resolve_normal_strike()` 复核其 PROTECTED 门，不直接调用玩家 receive，也不直接改 modulate。
- 真实守卫普通下砸：红 tint=1.0、反应 0.150、保护 0.600、速度 -160、方向 -1；位移 2020→2006/1990（非传送）；按住 D 仍向左；保护期内守卫自身 `_resolve_normal_strike` 返回 `PROTECTED`，不计击、不重入红；反应结束红=0、保护仍在；A/Q/J 恢复。
- 右侧命中方向 +1、位移向右；空中（y≈306，未着地）环命中红/左退；守卫背后环释放仍按守卫位置修正为 +1、向右退。
- 两击：第二击后 `pending=true`、hits=2、tint=1.0、x 未传送；pending 内第三信号被拒；约 0.15s 后原 retry 执行，hits=0、回 ARENA_SPAWN、红/速度清零、stage≥3、已看教学保留。
- 暂停集成：第一击后暂停/恢复仍 hits=1、不重打；第二击 pending 时暂停→恢复确实执行一次当前战斗恢复（hits=0、回恢复点、守卫重置、stage/已看教学保持）；暂停中 R 覆盖 pending 回开场且不重复 retry；暂停中“返回”到真 Level01、不残留 retry。
- 电影锁与完成锁清红/反应/速度（完成页本体由 47 检查覆盖）。

### 4.2 画面证据（正常 640×360 实机视口）

目录：`screenshots/flow_hurt_audio_20261116/`

> 该目录在中断会话中已有 18:17 的旧记录（`f01...`、`h1_/h2_...`、`frames/`、
> `MANIFEST_FLOW_HURT.txt`）。本轮没有覆盖它们，也没有采用为证据；本轮开始时正式
> 源码里并无本地受击 shader / L2 三按钮，故旧 manifest 的“shipped”描述不代表当前
> 构建。分界说明见同目录 `EVIDENCE_NOTE_20261116_1912.md`。

本轮文件：

- `a01_l2_completion_three_buttons.png`：三按钮完成页（已人工查看，L1 样式一致）。
- `a02_l3_arrival_from_l2.png`：真实鼠标从 L2 完成页进入 L3 后的开场画面，(40,320)。
- `a03_l3_real_move_right.png`：过渡后真实 D 移动（x 40.0→62.5）。
- `b01_arena_before_hit.png`：受击前基线。
- `hurt_frames/h00_000ms.png` … `h15_300ms.png`：真实守卫下砸后按 manifest 真实时间采样的 16 帧（部分步骤跳 1 帧，不是无间断 16.7ms 序列）。
- `hurt_sequence_16f.gif`、`hurt_sequence_contact.png`：由上述原始帧生成，未改画；GIF 每帧 50ms 仅为放慢观看，真实时间/帧间隔以 `MANIFEST.txt` 的 `sim_ms/physics_frame` 为准。
- `MANIFEST.txt`：每帧 `sim_ms / physics_frame / x / y / vx / vy / tint / reaction / protection / hits / guard state`。
- `pixel_check.txt`：整幅 640×360 红色主导像素统计（基线 280 → 命中 393，+113；平均红色余量 113.6→136.0）；只作客观辅助，不替代看图。

已人工查看 `h00`（tint=1.0，身体明显红、纹理/轮廓保留）、`h05`（tint=1.00，100ms 仍全红）、`h06`（tint=0.67，117ms 开始淡出）、`h07`（150ms tint=0 恢复正常），并确认 x 由 2020→1990.2 的左侧位移。**这是对本轮截图的查看，不是对 Terraria 录像的二次引用。**

### 4.3 旧测试（未改，报告具体不兼容）

未修改任何旧测试断言，也未扩 checker。本轮修复只复跑新增专项与感谢页 47，没有再跑旧 L2 suite；以下是此前一轮的记录，缺口保留：

- `tests/test_level_flow_rebuild.gd`：8/10。前 6 项（L1 真换场到 L2、L2 出生/未暂停）仍 PASS；2 个失败都只因新的三按钮要求：①“L2 completion primary is 返回主界面”；②用旧 primary 追“返回主界面 → Level01”（现在 primary 是进入第三关）。最小兼容建议：该测试改取 `get_completion_return_button()` 作返回路径，并把主按钮断言改为“进入第三关”。
- `tests/test_level_flow_pause.gd`：86/6。除三按钮相关 4 条外，还有：
  - `level-02 completion page is visible after the real completion path` 也失败。探针确认：该旧 setup 只锁 TargetBay，当前 L2 的 `is_exit_gate_ready()` 还需要联动记录/符石，`link=false`（非本次改动路径）。最小兼容建议：与新增测试相同，用 `debug_restore_stage(2,false)` + 最终仓入仓，再点 `get_completion_return_button()`。
  - 第 6 条为旧的“completed instance freed”随首次进入失败而级联。
- `tests/test_level_02_route.gd`：19/24。首个失败是“real rune lift lands the player on the 80 px sill”，之后 final 仓/完成级联；该段 L2 路线代码本轮未改，属既存路线/时序问题。最后一个旧断言“completion offers return to title”同样与三按钮新要求冲突。
- `tests/test_level_02.gd`（广测）：149/47。首批失败为不存在的旧节点名、旧平台图层字节哈希、旧“目标仓”文案等，说明该测试早于 L2 重建，属既存陈旧用例，未用于本轮验收。
- 以上旧测试未改；请协调者决定是否批准上述最小兼容修改。

### 4.4 1371 保护检查

`D:/minic/envs/2024212971/python.exe .openchamber/verification/flow_hurt_audio_20261116.py`

- 5 个授权脚本 CHANGED OK。
- 新增 shader、2 组测试脚本/场景 ADDED OK。
- **OVERALL FAIL**，仅因 5 个测试输出日志被旧测试自身 `FileAccess.open(..., WRITE)` 重写：
  - `tests/logs/level02_rebuild_input.log`（`test_level_02_input`）
  - `tests/logs/level02_rebuild_route.log`（`test_level_02_route`）
  - `tests/logs/level02_textured_test.log`（`test_level_02` 广测）
  - `tests/logs/level_flow_pause_critical.log`（`test_level_flow_pause`）
  - `tests/logs/level_flow_rebuild.log`（`test_level_flow_rebuild`）
- 这些不是源码/批准资产；已扫描仓内、`星核旅人.zip`、临时目录，均未找到旧副本；旧 before 仅有哈希，无法还原原字节。未改 before JSON、未扩 checker，等待协调者决定“重新基线化日志产物”或提供旧副本。除此之外 1361 个文件未变、MISSING 0。

## 5. 音频技术检查（read-only，不等于听审）

- 候选 10 条 + 串烧：全部 44.1 kHz / 16-bit PCM / 单声道；时长 0.16–1.25s（串烧 8.60s）；峰值 −3.00 dBFS；削波采样 0；DC 偏移最大 0.00267。
- 现有 6 条副本与 `assets/level03_prototype/*.ogg` **字节一致**（sha256）。
- `audition.html`：17,464 字节；引用 6 条现有 + 10 条候选 + 串烧；相对路径；无 `autoplay` 属性；含“现有/候选/未批准/未接入”中文说明；`manifest.json` / `manifest.md` / `README.md` 齐全。
- **未做**：本轮未重新听审、未在浏览器逐条播放、不做音色可用性结论；未改 `l3_audio.gd`、未接入 runtime。

## 6. 启动与运行

- 实机：Godot 打开 `基础场景原型`，F6 运行 `res://scenes/level_02.tscn`，完成第二关后点“进入第三关”；或直接 F6 `res://scenes/level_03.tscn`。
- 新功能检查：
  `D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/level03/test_flow_hurt_20261116.tscn`
- 截图重跑：
  `D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . res://tests/level03/capture_flow_hurt_20261116.tscn`
- 证据生成：
  `D:/minic/envs/2024212971/python.exe screenshots/flow_hurt_audio_20261116/build_flow_hurt_evidence.py`

## 7. 未验证 / 待协调

- 未做人耳音乐/音效听审，音频未接入。
- 未重新走完整 L2 从起点到出口的人手路线；完成页、重玩、返回、L2→L3 均用“恢复点 + 最终仓”setup 覆盖，报告中不冒充全路线。
- L2→L3 只处理了按下后的 3 tick 输入保护；若玩家把确认键持续按住超过系统重复延迟（约 0.5s），OS 重复按键的跳跃不在本轮断言内（未观察到，但未做长按实测）。
- L3 受击只在 640×360 正常视口取证；2× 窗口缩放和其他分辨率未单独截图。
- 旧测试兼容修改与 5 个日志产物的 1371 检查处理需协调者决定。
- 未实现“重生变暗再复活”过场（仅提案，未批准）。

## 8. 材质双重采样修复补记（协调复核后）

- 根因（协调 `docs/FLOW_HURT_AUDIO_REVIEW_20261116.md` 已核，官方 canvas_item 文档同义）：fragment 输入的 `COLOR` 已是 vertex 颜色（含 modulate/self_modulate）× 默认 `TEXTURE`；旧 shader 又 `base=COLOR` 后乘一次 `tex`，`hit_amount=0` 时纹理/alpha 被平方，正常人物变暗。
- 修复：`scripts/level03/l3_player_hurt.gdshader` 在 `vertex()` 用 varying 保存 vertex `COLOR`；fragment 只采样一次 `TEXTURE`，混红后 `COLOR = vec4(rgb, tex.a) * vertex_color`。保留 modulate 语义、不除黑像素；受击仍按亮度保纹理/轮廓，alpha 不变。
- 正常材质同帧实渲（非 headless 数值）：
  - 修复前协调 probe：`NEUTRAL_SHADER_RENDER_DIFF pixels=404 tint=0.00`，exit 1；图 `screenshots/flow_hurt_audio_20261116/neutral_coordinator/`（保留不覆）。
  - 修复后同 probe（仅 DIR 改为 after）：`NEUTRAL_SHADER_RENDER_DIFF pixels=0 tint=0.00`，exit 0；图 `screenshots/flow_hurt_audio_20261116/neutral_coordinator_after_20261116/`。PIL 独立复核 640×360 RGBA 逐像素 changed=0、max_abs=0。
- 修复后受击实机图/GIF（新目录、`c` 前缀，不覆旧 b/h）：
  - `screenshots/flow_hurt_audio_20261116_after_shader/c01_arena_before_hit.png`
  - `c_hurt/c00…c15`、`c_hurt_sequence_16f.gif`、`c_hurt_sequence_contact.png`、`c_pixel_check.txt`、`MANIFEST.txt`
  - 新图命中 tint=1.00、150ms 恢复 tint=0；正常基线不再偏暗。旧 `b01…/hurt_frames/h*` 已在原目录 `MANIFEST.txt` 和 `EVIDENCE_NOTE` 标“修 shader 前”。
- 专项复跑：`test_flow_hurt_20261116` **159/159 PASS**；47 感谢页沿用已通过日志，不重跑；未跑任何旧广测。
- 1371 保护不变：仍仅 5 个旧测试日志产物 FAIL，无新增越权；未重基线、未改 checker。
- 本轮仅改 shader、该专项取证/记录和新截图目录；runtime 其他脚本、音频、旧测试未动。
