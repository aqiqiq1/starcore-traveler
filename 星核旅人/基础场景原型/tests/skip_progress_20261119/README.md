# 长按空格跳过·右下角进度条验收（2026-11-19）

本目录只包含本轮新增的测试场景、脚本、日志、截图与参考记录；未改旧测试、未动
`scenes/ui`、`assets/mechanic_demos`，也未碰 level_01/02/03 的弹窗钩子。

## 改动

- 新增 `scripts/narrative/skip_hold_bar.gd`（`SkipHoldBar`）：一个纯呈现控件，不读输入、
  不改跳段计时/控制权，只在两段演出各自已有的 UI 层内实例化。
- `scripts/narrative/opening_cinematic.gd`：在 `OpeningCinematicUI` 内创建进度条，按
  `_space_time / SKIP_HOLD` 驱动；松开、短按、跳过提交、OUTRO、await-release、结束、
  暂停/失焦/中止时隐藏。
- `scripts/level03/l3_cinematic.gd`：在 `CineUI` 内创建同规格进度条，按同样的字段与
  时机驱动；`play/abort/reset/_complete_finish/_restore_control/debug_force_await_release`
  均清理。
- 未新增图片素材；颜色与 1px 边沿用已批准的暂停面板，`anti_aliasing=false`、无圆角、
  无阴影。

规格：640×360 逻辑视口，轨道 96×6，位置 `(528, 336)`；12px「跳过」在轨道左侧，
间距 6px；近黑底、`#739e9f` 1px 边框、`#f4cd63` 金色填充。L1/L3 位置完全一致，
都落在 44px 下黑边内，不压对白气泡。

## 运行

断言（headless）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  res://tests/skip_progress_20261119/test_skip_progress_20261119.tscn
```

断言 + 640×360 截图（窗口模式，必须能创建渲染设备）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
  res://tests/skip_progress_20261119/test_skip_progress_20261119.tscn -- --capture
```

截图像素复核：

```
D:\minic\envs\2024212971\python.exe tests\skip_progress_20261119\verify_shots.py
```

退出码 0 且末行为 `SKIP_PROGRESS_OK` / `PIXEL_AUDIT_OK` 时通过。

## 2026-11-19 实测

### 1. 功能断言

- `run_headless.log`：`SKIP_PROGRESS_RESULT pass=69 fail=0 shots=0`，末行
  `SKIP_PROGRESS_OK`，exit 0，无 ERROR/WARNING。
- `run_capture.log`：同一断言 + 8 张 640×360 截图，`pass=85 fail=0 shots=8`，
  `SKIP_PROGRESS_OK`，exit 0，无 ERROR/WARNING。

覆盖（两段演出各一遍）：

- 条位于 `(528,336)`、96×6；标签「跳过」在左侧且有间距，字体 12；1px `#739e9f`
  边、无圆角、anti_aliasing=false、近不透明近黑底、`#f4cd63` 填充。
- 3 帧短按：按下帧、按住 0.05s、松开后均不可见。
- 真实长按：逐帧采样 progress 只增不减；每一采样满足
  `fill_width = round(94 * progress)`。
  - L1 `target=.2/.4/.6` 实测 `progress=.2014/.4059/.6040`，`width=19/38/57`。
  - L3 实测 `progress=.2014/.4059/.6003`，`width=19/38/56`。
    （0.6003×94=56.43，四舍五入 56；不是条宽错误。）
- 松开蓄力：条立即隐藏。
- 长按到真实跳过：`_skipped=true`，条在 OUTRO 前即隐藏；仍进入 await-release，
  按住空格仍保持控制；松手后 `is_active()==false`，UI 层隐藏，条无残留。
- 松手后玩家没有因空格残留起跳（L1、L3 各一次 y/velocity 断言）。

### 2. 截图（640×360，`read` 已逐张查看）

- `l1_opening_hold_020.png` / `_040.png` / `_060.png`
- `l3_cinematic_hold_020.png` / `_040.png` / `_060.png`
- `l1_opening_after_skip_hidden.png`
- `l3_cinematic_after_skip_hidden.png`
- `*_detail6x.png`：右下角 6 倍放大裁片，便于看 1px 边、金色填充和 12px 标签。

画面核对：条在下黑边内，右侧留 16px；标签不遮挡条；未覆盖对白气泡；6 张蓄力图
的填充依次变长；两张 after-skip 图中条完全消失（场景和黑边状态也正常）。

### 3. 像素复核

`pixel_audit.log`：`PIXEL_AUDIT_OK`

```
l1 0.2/0.4/0.6 gold x=529..547 / 529..566 / 529..585 (19/38/57 px)
l3 0.2/0.4/0.6 gold x=529..547 / 529..566 / 529..584 (19/38/56 px)
all 640x360, border 528..623 / rows 336..341, label pixels=99
after_skip: gold_in_bar=0 border_in_bar=0（两关）
```

### 4. 三关启动

`level_01_quit90.log` / `level_02_quit90.log` / `level_03_quit90.log`：
`--headless --quit-after 90` 全部 exit 0，日志中 ERROR/WARNING 行数均为 0。

### 5. 导入

`import.log`：`--import` 一次，exit 0；未出现脚本解析错误。

## 参考核看

见 `references/REFERENCE_NOTES.md`。实际打开并观察了 GTA San Andreas 的
Hold-to-Skip 游戏截图（右下角、标签在左、避开字幕、只在按住时出现），并记录了
Hi-Fi Rush 的右下角 meter 文字资料。未取得 Hi-Fi Rush 第一手画面，条的具体形状、
尺寸与配色来自本轮用户规格和工程暂停面板，不是从参考照抄。

## 未验证 / 局限

- 键盘路径全部由 `Input.parse_input_event` 注入；没有真人手动长按试玩。窗口模式截图
  使用真实渲染设备，但输入仍是合成事件。
- 为了让「短按不显示」成立，控件有 0.10s 的显示延迟：短于 0.10s 的按键完全不出现，
  因此可见的第一帧进度约为 0.17，而不是从 1px 宽开始显示。进度数值本身仍严格等于
  `_space_time / SKIP_HOLD`，截图的 0.2/0.4/0.6 均按真实计时达到。
- 12px 字体的行盒高于 6px 轨道，标签是垂直居中于轨道、上下略超出黑边内的 6px 带；
  这是小字号正常行高，未压到对白。
- 只跑了本目录小测试与三关 90 帧启动；未跑旧的大测试套件，未做整关人工试玩，未导出，
  未 Git 提交。
- 参考记录中的 GTA San Andreas 截图是第三方游戏画面，仅作研究证据留在
  `references/`，未进入游戏资源；未照抄其像素或字体。
