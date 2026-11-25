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
| `assets/audio/*.wav` | 生成：inversion / bridge / wisp_hum / wisp_pop / complete |
| `tools/gen_assets.py` | 上述图片与 WAV 的生成脚本（无网络、无第三方采样） |
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
