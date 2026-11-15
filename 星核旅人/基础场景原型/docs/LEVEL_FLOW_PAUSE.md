# 关卡衔接与暂停页（LEVEL_FLOW_PAUSE）

更新：2026-11-06。适用正式入口 `scenes/level_01.tscn` 与 `scenes/level_02.tscn`。旧 `main.tscn`/F5、F7 原型未改。

## 1. 用户操作路径

### 第一关完成

- 走到出口后出现“第一关完成”结算页：
  - 主按钮 **进入第二关**（鼠标点击或键盘 Enter/Space，默认焦点在此）。
  - 次按钮 **重玩本关**，R 也仍可重玩。
  - 次按钮 **返回主界面**（回第一关初始标题菜单）。
- 只有 `_completed` 后按钮才生效；只接受一次，按钮立即禁用并切到真实
  `res://scenes/level_02.tscn`。不会在碰出口瞬间自动换关。
- 第二关以真实初始态进入：人物 (36,320)、辉相、起始仓锁定、目标仓空、
  `get_tree().paused == false`；旧 HUD/完成罩/Camera/输入不会保留。

### 两关暂停页

按 Esc（游戏进行中，或完成结算页上）打开：

- **继续游戏**：关闭暂停页。若从完成页打开，回到结算页，人物仍被完成冻结。
- **设置**：打开与标题菜单同一套主音量/显示设置；游戏仍暂停。
- **重新开始本关**：等价于 R，关闭暂停页并重置本关。
- **返回主界面**：切回真实 `level_01.tscn` 初始标题菜单，不保存本关进度。
- **退出游戏**：只调用 `SceneTree.quit(0)`，不关闭编辑器/其他进程。

第二关完成页有主按钮 **返回主界面** 和 **重玩本关**，没有第三关/下一关。
Esc 也能从第二关完成页打开暂停页。

### Esc 层级（每次按键只处理一层）

1. 显示确认 pending：Esc 取消未确认显示更改，**留在设置页并保持 paused**。
2. 设置页：Esc 返回暂停根，**仍 paused**。
3. 暂停根：Esc 继续游戏。
4. 游戏中：Esc 打开暂停根。

R 在设置页/显示确认中无效；普通暂停页与游戏中 R 仍重开本关。
焦点默认在“继续游戏”；Tab/方向键/Enter/Space 可用。设置页有明确返回。

## 2. 设置复用方式

没有复制一套分叉设置 UI：

- 暂停页内嵌一个 `StartMenu` 的 `settings_host_mode` 实例，直接复用：
  - 主音量滑条、百分比、`user://audio_settings.cfg`；
  - 窗口/桌面全屏、窗口尺寸、应用、10 秒保留/超时/Esc 回退；
  - `user://display_settings.cfg`、`DisplaySettingsController`、`PixelMenuButton`。
- host 模式不会启动标题菜单、世界隐藏、MenuCamera 或 2.2s 开场转场。
- 暂停页和标题菜单仍可各自初始化显示控制器：第一关标题菜单已应用配置时，
  暂停页读取同一路径；第二关 F6 独立启动时，暂停页宿主在关开始时应用已保存
  显示配置，因此确认后的窗口/全屏不会因独立启动而丢失。
- 未确认显示在离开设置、重开、返回标题、退出或场景释放时由
  `DisplaySettingsController` 回退；失焦不停止绝对时间倒计时（沿用已批准语义）。
- 音量修改立即生效并写入同一音频配置，跨关/回标题继续读取。

## 3. 底部常驻按键条

- 两关 HUD 不再绘制运行中的底部常驻按键条；`InputMap` 和实际控制逻辑不变。
- 暂停页右侧按本关分组展示：
  - 两关共有：A/D 或方向键、左Shift、空格、Q、F、R、Esc。
  - 第二关额外：E 释放/入仓；第一关不显示 E。
- Q 切换小提示、房间任务/交互 toast 保留。

## 4. 实现文件

- `scripts/level_01.gd`：完成页信号接线、下一关/回标题、暂停菜单创建、单一
  Esc/R 所有权（关闭 player 自重置，避免双重）。
- `scripts/level_02.gd`：暂停菜单、完成页回标题、重置时关闭暂停/完成状态。
- `scripts/level_hud.gd` / `scripts/level_02_hud.gd`：移除底部条与旧
  Label 暂停罩；完成页真实按钮；HUD 只保留 pause 状态标志。
- `scripts/ui/pause_menu.gd`（新）：两关共享暂停页、真实按钮、焦点、Esc 层级、
  内嵌设置 host、退出。
- `scripts/ui/level_flow.gd`（新）：真实 `change_scene_to_file`、清树暂停、
  释放跨场景输入。
- `scripts/start_menu.gd`：新增 `settings_host_mode` 与 host 打开/关闭/取消
  pending 接口；不改原菜单/开场默认流程与显示语义。
- `scenes/level_01.tscn`、`scenes/level_02.tscn`、`project.godot` **字节未改**，
  World/地面/碰撞/物件/Camera/V3 平台/DS03 运动全部保持。

## 5. 本轮实际验证（关键节点，非完整通关）

按用户 2026-11-06 的最新偏好，只跑关键 smoke，不重跑旧全套/完整出生路线：

- 解析/载入：两正式场景 headless 启动无脚本错误。
- `tests/test_level_flow_pause.tscn` headless **93/0**：
  - 两关初始态、底部条移除、暂停页按键分组；
  - 两关 Esc→暂停→设置→Esc 回暂停→Esc 继续；暂停冻结物理；焦点默认继续；
  - 设置页 R 被忽略；暂停根 R 重开并关闭页面；
  - 主音量 37% 写入同一配置，第二关读取到 37%；
  - **完成状态为 setup（直接发真实出口信号/布置目标仓）**，第一关 Enter
    单次进入真实 Level02，新场景初态/树 paused/无旧完成罩；
  - 第二关完成页主按钮为“返回主界面”，真实回到 Level01 初始标题；
  - 第二关暂停返回真实 Level01 初始标题；
  - 显示 pending 的 Esc 优先取消、设置不关、仍 paused，下一 Esc 才回暂停根。
- 独立 GUI 子进程 `tests/test_pause_quit_subprocess.tscn`：真实鼠标点击暂停页
  “退出游戏”，进程退出码 **0**（`tests/logs/level_flow_pause_quit_gui_result.json`）。
- 真实 GUI 截图（非 headless）：
  - `screenshots/level_flow_pause_01_level01_pause.png`
  - `screenshots/level_flow_pause_02_level01_completion.png`
  - `screenshots/level_flow_pause_03_level02_pause.png`
  - `screenshots/level_flow_pause_04_settings.png`
- 保护检查 `tests/logs/level_flow_pause_protection.json`：基线 146 文件，
  141 不变；仅 5 个允许脚本变化；`project.godot`、两关 scene、player、
  star-core/rune/stele/exit、旧 main 均 unchanged。

## 6. 未验/边界

- 没有重跑两关完整真实出生→通关路线、全部旧 suite、菜单/显示全套、DPI/多分辨率
  矩阵或大量 GUI 帧；按用户要求交给实际游玩发现问题。
- 完成→第二关的 smoke 使用 setup 触发完成，不等同于从出生完整通关。
- 标题菜单与暂停 host 各自初始化显示控制器；已保存配置一致时无可见跳变，
  但极端窗口移动/多显示器/DPI 未再穷举。
- 第二关完成页按钮、Esc 暂停、退出/回标题已实现并接线；完整人工手感/审美与
  长时稳定性待用户试玩。

## 7. 运行

```powershell
$project = "D:\godot game\星核旅人\基础场景原型"
# 正式第一关（标题菜单） / 第二关独立 F6
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path $project res://scenes/level_01.tscn
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path $project res://scenes/level_02.tscn
# 关键 smoke
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path $project res://tests/test_level_flow_pause.tscn
# 独立 GUI 退出检查
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path $project res://tests/test_pause_quit_subprocess.tscn
```
