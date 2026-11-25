# 裂隙工坊 · DLC 第二章设计（2026-11-25）

分支：`dlc`（未切分支、未提交、未推送、未导出）。本章是**独立 DLC 目录**：
`dlc/rift_workshop/` 整个删掉后，`level_01/02/03` 与标题菜单必须照常运行，
只是标题不再显示「裂隙工坊」（`ResourceLoader.exists` 判定）。

## 目标

在试炼场之后给一个更完整、可重复玩的短章：先用**新机制反转光幕**改相性，
再用**新机制相性光桥**考“相性即地形”，最后用**双生守卫**收尾。
所有规则只读/调用既有 L3 玩家与守卫接口，不改基础三关、`project.godot`、
`export_presets.cfg`、`scripts/narrative`、`assets` 运行资源。

## 场景

单场景 `dlc/rift_workshop/rift_workshop.tscn`，**1600×360**，横向跟随镜头
（640×360 视口，Camera2D limit 0..1600）。背景 DS03（`l3_depth`）
+ 本章专用紫色雾/浮屑 overlay。

### 段 1 · 反转回廊（x 0–560）

- 地面 `0..560`，顶面 y=320。
- `InversionA` x=160，24×120 紫色光幕；`InversionB` x=400。
- 两道既有极性门：`GateGold` x=270（需辉相）、`GateCyan` x=490（需澜相）。
- 2 只 PolarityWisp：x=330（初始金）、x=530（初始青），悬浮 y≈248/246。
- 走法：澜相出生 → 进 A 翻成辉相 → 过金门 → 进 B 翻回澜相 → 过青门。
  Q 始终可用，但这两道门用光幕教学“进入即翻、离开可再触发”。

### 段 2 · 相性桥（x 560–1080）

- 高台 `TerraceStart` x=560..688，顶面 y=280（40 px 台阶，跑跳可上）。
- 三段 `PhaseBridge`（64×10，顶面 y=280）：金 x=688..752、青 x=800..864、
  金 x=912..976；中间两块 48 px 石台 `LandingA` x=752..800、`LandingB` x=864..912。
- 高台终点 `TerraceEnd` x=976..1080，检查点 x=1030。
- 桥下**安全落脚层** `PitFloor` x=688..976，顶面 y=340（不会触发 kill line）。
  掉下去只损失节奏，可走回石台/高台重新起跳，不软锁。
- 2 只 PolarityWisp：x=776、x=888（各自悬在石台上方）。
- 走法：上高台后 Q→辉相过金桥，落石台 Q→澜相过青桥，再 Q→辉相过第二段金桥。

### 段 3 · 双生守卫（x 1080–1600）

- 竞技场地面 x=1080..1600，顶面 y=320；入口 x=1090 触发守卫苏醒。
- `GuardGold` 出生 x=1240，巡逻 1150..1320；`GuardCyan` 出生 x=1450，
  巡逻 1370..1530。两者 `start_positive` 一金一青，各自独立状态机与血条。
- 玩家 2 次受击 → 淡出 → 回竞技场入口 x=1100；只重置**仍存活**的守卫，
  已击败的守卫保持倒下（不是整章重来）。R 才是整章重开。
- 两只都击败 → 完成核心点亮 → 触碰 x=1560 完成。
- 完成面板「裂隙封闭 · 用时 mm:ss」，E/Enter 回标题。

## 新机制

### InversionField

- 24×120 紫色光幕；进入（Area2D，玩家 body）时把玩家相性翻**一次**；
- 停留在内部不再翻（Q 在内部只算玩家自己的切换）；离开后重新武装，可再次触发；
- 不改玩家输入、不伤害、不阻挡；只调用 `set_polarity_state()`；
- 防重复：`_inside` 由 `body_entered/exited` 维护，不使用逐帧检测；
- 视觉：整块紫 + 中央亮核/竖向亮缝 + 双向箭头，触发时白闪与横向冲击线；
  读序参考 Celeste Core Block（只借鉴“整块同色 + 中央亮核”）。

### PhaseBridge

- 64×10；玩家相性与 `required_positive` 一致 → 碰撞层 1（可站）；
  不一致 → 碰撞层 0（消失，玩家下落）。
- **防夹**：若切回同相时身体仍与 10 px 桥体重叠，先不实体化，等身体离开
  （向上或向下）再实体化；不瞬移、不挤压。
- 视觉：实体=深边 + 饱和桥体 + 中央亮条 + 两端亮帽 + 上下柔光；
  消失=仅 1 px 虚线轮廓 + 3 个漂移火花；实体化有 0.22 s 白闪。
- 下方必有安全层（段 2 的 PitFloor），掉下去不是死亡而是重试。

### PolarityWisp

- 原创 16×16、4 帧、金/青两态（8 帧条：0–3 金、4–7 青），2× nearest 显示。
- 正弦悬浮（y 振幅 6 px）+ 轻微横向摆；每 2.2 s 换相，每 3 s 脉冲。
- 脉冲：半径 82；同相 → 推开，异相 → 拉近；冲量横向为主（纵向 ×0.35），
  不产生免费跳跃/穿地；脉冲前 0.45 s 画蓄力环，脉冲瞬间画扩散环。
- J 一击击破：由章节在真实 `attack_hit_window` 里用玩家朝向矩形判定，
  **不要求异相、不要求真伤**；击破有 pop 音与 6 片碎光。
- 每只 wisp 自带 hum（1.000 s 循环、-24 dB，仅玩家 250 px 内播放），
  击破/脉冲共用 `sfx_wisp_pop.wav`（不同 pitch/音量）。

## 素材（全部原创生成/代码绘制）

- `assets/sprites/polarity_wisp_16x16_8f.png`：Python 生成的 128×16 帧条；
- `assets/rift_fog_640x360.png`：Python 生成的紫色雾（中下部浓、顶部干净）；
- `assets/audio/*.wav`：5 条 16-bit/44.1 kHz 单声道，峰值 ≤ -16 dBFS：
  `sfx_inversion`、`sfx_bridge`、`sfx_wisp_hum`、`sfx_wisp_pop`、`sfx_complete`；
- 生成脚本 `tools/gen_assets.py`（可重跑，无网络、无第三方采样）。
- 其余视觉（光幕、光桥、浮屑、蓄力环、完成面板）全部 `_draw()` 代码绘制。
- 详细参考与“可借鉴/不照搬”见 `REFERENCE.md`。

## 入口

`scripts/start_menu.gd` 只做加法：Quit 下方已有「试炼场」(y=238)，
新增「裂隙工坊」(264, 262, 112×20, STONE)；仅当
`res://dlc/rift_workshop/rift_workshop.tscn` 存在时 `visible/disabled` 打开并加入焦点环，
缺失时隐藏、禁用、焦点环跳过。点击/Enter 先释放一次性动作并锁住全部菜单热区，
再 `change_scene_to_file`；失败可恢复菜单。基础 master 不包含此按钮。

## 复用与依赖（明确记录）

- 复用且未修改：`scenes/level03/l3_player.tscn`（J/受击/回跳）、
  `scenes/level03/guard.tscn`、`scenes/backgrounds/cloud_ruins_ds03.tscn`、
  `scripts/level03/l3_terrain.gd` + `bridge_stone_v1` 石面、`scripts/level_checkpoint.gd`、
  `assets/level03_prototype/key_core_12f.png`、现有字体与调色板、
  `scripts/ui/level_flow.gd`、`PixelMenuButton` / `CompactLevelHeader`。
- **跨 DLC 只读复用**：`dlc/trial_chambers/polarity_gate.tscn`（与 `.gd`）作为两道
  极性门；本章不修改 trial_chambers 任何文件。若单独删除 trial_chambers，
  本章的门会缺失（当前验收只要求删除 rift_workshop 后基础游戏正常）。
- 未改：基础三关场景/脚本、`project.godot`、`export_presets.cfg`、
  `scripts/narrative`、`assets` 运行资源、`scripts/audio/demo_audio.gd`。

## 验证门槛（与 tests/README.md 对应）

- 反转只翻一次；桥同相可站/异相消失且防夹、不软锁；
- wisp 可击破、脉冲推/拉确实作用于玩家、相位按 2.2 s 切换；
- 双守卫都能被真实真伤判定击败，只倒一只不开完成；
- 失败回竞技场入口、R 不软锁、完成后 E 回标题；
- 真实输入路线贯通三段；640×360 实机截图 7 张；
- 导入、三关 90 帧 0 错误；删除整个 `dlc/rift_workshop` 后 `level_01` 仍 0 错误。

## 未做 / 局限

- 可选 GuideEcho 两页未做（保持范围，改为 HUD 一行目标 + 事件提示）。
- 守卫战斗的自动化证据沿用既有 `debug_force_gravity()` 进入引力蓄力，
  受击仍由 guard 自己的 `receive_player_hit()` 结算；真实物理手感需人手复玩。
- 桥下安全层是设计上的保底路线（可沿下层走到终点后跳上高台），
  不是主路线；它保证“掉下去不软锁”，但熟练玩家仍可能绕开部分桥段。
- 未做真人节奏/可读性终审；像素呈现只按 640×360 实机截图核看。
