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
