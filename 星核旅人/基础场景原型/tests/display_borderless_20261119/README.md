# 显示设置：1920×1080 无边框窗口选项（2026-11-19）

本目录只包含本轮新增的验证脚本、日志、截图和参考记录。未改关卡、弹窗、美术、输入映射、`project.godot` 基准视口/拉伸或 `export_presets.cfg`，未 Git、未导出。

## 改动文件

- `scripts/ui/display_options.gd`
  - 新增 `BORDERLESS_SIZE = 1920x1080`、`is_borderless_size()`、`size_label()`、`is_borderless_choice()`。
  - `fits()` 对 1920×1080 使用物理屏幕尺寸判断，不再套用标题栏余量；其余候选仍按可工作区减边框余量判断。
  - `candidate_entries()` 增加 `borderless`、`label` 字段，2560×1440 仍给出“超出本屏”原因。
  - `validate_choice()` / `validate_saved_state()` 支持无边框标记；旧配置没有 `borderless` 字段时由尺寸推断，未知 mode、非法字段和矛盾字段都回退而不是拒绝启动。
- `scripts/ui/display_settings_controller.gd`
  - 窗口模式 1920×1080 以 `Window.MODE_WINDOWED` + `borderless=true` 运行，尺寸 1920×1080；屏幕正好 1920×1080 时位置对齐物理屏幕原点，更大屏幕则居中。
  - 配置版本 2，新增 `display/borderless`；旧 `mode=windowed/fullscreen` 和尺寸继续可读。
  - 待确认超时从 10 s 改为 15 s；确认、取消、超时、Esc/离场、应用失败都恢复原 mode/size/borderless/position。
  - 捕捉/恢复窗口状态时包含 `borderless`。
  - Windows 细节：如果“边框去掉 + 尺寸设为全屏 + 同一帧挪到屏幕原点”同时发生，Godot 下一帧会把窗口报成 `MODE_EXCLUSIVE_FULLSCREEN`。因此先放到屏幕原点 +1 px，下一帧再落到精确原点；最终位置仍精确，mode 保持 `MODE_WINDOWED`。该过程有 token 防止取消/连续切换时旧回调覆盖新状态。
- `scripts/start_menu.gd`
  - 1920 按钮文字为 `1920×1080（无边框）`（12 px 下实测宽 114 px，按钮宽 144 px）。
  - 说明改为两行：`1920×1080：无边框窗口，3× 整数缩放` / `2560×1440：超出本屏工作区 1920×1032`。
  - 待确认提示初始文字改为 15 秒。
- `tests/display_borderless_20261119/`：本测试、日志、截图、参考记录。旧测试未改。

## 运行

断言（headless，纯规则 + 控制器流程，93 项）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . \
  res://tests/display_borderless_20261119/test_display_borderless_20261119.tscn
```

真实窗口（设置页 640×360 截图、1920 无边框实际窗口、取消/15 秒回退、全屏↔无边框、重启读回，181 项）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . \
  res://tests/display_borderless_20261119/test_display_borderless_20261119.tscn
```

## 2026-11-19 实测

### 1. 纯规则与控制器流程（headless）

`run_headless.log`：`DISPLAY_BORDERLESS_RESULT pass=93 fail=0 shots=0`，`DISPLAY_BORDERLESS_OK`，exit 0。

覆盖：

- 1920×1080 带框不满足 1920×1032 工作区；无边框按物理 1920×1080 判定可用；1366×768 屏幕不可用。
- 640/1280 仍带框可用；2560×1440 仍禁用且带原因。
- 默认窗口仍 1280×720；1920 不被误当默认。
- 旧配置：`windowed 1280×720`、`fullscreen`、无 `borderless` 字段的 `windowed 1920×1080` 均正常。
- 坏配置：未知 mode、`borderless=false` + 1920、`borderless="yes"`、2560、负数尺寸都回退并有 notice。
- 控制器：15 s 默认、暂存不写配置、取消恢复、短超时恢复、应用失败恢复、确认写 `version=2/mode=windowed/1920×1080/borderless=true`、新控制器读回、旧配置读回。

headless 日志中的 WARNING 是“坏配置修正”用例主动触发的生产警告，不是测试失败；退出码 0。

### 2. 真实 1920×1080 窗口（本机）

`run_windowed.log`：`DISPLAY_BORDERLESS_RESULT pass=181 fail=0 shots=3`，`DISPLAY_BORDERLESS_OK`，exit 0。

实际属性：

```
ENV     screen=1920×1080 usable=1920×1032 usable_pos=(2560, 452)
        start window=1280×720 pos=(2880, 608) borderless=false mode=0
APPLY   mode=0 size=1920×1080 pos=(2560, 452) borderless=true
        decorated=1920×1080 content_scale=640×360 integer_scale=3 pending=true
CANCEL  1280×720 pos=(2880, 608) borderless=false mode=0
TIMEOUT elapsed_ms=15044 reason=timeout -> 1280×720 framed
READBACK active_mode=0 active_size=1920×1080 window_mode=0
         window_size=1920×1080 borderless=true notice=""
```

- `window_get_size_with_decorations == 1920×1080`，与窗口尺寸相同，说明没有标题栏/边框余量。
- `Window.MODE_WINDOWED`（0）而非 `MODE_FULLSCREEN`（3）/`MODE_EXCLUSIVE_FULLSCREEN`（4）。
- 取消、15.044 s 超时、全屏取消都恢复到原 1280×720 带框窗口和原位置。
- 通过设置页“应用 → 保留设置”写入临时配置，新建控制器能读回并重新应用 1920 无边框。
- 640×360 仍带框；全屏仍进 `MODE_FULLSCREEN`；从无边框 1920 进全屏后取消，用一帧中间带框窗口过渡，随后回到无边框 1920。反过来从全屏确认后选窗口 1920，也能以两帧过渡落到 `MODE_WINDOWED` + 无边框 1920，不会进入 exclusive fullscreen。

### 3. 截图（已逐张查看）

- `settings_page_640_borderless_option.png`：640×360 实际窗口截图。三个可点候选（640、1280、1920 无边框），2560 灰掉；两行说明写明“无边框窗口，3× 整数缩放”和“2560×1440：超出本屏工作区 1920×1032”；状态“显示设置已保存”。
- `pending_1920_borderless.png`：1920 应用后的确认层，`15 秒后自动恢复`，实际窗口为 1920×1080 无边框。截图是 640×360 逻辑画布（content scale 3×），不是物理窗口尺寸；物理尺寸以 `run_windowed.log` 为准。
- `settings_applied_1920_borderless.png`：确认后设置页，1920 仍为金色选中，说明和状态保持。

### 4. 导入与三关启动

- `import.log`：`--headless --import` exit 0，ERROR/WARNING 行数 0。
- `level_01_quit90.log` / `level_02_quit90.log` / `level_03_quit90.log`：`--headless --quit-after 90` 均 exit 0，ERROR/WARNING 行数 0。

## 未验证 / 局限

- 输入由 `pressed.emit()` 合成，不是真人鼠标点击；窗口属性是引擎/系统实测，但没有真人手动 Alt-Tab 录屏。
- 只验证了本机 1920×1080 单屏布局（工作区 1920×1032，屏幕原点 (2560,452)）；其他 DPI、缩放比例、多显示器、2K/4K 未测。2560×1440 候选没有对应硬件。
- 无边框窗口不能像带框窗口一样拖标题栏；这是无边框选项本身的行为，未加入额外拖拽逻辑。
- 截图是 640×360 逻辑画布；物理 1920×1080 的窗口标志/尺寸/装饰尺寸以日志为准。
