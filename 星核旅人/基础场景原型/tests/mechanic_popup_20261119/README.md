# 机制演示弹窗 · 实现与验收（2026-11-19）

本次只加教学层：一次性机制弹窗、触发钩子与真实关卡演示素材。未改玩法规则、碰撞、数值、对白文本、关卡布局和美术风格；未改另一个 agent 正在处理的 `scripts/narrative/opening_cinematic.gd` / `scripts/level03/l3_cinematic.gd`。

守卫弹窗为 **2 页**，其余机制 1 页。守卫触发时机已改为**近门残响电影/对话结束、控制交回之后**；6 条演示全部加长为 **24 帧 / 8 fps / 256×144（3 s）**。

## 1. 新增 / 修改

新增：

- `scenes/ui/mechanic_popup.tscn`
- `scripts/ui/mechanic_popup.gd`（`MechanicPopup`）
- `scripts/ui/mechanic_tips.gd`（`MechanicTips`，静态运行内去重）
- `assets/mechanic_demos/{polarity,core_carry,relay_link,float_platform,guard_invalid,guard_valid}.png`（每条 24 帧横条）
- `assets/mechanic_demos/*.json`（24 帧 / 8 fps / 摆放说明）
- 本目录：捕获场景/脚本、测试场景/脚本、日志、截图、接触表

修改（只加钩子）：

- `scripts/level_01.gd`：弹窗创建、触发判断、对白/暂停阻断。
- `scripts/level_02.gd`：同上，`core_carry` / `relay_link` 两处触发。
- `scripts/level_03.gd`：同上，`float_platform` / `guard_field` 两处触发；新增 `_guard_tip_ready` 时机门。

## 2. 守卫触发时机（本次重点）

实际检查 `scripts/level03/l3_cinematic.gd`：

- `finished` 只在 `_restore_control()` 里发出，也就是控制真正交回时。
- `abort()` **不会**发 `finished`，只恢复控制并返回。

因此 `level_03.gd` 的处理是：

- 新增 `var _guard_tip_ready: bool = false`。
- `_on_cinematic_finished()` 里置 `true`（`_cine.finished` 已连接）。
- `before_pause_opened()` 中若 `_cine.is_active()`，调用 `_cine.abort()` 后也置 `true`；这样暂停中止对话后，恢复时仍有守卫提示。
- 窗口失焦导致的 `_cine.abort()` 同样置 `true`，避免一次失焦永久丢掉提示。
- `_restart_level()` / R 中 `_cine.reset_for_new_run()` 后置 `false`。
- `_tick_mechanic_popup()` 的守卫条件改为：
  `_guard_tip_ready and _stable_stage >= STAGE_ARENA and pos.x >= 1680 and not _guard.is_defeated()`。
- 对白进行中、电影进行中、暂停中、恢复/重试中都不弹；`is_mechanic_popup_blocked()` 保留这些阻断。
- `MechanicTips` 的“本次运行只弹一次”不变。

实测结果：

- 残响电影开始前：守卫弹窗不弹，`_guard_tip_ready=false`。
- 电影进行中：不弹，`_guard_tip_ready=false`。
- 电影结束/长按跳过并交回控制：`_guard_tip_ready=true`，守卫弹窗在第一个可用 tick 打开；打开时守卫状态为 `GRAVITY_CHARGE`、`action_elapsed=0.000`、`enemy_slam_count=0`，即尚未造成伤害前就被暂停。
- 暂停菜单中止电影：`abort()` 不发 `finished`，但 `before_pause_opened()` 已置 ready；恢复后弹窗打开。
- R 重开：ready 复位为 false；seen 记录仍按运行内去重。

## 3. 版式、分页、输入

- 640×360 内面板 560×236，位置 (40,62)；遮罩 alpha 0.72。
- 左演示窗 256×144，位置 (12,12)，1 px 青灰边、黑底、最近邻采样；右侧 x=282、宽 266。
- 标题 16 px 金色、正文 12 px、按键行 12 px 青色，沿用暂停面板配色与字体处理。
- 右上角页标 `1 / 2`，单页隐藏。
- 页脚按页数变化：
  - 单页：`F 继续 · 长按空格 跳过`
  - 有下一页：`F 下一页 · 长按空格 跳过`
  - 最后一页：`F 关闭 · 长按空格 跳过`
- `F`：有下一页翻页，末页关闭；单页直接关闭。
- 长按空格 0.5 s：关闭整个弹窗，不逐页翻；右下角复用 `scripts/narrative/skip_hold_bar.gd` 的 `SkipHoldBar`（`update_hold` / 内部 `set_progress` / `hide_progress`），位置为其原生 640×360 右下角 (528,336)，不再自绘第二条进度条。
- 短按空格：不翻页、不关闭；0.10 s 后显示共享进度条，松开清空。
- 翻页时：树保持暂停、演示回到第 0 帧、seen 不变、不触发其它机制。
- 关闭时清空玩家输入缓冲，避免长按空格带入跳跃。
- 缺素材时隐藏左窗、文字扩满，不报错。

## 4. 触发点与文案（5 个机制，守卫 2 页）

| id | 关卡 | 触发条件 | 页数 |
| --- | --- | --- | --- |
| `polarity` | L1 | 玩家 x ≥ 640，且未开场、无对白、无暂停/完成 | 1 |
| `core_carry` | L2 | 稳定阶段仍为起始仓、玩家 x ≥ 84 | 1 |
| `relay_link` | L2 | 中继仓真实入仓后、稳定阶段 ≥ 中继仓、玩家 600 ≤ x < 940 | 1 |
| `float_platform` | L3 | 装置未激活、玩家 y ≤ 220、x 180–380、距装置 ≤ 110 | 1 |
| `guard_field` | L3 | `_guard_tip_ready` 为真、稳定阶段 ≥ 竞技场、玩家 x ≥ 1680、守卫未击败 | **2** |

文案：

- `polarity`：标题 `相性 / 符石`；`同相推开，异相拉近。` / `按 Q 换相，借符石之力上高台、越坑。`；按键 `Q 切换相性 · 靠近符石生效`。
- `core_carry`：`运核入仓`；`按 E 取核，核会变成与你相反的相性。` / `用 Q 调节距离，把核领进空仓再按 E。`；`E 取核 / 入仓 · Q 换相性`。
- `relay_link`：`联动仓解锁`；`中继仓入仓后，力线可以穿过石墙。` / `把核送入联动仓，符石会记住它的颜色。`；`E 入仓 · 借力符石上高台`。
- `float_platform`：`浮地装置`；`按 E 启动装置，石板升起并限时支撑。` / `踩上后约 1 秒开始松动，别停太久。`；`E 启动 / 重建浮地`。
- `guard_field` 第 1 页：`守卫吸附 · 无效伤害`；`蓄力时异相被吸近、同相被弹开。` / `异相普通攻击只碎壳、立刻重组，不计伤害。`；`Q 换相性 · 被吸近 / 被弹开`。
- `guard_field` 第 2 页：`守卫 · 有效伤害`；`趁蓄力被吸近，按 J 命中胸口弱点。` / `命中 1 点真伤后守卫换相。` / `再按 Q 切回异相；累计 3 点。`；`J 命中弱点 · 命中后 Q 再切异相`。

第一关没有独立“借力”输入/节点，借力就是符石场对玩家的 Q/相性力，因此并入 `polarity`，不单列。

与代码核对：

- `l3_guard.gd:681`：`snapshot_positive == _positive` 返回 `SAME_PHASE`，J 出真伤必须是**异相**；第 2 页写“切回异相”，未写“切同相”。
- `SHELL_HITS_TO_BREAK = 2` 当前声明但未被引用；普通有效命中走 `_apply_normal_break()`，一次就碎壳/重组、不计真伤；`MAX_TRUE_DAMAGE = 3`。
- `_advance_hurt` / `_begin_hurt` 不是当前真伤路径；真伤走 `_begin_scatter()` → `_advance_reassembling()` 后 `_pending_true_switch` 换相。

## 5. 演示素材（6 条，24 帧 / 8 fps / 3 s）

全部为**正式关卡真实状态的非 headless 捕获**，256×144 横条。运行时帧数由 `texture.get_width() / 256` 推导，不依赖 JSON 的 `frames`；JSON 仍记录 `frames=24` 与摆位说明。

- `polarity`：L1 高台真实符石场；24 帧内真实 Q 在 frame 6 / 16 切换，吸引与推开往返，保持符石与玩家同框。
- `core_carry`：L2 起始仓真实 E 释放核；向右走 1 s、停 1 s 等核跟上、再向左走 1 s，核按真实相性对力跟随。
- `relay_link`：L2 真实取核、搬到中继仓、真实 E 入仓；前段是入仓，后段停留真实已入仓/墙状态。
- `float_platform`：L3 真实装置 E 启动浮地，玩家站上 Block2；前 12 帧是真实 1.1 s 倒计时 + 抖动开始；后 12 帧**循环最后 3 个仍在石板上的抖动帧**。真实掉落会进入恢复黑屏，属于无关画面，因此采用规格允许的“循环尾部”，未伪造新动作。
- `guard_invalid`：L3 真实 `GRAVITY_CHARGE` 吸附 → 真实 Q 切同相 + A 退出 92 px 释放环 → 守卫 RECOVER/ACTIVE → 普通异相 J → `SHELL_SHATTER` → 壳碎/重组。3 s 覆盖了“吸附/弹开 → 无效普通命中 → 重组”，捕获结果不是 `TRUE_HIT`，玩家未被释放环命中。
- `guard_valid`：L3 真实 `GRAVITY_CHARGE` 吸附 → 靠近 → J → `TRUE_HIT`（remaining=2）→ 碎壳/重组 → 守卫换相（末段可见蓝色新相性）。

## 6. 运行 / 复跑

```
cd "D:/godot game/星核旅人/基础场景原型"

# 1) 导入
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import

# 2) 功能验收（headless）
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  res://tests/mechanic_popup_20261119/test_mechanic_popup_20261119.tscn

# 3) 演示捕获（必须窗口模式）
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
  res://tests/mechanic_popup_20261119/capture_mechanic_demos.tscn

# 4) 打开态截图（必须窗口模式）
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
  res://tests/mechanic_popup_20261119/capture_popup_shots.tscn

# 5) 状态图说明条 + 接触表
D:\minic\envs\2024212971\python.exe tests\mechanic_popup_20261119\annotate_after_cine.py
D:\minic\envs\2024212971\python.exe tests\mechanic_popup_20261119\make_contact_sheet.py
```

## 7. 实测结果

- `test_run.log`：**127 PASS / 0 FAIL**，末行 `MECHANIC_POPUP_TEST_OK`，exit 0，无 ERROR/WARNING。
  - 电影前/中不弹；电影结束/跳过、控制交回后弹；打开时守卫 `GRAVITY_CHARGE`、elapsed=0、slam=0。
  - 暂停中止电影：abort 不发 finished，但 ready 已置；恢复后弹窗打开。
  - R 重开：ready 复位 false。
  - 两页页标/页脚/按键行/文案、F 翻页/末页关闭、翻页暂停/演示回 0/seen 不变、短按空格不翻页、长按一次关闭整窗。
  - 暂停期间守卫蓄力、L2 星核、L3 浮地计时冻结。
  - 五处触发各一次；R/切关不重置 seen。
  - 缺素材降级、请求排队、已暂停树拒绝打开。
- `capture_run_24.log`：`MECHANIC_DEMO_CAPTURE_OK`，6 条 24 帧。
- `import.log`：exit 0，无 ERROR/WARNING。
- `level_01/02/03_quit90.log`：三关 `--headless --quit-after 90` 均 exit 0，无 ERROR/WARNING。

## 8. 截图

- `popup_polarity.png`
- `popup_core_carry.png`
- `popup_relay_link.png`
- `popup_float_platform.png`
- `popup_guard_page1.png`（`1 / 2`，无效伤害）
- `popup_guard_page2.png`（`2 / 2`，有效伤害）
- `popup_guard_after_cine.png`（残响结束、守卫弹窗刚出现的原始 640×360 状态图）
- `popup_guard_after_cine_annotated.png`（同图底部加状态说明条）
- `popup_guard_after_cine_state.txt`（同图状态：player=(1986.915,320)、stage=3 ARENA、guard=GRAVITY_CHARGE、elapsed=0.000、slam=0、page=1/2）
- `popup_skip_hold.png`（共享 `SkipHoldBar`）
- `popup_missing_demo.png`
- `contact_sheet_20261119.png`（总览）
- `raw/`：各条 24 张 256×144 原始帧与首末整屏

## 9. 未完成 / 风险

- 未做真人整关试玩；触发、翻页、跳过均为脚本注入 + 真实渲染截图核对。
- `float_platform` 的后 12 帧是真实抖动帧循环，不是实时掉落；真实掉落会进入恢复黑屏，未用无关画面凑。若协调者希望保留掉落，需要另定更长的片段或不同机位。
- `guard_invalid` 已覆盖“吸附/弹开 → 普通碎壳 → 重组”；由于 3 s 窗口，没有在弹窗内重复演示第二次普通命中。
- `relay_link` 的 0.7 s 屋顶解锁材质在 1× 256 px 裁片外，后段停留的是真实已入仓/石墙状态，未画入屋顶效果。
- `MechanicTips` 仅本次运行内有效，退出后清零（未写 `user://`）。
