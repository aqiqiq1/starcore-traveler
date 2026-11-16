# 第三关首版可玩实现报告（断桥外郭）

2026-11-15 · 实现 Agent 交付记录。规格以 `docs/L3_PROTOTYPE_BRIEF_20261115.md` 为准；本报告只记录实际做了什么、实测到什么、哪些还没验。

## 1. 入口与范围

- 可玩场景：`scenes/level_03.tscn`（从出生到实际走入城内并结算，单场景完整循环）。
- F6：编辑器打开该场景按 F6；命令行：
  `D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/level_03.tscn`
- 未改正式 L1/L2、共享 player、原输入地图、力场/星核/仓规则、project.godot、菜单/F5 旧沙盒入口。所有 L3 逻辑在新目录/新继承类中；ASSET_CREDITS 只在本轮末尾追加第 15 节。
- 控制：A/D 移动，左Shift 奔跑，空格跳跃，Q 切玩家相，J 单次挥击，E 释放/存核/启动装置/取核/嵌核，R 整关重来，Esc 暂停。

## 2. 实际玩法与参数（可在新文件集中调）

### 空间

| 段 | 范围 / 高度 | 职责 |
| --- | --- | --- |
| 起点 + 运核 | x 0–560，地面 top 320 | 出生 40,320；起始仓 150、符石仓 330；远处城门剪影与目标提示 |
| 符石登高 | 台地 x 560–900，top 210；符石 (560,152) | 存核记录点亮符石；异相吸近、切同相落到台地 |
| 固定装置 | 装置 x 830，台地 top 210 | 自带无色核；E→紫色稳定态；启动浮地 |
| 浮地 | 5 块石 x 916/1042/1152/1246/1372；顶 222/248/218/242/222；尺寸 96×32 / 80×28 / 64×24 / 96×32 / 80×28 | 限时上升、可站、预警、下沉；下沉末尾撤碰撞落入虚空 |
| 安全缓冲 + 守卫前恢复点 | 缓冲 x 1482–1660，top 252；恢复点 1520,252 | 与浮地倒计时脱钩；失败不再跑运核/浮地 |
| 守卫场 | 阶梯 1660–1700 top 290；场地 1700–1960 top 320 | 单个 2x 守卫；观察/退让区 |
| 城门/城内 | 门 1960,320；城内 1960–2240，top 320 | 16px 守卫核嵌入 24px 孔；门开；x≥2070 且实际走入才结算 |

- 总宽 2240 px（不是旧 2304 建议；由以上职责段拼出）。相机 limit 0–2240 / 0–360。
- 恢复点：START 40,320；RUNE 430,320；DEVICE 800,210；ARENA 1520,252；守卫出生 1810,320。
- 浮地参数：升起 1.10 s，错峰 0.06 s；稳定总时长 20.0 s；最后 4.0 s 预警；下沉 2.20 s；静止石块 **无碰撞**（只是可见的谷底碎石，避免把谷底变成隐藏桥）。

### 运输核 / 符石 / 装置

- 100 px 运输场、仓的 E 语义、存核记录、脉冲、符石 request/commit、Q/E 全部复用正式组件；没改规则。
- L3 符石局部参数：range 210、inner 18、full 54、outer fade 30、full accel 2700；初始 inactive，由符石仓记录的核相性点亮。实测从 482 走近后被真实吸力抬到台地，Q 同相后落到 210。
- 固定装置不是仓：E 只把装置自带核从无色 inactive 换成紫色 active；近距 46 px；不读取/不消耗运输核。浮地运行时再按 E 只提示“仍在稳定”；回落/超时后 E 可重启。

### 守卫

- 现橙/青 Golem 素材，**2x Nearest**，脚底锚点（帧 90×64，offset -45,-64，scale 2）；新 `L3Guard` 只写 L3 规则，不改旧 enemy 脚本。
- 动作：0–3 起手一次（0.30 s）→ 只 4↔5 高举循环（2.20 s，0.16 s/帧）→ 6–10 完整下砸/收招（0.46 s；6–7 为 0.16 s 实接触窗，8–10 收招）→ 0.35 s 间隔。蓄力总 2.50 s。
- 头顶：64×6 蓄力条 + 三枚 4×4/5×5 菱形真伤标记；无第二条血条；守卫离屏时不绘制（修复了远处出现空面板的问题）。
- 场：蓄力期间 radius 190→150 逐步内收；inner 18、full 50、fade 30、accel 1650；异相吸、同相斥，作为房间唯一聚合点的一个 provider 施加到玩家；不关闭斥力。
- 真伤：三次；必须同时满足“真实蓄力易伤窗（≥0.30 s）+ 同相（按 J 起手快照）+ 真实近身命中（前向 2–58、垂直 ≤40、地形射线不挡）”。每挥击最多结算一次（房间 + 守卫双重 swing id 去重）。前两次真伤后守卫换相；第三次失活并掉 16px 核心。
- 普通阶段：石壳累计 2 次同相挥击破碎，立即 0.75 s 散架 + 0.60 s 重组（+0.40 s 间隔），**不计真伤、不清理已有真伤**；无旧 8 s 倒地等待；重组/失活期间不再判伤。
- 弱点：`weakpoint_corner_motion_v2` 64 帧、12.5 fps、72×72 画布/48×48 原图，挂点在 2x 守卫胸口（局部约 (4×facing,-34)），不随身体旋转；只在真实易伤时显示；金/青随锁定相。
- 掉落核心：16×16 v7；落点脚底上方 10 px；靠近 44 px 按 E 取，携带显示为 16px 12 帧；门孔 24px；近门 50 px E 嵌入；嵌入 0.70 s 后门开。
- 下砸真实威胁：前向 48、44×34 的拳区、0.16 s 实接触窗；命中走玩家已有击退/0.15 s 反应/0.6 s 保护；最后 0.55 s 有地面预警色块。

### 近门电影

- 触发：门仍锁、未演过、玩家 x≥1896 且 y 245–335（接近锁门时；不碰门自动结算）。
- 一次性：黑边 44 px、独立相机、短脚本走路到门、问号、听重组声/守卫蓄力、感叹号回头、镜头看守卫、回主角、s40 残响投影、3 页短对白；对白期间守卫计时/伤害、玩家移动/跳跃/Q/E/J 全部冻结。
- 已碎裂分支：不伪造倒地，播放真实散架/重组；已受真伤/已击败不清零、不复活；未碎裂显示真实蓄力。
- 输入：短按空格补全当前行/下一页；长按 0.6 s 跳过整段；恢复前等空格松开（同一按下不会触发跳跃）；恢复后守卫重新起一轮可反应蓄力。
- 清理：暂停（before_pause_opened / 暂停菜单）、失焦、R、返回菜单、结束、跳过统一清黑边/符号/投影/临时相机/输入接管；R 后可重播；普通死亡不重复教学。

## 3. 实测结果（真实引擎/真实输入）

测试入口在 `tests/level03/`；全部用 headless 运行，均自行 quit。本会话实际汇总：

| 测试 | 结果 | 覆盖 |
| --- | --- | --- |
| `test_level03_load.tscn` | **34/34 PASS** | 解析/载入、玩家落地、22 节点/资源尺寸、2x、胸位弱点、门/装置/浮地初始态、核心/仓初始态、HUD |
| `test_level03_route.tscn` | **33/33 PASS** | 真实 A/D/E/Q/空格：释放运输核→引导→入符石仓→脉冲点亮→真实吸力登台→Q 同相落地→E 启动装置→浮地上升→真实跳跃跨 5 块→缓冲恢复点；超时用缩短 5.0 s/1.4 s 的设置做真实下沉/坠落恢复，再恢复 20 s 重跑 |
| `test_level03_combat.tscn` | **73/73 PASS** | 2x/帧循环/弱点 v2/场收缩/同相斥·异相吸；真实“异相吸近→Q 同相→J”一次真伤；3 真伤换相/失活掉核；普通 2 击碎立即重组；同一 swing id 去重、背后挥空；6–10 下砸与单次接触、声画事件；取核→嵌 24px 孔→门开→门外贴门不结算→实际走入城内才结算 |
| `test_level03_cine.tscn` | **59/59 PASS** | 近门触发一次性、黑边/相机/走路/问号/感叹号/s40/打字机、短按补全+翻页、长按 0.6 s 跳过、等松开不跳、暂停清理、失焦清理、R 全清并重播、普通死亡不重播、已碎裂分支、已击败不复活 |

总计 **199 项 PASS，0 FAIL**（本轮只跑 L3 关键节点，未跑旧全量 suite）。

**Setup vs 真实行动（必须连同结果一起读）**

- 真实输入链：运核→存仓→符石登台、浮地跨块、真实 J 的第一发真伤、取核/嵌门/走入城内、电影触发与空格推进/跳过。
- 有限 setup：浮地超时把 `float_duration/warning_time` 临时改为 5.0/1.4 s；守卫下砸/3 真伤/石壳/同一挥击的因果用“被迫起蓄力 + 直接调用 receive_player_hit”的有限状态检查；电影截图用 arena setup；城门截图用 gate-with-key setup 并把电影标记为已演；截图里的守卫姿态是 forced charge。以上都在测试日志或截图 manifest 中写明，不冒充人工全程试玩。

**截图（引擎实机 640×360，`screenshots/level03_prototype_20261115/`）**

- `level03_00_start.png`：全程无 setup 的起点。
- `level03_01_rune_climb.png`：setup 符石阶段；真实走到台地边被抬起。
- `level03_02_float_route.png`：setup 装置阶段；真实 E 启动 + 跳上第一块。
- `level03_03_guard_weakpoint.png`：setup 守卫场 + forced charge + 同相摆位；2x 守卫、v2 弱点、v3 场、头顶条与 3 标记。
- `level03_04_gate_open_city.png`：setup 门/核/电影已演；真实 E 嵌核开门；可见 v2 门效与城内拱/光。
- `level03_05_city_complete.png`：真实走入城内后的第三关完成页。
- `level03_06_cine_bars.png`：setup 守卫场；真实走到锁门触发；黑边、s40 残响、第一页对白。

截图说明全文见同目录 `MANIFEST.txt`。

## 4. 素材与许可

- 运行副本只在 `assets/level03_prototype/`（27 个必需 PNG/OGG + `SOURCE_MANIFEST.json`，逐文件源路径/源与目标 SHA256/用途/许可）。运行时脚本与场景不引用 `previews/`（已 grep 为空）；没有复制 GIF/审图板/参考图。
- 核心/孔/门：v7 16px 核 / 24px 孔；核原形 Frakassets “Free Shiny Gem Round”, CC BY 4.0（保留署名/许可/派生记录）；门/核壳为项目内 AI 辅助/离线像素候选。固定装置 v4；弱点 v2（创作者已认可该运动）；场 v3；浮地、符号、城内样板为项目自制候选。
- 音频：charge v2 来自 jdagenet（Sci-Fi Drone Loop, OGA, **CC BY 3.0**，已修改，必须署名/链接/注明修改）；slam v5 为 CC0 源（qubodup/rubberduck/Kenney/StarNinjas）+ 项目合成；A/C/D 四条（重组/浮地/落座）为 **CC0 候选，临时试装**。
- 直接复用正式现文件：Golem 橙/青、s40 残响、v2 门效、L2 石地面、主角/星核/仓/符石/DS03。主角与 Golem 作者/许可仍未知，只能内部原型，不据此宣称可发行。
- 详细署名/修改/边界见 `ASSET_CREDITS.md` 第 15 节与 `assets/level03_prototype/SOURCE_MANIFEST.json`。

## 5. 保护基线（重要）

- 本轮开始时该文件存在：`C:/Users/aqiqiqi/AppData/Local/Temp/opencode/l3_prototype_before_20261115.json`（86,632 bytes）。本会话后段该文件在 Temp/opencode **已不存在**（`Get-ChildItem` 全盘 Temp 未找到同名文件）。**我没有删除或修改它**；原因未知（疑似临时目录清理/外部进程）。因此**没有声称 653 项 hash 检查通过**；若创作者/协调者能恢复该基线，应重跑一次。
- 作为独立可得证据：`git -c core.quotepath=false diff --name-only HEAD -- "星核旅人/基础场景原型"` 在本项目 **1,236 个 tracked 文件**中只有 **`ASSET_CREDITS.md`** 一项变化（即授权的末尾追加），其余全部是新增未跟踪文件。`previews/` 被项目 `.gitignore` 排除，git 无法覆盖其 hash；这正是 653 基线本应负责的部分，而该基线文件现在缺失。正式 L1/L2、共享 player、旧实验、project.godot、旧素材均无 tracked 修改。新增截图、`tests/level03`、`assets/level03_prototype` 都是本关新内容。
- 未提交、未推送、未删旧文件、未强关用户应用、未购买/上传/调用付费服务。

## 6. 未验 / 风险 / 需创作者判断

1. **没有人工连续试玩**。难度曲线、守卫 2.5 s 蓄力与 1650 场力的手感、20 s 浮地在真人压力下是否够、下砸/击退是否过重，均留给创作者判断；测试是脚本化/有限 setup。
2. **音频未听审**。charge v2 / slam v5 只是“允许试用”；charge 是 3.138 s one-shot，在 2.5 s 蓄力结束/下砸时被淡出截断；A/C/D 四条仍是候选。音量/低切/结尾都未由人耳确认。
3. 弱点 v2 的**运动**是创作者刚认可的，但 1x 实机叠加在场/2x 守卫上是否够清晰、48×48 原图在胸口是否过大，需看截图/实机；旧预览偏低的问题已改为胸口，未再让人复核挂点。
4. 城内只有 192×96 拱样 + 暗墙 + 暖光，是“可走入的起始空间语言”，不是完整城市；远处城门剪影是屏幕固定暗层，不是真视差。
5. 电影暂停用的是 `PauseMenu.open_pause()` 同一代码路径，失焦用窗口信号直接触发；未在真实 Esc/OS 失焦下手动连按；返回主界面按钮的实际点击、设置页、完成页两条按钮的鼠标/键盘流程未点测。
6. 守卫的“地形射线挡住/背后/远距”只有背后与去重实测；arena 内没有真实墙体做穿墙反例（射线代码存在，未专门造墙）。
7. 核心/装置的 16/24 尺寸以 v7 候选为准；固定装置 v4、场 v3、浮地等仍是候选，未被创作者最终确认所有美术。
8. 普通死亡不重复教学已测；但“死亡后从浮地/守卫前恢复再打”的完整人手路径、R 后所有音频/相机/输入细节的连续体感未做人工长跑。
9. 本报告不把测试 setup 当成人工全关试玩；未跑旧 suite，没有回归覆盖旧关。

## 7. 复现命令

```bat
cd /d "D:\godot game\星核旅人\基础场景原型"
set Godot=D:\Godot\Godot_v4.7.2-stable_win64_console.exe

%Godot% --headless --path . res://tests/level03/test_level03_load.tscn
%Godot% --headless --path . res://tests/level03/test_level03_route.tscn
%Godot% --headless --path . res://tests/level03/test_level03_combat.tscn
%Godot% --headless --path . res://tests/level03/test_level03_cine.tscn

REM 实机截图（有窗口）：
%Godot% --path . res://tests/level03/capture_level03.tscn
```

日志：`tests/level03/*.log`、`screenshots/level03_prototype_20261115/MANIFEST.txt`。测试的 setup 说明在各 `.gd` 文件头与本报告第 3 节。


## 8. 2026-11-15 定向修复复测（第二轮，保留初版 199 为先前检查）

本轮只修 L3 演出的三处规格遗漏/边界，不改旧前两关、素材或布局，不重跑旧全量，也没有把初版 199 当成“已覆盖本轮修改”的证据。**第 3 节的 199（load 34 / route 33 / combat 73 / cine 59）是修复前的检查，原样保留；下面是新复测。**

### 8.1 门前回头 + 真实石块动静

- `L3Player` 新增仅 L3 使用的 `face_direction()`（调用共享 player 的私有朝向方法，不改共享脚本）。
- DOOR 段改为 1.20 s：主角先朝门（`get_facing()==1`）显示问号；0.40 s 时只对“守卫活着且当前不在散架/重组”的情形发一次 `stone_cue_requested`（短石块落定声，复用已记录的 float-settle 候选，不新增素材）；0.75 s 主角实际转向守卫方向（`get_facing()==-1`），问号换成感叹号；1.20 s 后镜头才移到守卫。真实重组仍由守卫自己的 `reassembly_started` 音效驱动，不叠新的石头 cue；已击败守卫不发 cue。
- 新测实际检查 `get_facing` 数值（不是只查符号 visible）、cue 的 `get_last_played()=="stone_cue"`、GUARD 段相机 x 已接近守卫；已碎裂分支检查没有假的 stone cue。新增实机截图 `level03_07_cine_turn.png`（只补这一张，原 7 张未重渲染；见 `MANIFEST_TURN.txt`）：主角已朝左（守卫），感叹号在头顶，镜头仍在主角。

### 8.2 等松键边界（active-or-await 占用）

- `L3Cinematic.is_active()` 现在返回 `_active or _await_release`；await 期间 HUD 仍隐藏、玩家输入仍锁、守卫 cinematic mode 仍冻结、cine 相机仍持有视图。因此 level 的 E/J 门槛、暂停、失焦、R 都会把它当成占用。
- `_complete_finish()` 在长按空格仍未松时进入 await；`_restore_control()` 才恢复相机/解锁/关守卫 mode/发 fresh charge。`abort()` 现在也处理 `_active=false + _await_release=true`，并清 `_space_held`、解锁、回相机、关守卫 mode；`reset_for_new_run()` 同样解锁、回相机、关守卫 mode、清 played/await。
- 测试用**真实长按空格**进入 await（日志：`held Space reaches await-release (forced_setup=false)`），然后在该间隙：
  - 按 E（门/携带核心已在可嵌距离）→ **不嵌入**；按 J → **不挥击**。
  - Esc/暂停 → abort：HUD 回来、玩家解锁、相机回玩家、守卫 mode 清、门未被误触；松开空格不跳。
  - R → 关卡回起点、相机/守卫/await 全清、门未动。
  - 失焦 → abort + 守卫冻结；回焦解冻；门未动。
  - 若 headless 无法保持 held 输入，测试有明确的 `debug_force_await_release()` 有限 setup 并在日志标 `SETUP forced...`；本次实际走的是真实 held 路径。
- 长按跳过后仍检查守卫进入新一轮蓄力（elapsed < 0.7 s），2.50 s 蓄力窗保留反应时间；同一空格按下在恢复后仍不触发跳跃。

### 8.3 已击败 / 部分真伤的分支对白

- 守卫已击败：使用 2 页短分支（“核心已落/按 E 取走”“到城门按 E 嵌 24px 孔，门开后再入城”），不再讲“三次它才失活”的当前行动；不复活、不重置真伤/核心/门。
- 仍有 1–2 次部分真伤：保留 3 页教学，不重置已有真伤标记，不强制展示倒下；真实 stone cue 仍可出现；测试检查 1 mark 保持且页数仍为 3。
- 新测还检查已击败页数为 2、首句指向取核/核心、没有假 stone cue、守卫保持 defeated/inactive。

### 8.4 本轮实跑

| 测试 | 结果 | 说明 |
| --- | --- | --- |
| `test_level03_load.tscn` | **34/34 PASS** | 载入/资源/初始态；本轮复跑 |
| `test_level03_combat.tscn` | **73/73 PASS** | 守卫/J/门/城；因门电影 skip 路径同受影响而复跑 |
| `test_level03_cine.tscn` | **112/112 PASS** | 新增回头/cue/相机、await 负例、E/J 封锁、暂停/失焦/R 清理、partial/defeated 分支；替换原先 59 的统计 |
| `test_level03_route.tscn` | 未复跑（原 33/33 保留为先前检查） | 本轮未改运核/浮地/布局相关逻辑 |

- 新增截图：`screenshots/level03_prototype_20261115/level03_07_cine_turn.png` + `MANIFEST_TURN.txt`；原 7 张未重渲染。
- 音频 cue 复用 `audio_float_settle.ogg`（已有第 15 节候选记录），未新增/编辑 ASSET_CREDITS，未复制新材料。
- 仍未验：真人手感的回头节奏/相机速度、真实 OS 长按与失焦的端到端体验（headless 用真实 synthetic held key，日志已标 forced_setup=false）、cue 的听感、已击败/部分真伤对白的阅读节奏；没有人工全关试玩。
