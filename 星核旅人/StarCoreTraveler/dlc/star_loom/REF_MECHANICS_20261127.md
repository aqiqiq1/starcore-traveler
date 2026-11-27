# DLC3 补回机制 · 呈现参考记录（2026-11-27）

## 本轮要解决的问题

不是新造门/石/检查点造型，而是把**本体已批准的三件 prefab** 放进 DLC3
冷石+金线的城内厅，让同相门、可推拉符文石、检查点在 640×360 下能读、
不挡角色、不破坏 Boss 房构图。

## 实际打开并核看的来源

### 1. 同相门（已有 prefab，沿用其批准参考）

- 页面：Celeste Wiki · Core Block，2026-11-27 重新打开：
  <https://celeste.ink/wiki/Core_Block>
  - 页面两态信息框仍为 Hot 深炭黑/红橙裂纹、Cold 深蓝/青裂纹；两态共用轮廓。
- 项目内实际游戏截图（本轮打开核看）：
  - `screenshots/art_audit_20261127/after/dlc_01_trial.png`：试炼场双门，
    金太阳/青月亮在 640×360 下可读；8×88 光幕、34×34 标记板、锁扣。
  - `screenshots/art_audit_20261127/after/dlc_03_loom.png`：DLC3 城内厅的
    冷石拱窗、金色经线、深色台座。
- 既有参考记录：`dlc/trial_chambers/REF_POLARITY_GATE.md`
  （含 2026-11-25 的 Celeste Hot/Cold 实际截图路径与“不照搬”边界）。

### 2. 符文石（本体旧机制，直接复用 prefab）

- `scenes/rune_stone_field.tscn` / `scripts/rune_stone_field.gd`：
  32×32 三态石、`field_range=160`、`full_acceleration=2400`、
  同相斥/异相吸、无实体球碰撞。
- `scenes/rune_stone_visual.tscn` / `scripts/rune_stone_visual.gd`：
  睡眠/金/青三张原生 32×32 图、+/- 提示。
- 项目内实际游戏截图：
  - `screenshots/art_audit_20261127/after/level_01.png`：本体关卡里的
    冷石/金线地面与角色比例；符文石与该层同一调色。
- 本轮新增的“可移动”只改变承载方式：把石头的 `Node2D` 沿地面移动，
  力仍由既有 `sample_field()` 给出；没有改 prefab、没有画新石头。

### 3. 检查点（本体旧机制，直接复用 prefab）

- `scripts/level_checkpoint.gd`：40×36 原生 inactive/active PNG、
  `Area2D` 触发、脚底锚点 (20,35)、`checkpoint_entered` 信号。
- 实际打开核看的纹理：
  - `assets/checkpoint_exit/checkpoint_inactive.png`
  - `assets/checkpoint_exit/checkpoint_active.png`
- 项目内使用方式：`scenes/level_01.tscn` / `scenes/level_02.tscn` 的
  `LevelCheckpoint` 节点（只读参考，未改本体）。

## 可借鉴 / 不照搬

可借鉴：
- 门的状态先于细节：整色光幕 + 中央日/月标记 + 有/无锁扣；本轮保持。
- 门/槽/检查点都落在同一条冷石台座上，金线只做 1 px 读点，不铺大面积发光。
- 石头的 +/- 提示和青/金整色沿用本体，让“同相推、异相拉”在同一套视觉语言里。

不照搬：
- 不使用 Celeste 的方块像素、裂纹、Hot/Cold 具体造型或弹跳/碎裂玩法。
- 不复制第三方门框、角色、字体、音效或调色板；金 `#f4cd63`、青 `#5fe1e6`、
  近黑底沿用项目现有三关。
- 不把试炼场的背景/柱子搬进 DLC3；DLC3 继续用 `city_v2` 冷石拱窗。

## 证据路径

- 本轮实机 640×360：
  - `screenshots/loom_mechanics_20261127/gate_closed.png`
  - `screenshots/loom_mechanics_20261127/gate_open.png`
  - `screenshots/loom_mechanics_20261127/stone_socket.png`
  - `screenshots/loom_mechanics_20261127/stone_pulled_back.png`
  - `screenshots/loom_mechanics_20261127/checkpoint.png`
- 基线参考：
  - `screenshots/art_audit_20261127/after/dlc_01_trial.png`
  - `screenshots/art_audit_20261127/after/dlc_03_loom.png`
  - `screenshots/art_audit_20261127/after/level_01.png`

## 未核实

- 没有重新逐帧播放 Celeste Core Block 的 GIF；门沿用既有静态两态结论。
- 没有运行 Celeste 本体，也没有听/看其开关动作与音效。
- 石头的手感只在本轮 headless 断言与 5 张 640×360 截图中核对，未做长时间真人试玩。
