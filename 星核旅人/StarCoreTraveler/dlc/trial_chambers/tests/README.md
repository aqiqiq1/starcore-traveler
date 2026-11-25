# 星核试炼场 · 实现与验证记录（2026-11-25）

分支：`feature/gameplay-expansion-20261125`（未提交、未推送、未导出）。

## 新增/改动文件

- `scenes/trial/polarity_gate.tscn`
- `scripts/trial/polarity_gate.gd`
- `scenes/trial/trial_chambers.tscn`
- `scripts/trial/trial_chambers.gd`
- `scripts/trial/trial_hud.gd`
- `scripts/start_menu.gd`（仅新增 Quit 下方 112×20 的 `试炼场` 按钮、焦点链与场景切换；既有开始/设置/退出逻辑未改）
- 本目录下的测试场景、日志、截图与 `out/`。

未改：`level_01/02/03` 场景与脚本、`project.godot`、`export_presets.cfg`、既有菜单布局/设置页、`assets/mechanic_demos`、`assets/audio*`、`scripts/narrative`。未新增外部素材、音频、字体。

呈现参考：`项目归档/玩法拓展_20261125/REF_POLARITY_GATE.md`（已实际打开 Celeste Wiki Core Block 的 Hot/Cold 两态并截图，参照点为整块变色 + 中央亮核；未搬造型/像素/玩法）。

## 运行命令

Godot：`D:/Godot/Godot_v4.7.2-stable_win64_console.exe`，工程目录：`D:/godot game/星核旅人/基础场景原型`。

```powershell
# 门逻辑 / 碰撞 / 防夹
... --headless --path . res://dlc/trial_chambers/tests/gate_test.tscn

# 出生→两门→竞技场→失败→R→三真伤→完成→回标题
... --headless --path . res://dlc/trial_chambers/tests/route_test.tscn

# 标题按钮键盘 + 鼠标 + 既有开始/设置回归
... --headless --path . res://dlc/trial_chambers/tests/title_test.tscn

# 暂停“返回标题”
... --headless --path . res://dlc/trial_chambers/tests/pause_title_test.tscn

# 640x360 实机截图（必须不加 --headless）
... --path . --position 60,60 res://dlc/trial_chambers/tests/capture_visuals.tscn

# 导入 / 三关 90 帧
... --headless --path . --import
... --headless --path . res://scenes/level_01.tscn --quit-after 90
... --headless --path . res://scenes/level_02.tscn --quit-after 90
... --headless --path . res://scenes/level_03.tscn --quit-after 90
```

## 本轮结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 极性门 | **32 / 0**，exit 0 | `gate_test.log` |
| 试炼路线 | **46 / 0**，exit 0 | `route_test.log`、`route_test_visual.log` |
| 标题入口 | **25 / 0**，exit 0 | `title_test.log` |
| 暂停返回标题 | **5 / 0**，exit 0 | `pause_title_test.log` |
| 导入 | exit 0，无 ERROR/WARNING | `import.log` |
| 主线 90 帧 | 三关均 exit 0，0 ERROR/WARNING | `level_01_90.log` 等 |
| 试炼 90 帧 | exit 0，0 ERROR/WARNING | `trial_90.log` |

门测试实际数值：

- 初始：玩家澜相（`is_positive()==false`），金门需辉相 `required_positive=true`，碰撞层 1。
- 同相：`is_open()==true`，`get_collision_layer()==0`。
- 异相：阻挡；实际按住右 50 帧停在 `x=269.93`（门 x=280，8 px 门 + 12 px 身位）。
- Q 后同相穿过到 `x=342.47`。
- 青门（x=520）辉相阻挡在 `x=509.93`；Q 回澜相后穿过到 `x=581.93`。
- 防夹：同相进入门内（`is_player_inside()==true`）后切到异相，仍是 `is_open()==true`、碰撞层 0；离开后 `is_open()==false`、碰撞层 1。
- 门不改变玩家相性（切换 required 后玩家相性不变）。

路线测试实际覆盖：标题状态 → 真实按住右/跳 + Q 穿过两门 → 进入竞技场 → 两次受击恢复（玩家回到 `x=850` 竞技场入口、guard 回 ACTIVE、可继续移动）→ R 整关重置（回 `x=40`、澜相、计时清零、无暂停/完成锁）→ 再次走完两门 → 三格真伤击败守卫 → 触碰 `x≈1200` 完成点 → 面板“试炼完成 · 用时 00:16” → E 返回 `res://scenes/level_01.tscn` 且 `StartMenu` 存在。

## 截图（均实际渲染 640×360）

`tests/trial_20261125/out/`：

- `gate_gold_closed.png`：金门关闭（澜相玩家）
- `gate_gold_open.png`：金门打开（辉相玩家在门内，碰撞层 0）
- `gate_cyan_closed.png`：青门关闭（辉相玩家）
- `arena.png`：竞技场与守卫三格血条
- `pause.png`：Esc 暂停，仅“继续 / 返回标题”
- `completion.png`：完成页（静态截图，用 guard 现有 debug 死亡 + defeated 信号到达页面）
- `route_completion.png`：真实三真伤路线打完后的完成页，用时 00:16
- `title_trial_button.png`：标题 Quit 下方“试炼场”按钮，焦点高亮

`out/.gdignore` 让这些截图不参与项目资源导入。

## 验证方法说明 / 局限（不作夸大）

- 路线中两门、R、暂停、完成/回标题均走真实玩家输入（`Input` 动作 / viewport 按键）与真实场景状态；不是用静态截图冒充。
- 守卫三格真伤：第 1 击通过真实 `J` 键事件进入 `request_attack()`；第 2/3 击为确定性测试直接调用同一个 `request_attack()`。每次命中都由 guard 自己的 `receive_player_hit()` 状态机结算。为控制测试时序，使用了 guard 已有的 `debug_force_gravity()` 进入引力蓄力；没有修改 guard 规则、伤害或 J/J 射程。
- 失败恢复测试通过 `guard.player_struck` 信号注入两次（连接的是产物中同一个接收函数），不是物理被守卫击中；真实物理受击仍需人手试玩确认。
- `completion.png` 为画面取证使用了 `guard.debug_force_death()` + `defeated.emit()`；`route_completion.png` 则来自真实三真伤路线。
- 守卫蓄力/下砸/重组复用现有 `scripts/level03/l3_audio.gd` 和既有音频文件；主角挥击/受击/碎裂/记录/完成/失败/复活沿用 `DemoAudio`。没有新增音频资源，也没有改动主线音频。
- 未做真人整关节奏、手感、可读性终审；像素级呈现只按本项目 640×360 实际截图核看。
- 本轮未执行 Git 提交/推送/导出。

## 2026-11-25 真实 J 伤害修复 + 开场说明页

### 实际失败点（复现记录）

- 真实 J（`Input.parse_input_event`，物理键 J）在 **正确条件**（异相、GRAVITY_CHARGE、
  正面 2–36 px）下本来就能掉血：`attack_started` / `attack_hit_window` 各 1 次，
  `receive_player_hit()` 返回 `TRUE_HIT`，真伤标记 0→1。
- 实战中打不出伤害的三个原因：
  1. 试炼场没有把守卫既有的 `sample_player_force()` 接到玩家外力。原关卡 03
     靠异相引力把玩家吸进 36 px 的 J 射程；DLC 只画了引力场，没施加力，
     玩家在 38/42/48/56/70 px 按 J 全部是 `MISS_RANGE`。
  2. 玩家朝向取的是“最后一次移动方向”。后退或换目标后立刻按 J 会朝反方向
     `MISS_BEHIND`（实测 -22 px、朝左时）。
  3. 规则本身（必须异相 + 蓄力）只在 mechanic popup/基础关讲过，DLC 的 HUD
     在无效命中时没有反馈。

### 修复（只改 DLC）

- `trial_chambers.gd`：每物理帧把 `_guard.sample_player_force()` 的结果通过
  `_player.apply_external_force()` 施加；异相被吸近、同相被弹开，和关卡 03 的
  provider 契约一致。未改守卫射程、伤害、状态机。
- 真实 J 按下时，若竞技场内 140 px 内有存活守卫，先把玩家转向最近守卫（只改
  facing，不改位置/相性/射程）。修复旧朝向造成 `MISS_BEHIND`。
- `attack_hit_window` 里读取 `receive_player_hit()` 的返回：`SHELL_SHATTER` /
  `SAME_PHASE` / `MISS_RANGE` / `MISS_BEHIND` / `BLOCKED` 各给一行短提示；
  真实真伤仍显示“剩余 N”。规则不变，只把规则讲清。
- `trial_hud.gd`：补 `get_event_text()` / `is_event_visible()` 测试访问器。
- 新增共享 `dlc/ui/dlc_guide.tscn/.gd`：关卡开始自动弹一次 3 页说明
  （目标 / Q 与门内安全 / 守卫战），`F` 翻页、长按空格 0.5 s 跳过、Esc 吞掉。
  `TrialChambers.show_intro_guide = true`；自动测试在 `add_child` 前设 false。
  说明页内容/示意图/截图见 `dlc/ui/tests/README.md`。

### 本轮测试结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 极性门 | **32 / 0** | `gate_test.log` |
| 试炼路线 | **46 / 0** | `route_test.log` |
| 标题入口 | **25 / 0** | `title_test.log` |
| 暂停返回标题 | **5 / 0** | `pause_title_test.log` |
| 真实 J（共享测试，含 trial） | **23 / 0** | `../ui/tests/real_j_damage_test.log` |
| 开场说明页（共享测试） | **81 / 0** | `../ui/tests/guide_test.log` |
| 说明页演示 | 3 页均真实关卡帧条 24 帧 / 8 fps | `../ui/demos/trial_*.png` |

真实 J 实测（修复后）：

- trial：异相 70 px 蓄力 24 物理帧被拉近 `dx=+4.39`、`force_x=496.8`；
  22 px 背对守卫按 J，自动转正后 `TRUE_HIT`，真伤 0→1。
- 同相按 J：`SAME_PHASE`，真伤不变，HUD 显示“同相无效 · Q 切异相再按 J”。
- 所有 J 攻击都通过 `Input.parse_input_event` 的真实物理键事件，没有直接调用
  `request_attack()`。

## 2026-11-25 打磨补充（门开启提示）

- 只改 `dlc/trial_chambers/polarity_gate.gd` 的 `_draw` 与 `_physics_process` 计时段：
  开启态在 8×88 轮廓内画 3 条 4×1 px 近白横线 + 3 px 箭头，2.2 s 自下而上循环；
  关闭态保持原实体亮场与横向火花刻度。碰撞层、防夹 latch、`is_open()` 等 API 未改。
- 参考：`dlc/rift_workshop/REFERENCE_PASS_CUE.md`（Celeste Core Block / Dream Block
  逐帧核看；只借“状态先于细节 + 内部单向动效”的读序，不搬像素/造型/调色板）。
- 重新跑四项测试仍为 **32 / 46 / 25 / 5，0 失败**，导入与三关 90 帧 0 ERROR/WARNING。
- 640×360 截图已重出：`tests/out/gate_gold_closed.png`、`gate_gold_open.png`
  （开启态站在门侧，箭头可见）、`gate_cyan_closed.png`、`arena.png`、`pause.png`、
  `completion.png`、`title_trial_button.png`。
- 局限：静态截图只证明两种状态和箭头存在，未做真人“远看/边走边看”的可读性终审。
