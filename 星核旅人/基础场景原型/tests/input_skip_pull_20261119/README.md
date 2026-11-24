# 输入 / 跳段 / 守卫吸力验收（2026-11-19）

本目录只包含本轮新增的测试场景、脚本与日志；不修改归档或旧测试。

## 运行

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  --quit-after 20000 res://tests/input_skip_pull_20261119/test_input_skip_pull_20261119.tscn
```

退出码 0 且末行为 `INPUT_SKIP_PULL_OK` 时通过。

## 覆盖

- `A. L1 opening`：短按空格不补全/不翻页；F 先补全再翻页；长按空格 0.6s 直接跳过整段；
  跳过结束时保持控制直到空格松开；松手后玩家没有因空格残留而起跳。
- `B. L3 cinematic`：同上四条规则；另核对两关暂停页文案含 `F继续` 与 `长按空格跳过整段`。
- `C. 守卫吸力`：把玩家设为与守卫相反的相性（真正“吸引”），以共享跑速 160 从左侧进入
  GRAVITY_CHARGE 场，记录入场速度、峰值速度、最大采样加速度、弱点前累计冲量、是否越过
  守卫/弱点；另做两条“松手”补充测量。只读 `get_field_tuning()`、`sample_player_force()`
  与玩家真实物理，不改守卫规则。

测试用到的设置仅：关闭 L1 标题菜单、通过关卡自身 `_start_cinematic()` 开始 L3 演出、
设定玩家相反相性、把玩家放到竞技场已知 x。守卫 AI、力场采样、玩家物理、碰撞、对白逻辑
均按正式代码运行。

## 2026-11-19 实测（FIELD_ACCELERATION = 520）

来源：`run_520.log`（46 PASS / 0 FAIL，exit 0，无 ERROR/WARNING）。

```
PULL_TUNING acceleration=520.0 range=118.0 inner=16.0 full=42.0 fade=24.0
PULL_PASS entry_speed=160.0
PULL_PASS peak_speed=320.0          # 触及玩家共享 ANCHOR_MAX_HORIZONTAL_SPEED=320
PULL_PASS max_accel=509.39
PULL_PASS impulse_pre_cross_dv=165.06
PULL_PASS crossed_weakpoint=true
PULL_PASS crossed_guard=true
PULL_PASS end_x_minus_chest=138.45
```

旧值 750 的对照（把常量临时改回 750 跑同一脚本后已改回 520，见
`run_750_temp_reference_reverted.log`；该日志末尾的 FAIL 是“当前值应为 520”的断言，
说明它是临时参考运行，不是当前失败）：

```
PULL_PASS max_accel=734.51
PULL_PASS impulse_pre_cross_dv=220.41
PULL_PASS peak_speed=320.0
PULL_PASS end_x_minus_chest=132.56
```

即：满强度加速度 −31%，弱点前累计吸力冲量 220.41 → 165.06 px/s（−25%）；但两者都在
穿越途中触及共享 320 速度上限，峰值速度相同，160 跑速穿越仍然会越过守卫与弱点。

补充“松手”测量（`PULL_STOP` / `PULL_EARLY`）中，玩家在弱点附近松开方向后仍被
“借速保护”保留 320 余速，520 的制动更弱，实际滑到弱点后约 126–128 px 才停下，
且滑行末尾已超出 1.3s 蓄力窗口（`charge_still_active_at_rest=false`）。因此这组数
不能用来宣称“停下更短/更不容易滑过头”；它只说明吸力强度与每帧增量确实下降。
750 参考运行的松手段在停下前被释放环命中（`player_hits=1/2`），不能作为干净的
对照值。

## 其它日志

- `level_01_quit90.log` / `level_02_quit90.log` / `level_03_quit90.log`：三关
  `--headless --quit-after 90`，均 exit 0，无 ERROR/WARNING。
- `import.log`：`--import` 一次，exit 0。其中报错来自工程既有、早已删除的旧脚本引用
  （`background.gd`、`polarity_record_test_*`、`star_core_interaction_standalone.gd`），
  与本轮 6 个脚本及本测试无关；未修改这些旧场景。

## 未验证

- 未在窗口模式做人工按键/画面验收；键盘路径全部通过 `Input.parse_input_event` 注入。
- 未检查暂停页文字在 640×360 实际渲染中的像素溢出（只核对数据源字符串）。
- 未跑旧的大测试套件，未做真人整关试玩。
