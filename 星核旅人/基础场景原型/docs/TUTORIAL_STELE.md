# 提示石碑教程组件（TutorialStele）

更新日期：2026-11-01。本文只说明教程石碑组件、它的素材生成、主场景最小接入和验证结果；不改变角色、星核运输、符文石、F2/F4/F7 原有玩法。

## 1. 交付与入口

- 可拖放组件：`scenes/tutorial_stele.tscn`（根节点 `TutorialStele`，`@tool`）。
- 主场景节点：`scenes/main.tscn` 的 `World/TutorialStele`，位置 `(224, 288)`，`player_path = ../Player`。没有移动 Terrain、Player、AnchorRoom、InteractionRoom、HUD 或 F7 房间的节点。
- 单独查看：`scenes/tutorial_stele_demo.tscn`（F6 直接运行），出生点左侧为灰态，右侧两块石碑用于看近光、翻页和“仅最近一块响应”。
- F 操作：`scripts/input_setup.gd` 增加 `tutorial_next = KEY_F`。翻页由石碑自己消费真实按键事件；Main 只做房间切换时的暂停/清页通知。
- 文本只含三条操作教学，可由创作者在检查器里改 `pages`（`PackedStringArray`）。

新增/改动文件：

| 文件 | 用途 |
| --- | --- |
| `scripts/tutorial_stele.gd` | `@tool` 组件：灰/流光显示、最近石碑协调、页面、世界锚定提示框、暂停/失焦/换房清理 |
| `scenes/tutorial_stele.tscn` | 可直接拖入 2D 场景的组件；根为 `Node2D`，子节点 `Stone` 为 26x52 精灵 |
| `scenes/tutorial_stele_demo.tscn` | F6 视觉/翻页/多碑演示，不另建测试房系统 |
| `scripts/input_setup.gd` | 新增 `tutorial_next`（F），原动作不变 |
| `scenes/main.tscn` | 只新增 `World/TutorialStele` 实例；不改原有节点位置 |
| `scripts/main.gd` | F2/F4/F7/R/失焦的最小调用；不接管翻页 |
| `自制素材/提示石碑/generate_tutorial_stele_assets.py` | 直接调用批准概念脚本的 `stone()`/`groove_floor()` 生成运行资产 |
| `assets/tutorial_stele/` | 灰/金/青参考 PNG、槽 mask、64 帧流光图、manifest |
| `tests/test_tutorial_stele.gd` / `.tscn` | 独立 Godot 验收，不修改现有 runner |
| `tests/test_tutorial_stele_fidelity.py` | 直接对概念脚本做像素级核对 |
| `tests/test_tutorial_stele_capture.gd` / `.tscn` | 真实引擎截图工具，不是人工连续试玩 |
| `screenshots/tutorial_stele_01..05*.png` | 实际 Godot 根视口截图 |
| `screenshots/MANIFEST_TUTORIAL_STELE.txt` | 截图说明和“脚本固定姿态”标记 |

## 2. 美术保真与生成

唯一形态来源是已批准的概念脚本：

`自制素材/提示石碑概念示意/draw_concept.py`，其中 `stone(state='grey', band_y=26)` 原生输出 26x52；`groove_floor()` 是有效槽 mask，槽宽上段 5 px、21..23 行 4 px、24..28 行 3 px、29..31 行 4 px、下段 5 px。

运行资产：

- `assets/tutorial_stele/tutorial_stele_grey.png`：`stone('grey', 26)` 原样导出；
- `tutorial_stele_gold.png` / `tutorial_stele_cyan.png`：`stone('gold'/'cyan', 26)` 原样导出；
- `tutorial_stele_groove_mask.png`：`groove_floor()` 原样导出；
- `tutorial_stele_frames.png`：64 帧 × 26x52，横向排列（1664x52）；
- `tutorial_stele_manifest.json`：源脚本/概念图/生成脚本哈希、生成参数、帧表哈希、槽宽、帧心位置等。

组件运行时只加载 `tutorial_stele_grey.png` 和 `tutorial_stele_frames.png`；gold/cyan 参考图和槽 mask 是保真对照、测试和文档用，不进入游戏绘制。

生成方法不是重画：`generate_tutorial_stele_assets.py` 用 `importlib` 加载概念脚本，直接调用其 `stone()` 和 `groove_floor()`。动画帧同样由概念函数生成：先取同一 `band_y` 的 gold/cyan 两张概念图，在槽 mask 内按颜色保持段合成，再把**槽外像素整个复制回 grey 参考**。因此：

- 三态参考的 alpha 完全一致，外壳不描边、不缩放、不旋转；
- 每一帧槽外像素与 grey 逐像素相等；
- 灰态没有金/青痕迹；
- 运行时没有任何 `modulate`、着色器或外壳染色，流光已烘焙在 26x52 帧里；
- 显示固定为 1:1、NEAREST，不使用 2× 或平滑过滤。

动画节奏（默认由组件 `glow_fps = 8` 驱动）：

| 项 | 值 |
| --- | --- |
| 帧数/尺寸 | 64 帧，每帧 26x52 |
| 播放 | 8 FPS，8 s 一循环 |
| 亮带 | 4 s 一次向下扫过槽；亮带上缘软尾、下缘较短前缘（沿用概念公式） |
| 颜色 | 第一趟金 `#f4cd63`，第二趟青 `#5fe1e6`；两者都完整保持，不把亮带染成中间绿色 |
| 换色 | 只在亮带已离开槽的 t≈0.47..0.53 短暂交叉，屏幕上看到的是纯金或纯青的亮带 |
| 基准帧 | 第 16 帧 = 精确 `stone('gold', 26)`；第 48 帧 = 精确 `stone('cyan', 26)` |
| 入场 | 组件从第 8 帧开始（亮带在槽上口附近），随后向下流 |
| 底部光 | 槽内 0.27 基色柔光 + 高斯亮带，全部在 `groove_floor` 内 |

复核命令：

```powershell
& "D:\minic\envs\2024212971\python.exe" "D:\godot game\星核旅人\自制素材\提示石碑\generate_tutorial_stele_assets.py"
& "D:\minic\envs\2024212971\python.exe" "D:\godot game\星核旅人\基础场景原型\tests\test_tutorial_stele_fidelity.py"
```

## 3. 组件用法

把 `scenes/tutorial_stele.tscn` 拖入场景即可。根节点原点在石碑脚底中心；视觉精灵内部固定为 `(-13, -52)`，所以把根节点放到地面上即可。组件没有 `CollisionObject2D`、`Area2D`、`CollisionShape2D`，不阻挡玩家。

主要导出项：

| 导出项 | 默认 | 说明 |
| --- | --- | --- |
| `pages` | 三页 | 每页字符串；`\n` 可换行，长句自动 word-smart 换行 |
| `near_range` | 56 px | 玩家脚底到石碑脚底的进入距离 |
| `leave_margin` | 10 px | 已显示后的额外离开距离（56+10=66），防边界单帧闪烁 |
| `player_path` | 空 | 留空时自动找 `PrototypePlayer`；Main 中设为 `../Player` |
| `glow_fps` | 8 | 只影响动画播放速度，不改变图 |
| `prompt_width` | 244 px | 文字框宽度；会被限制在 640x360 内 |
| `prompt_hud_safe_top` | 50 px | 文字框顶部安全线，避免被现有顶部 HUD 遮挡 |

提示框是石碑上方的世界空间 `Control`，不是 HUD 子节点：

- 每条石碑只创建一个提示框和三个 `Label`，翻页只改文字/尺寸，不会重复实例化节点；
- 位置随石碑根节点移动；每帧根据当前 640x360 视口把左右边和顶部夹紧（顶部默认 50 px，底部为 notch 留 8 px）；
- 中文使用本地 `assets/fonts/tutorial_zh.ttf`（Fusion Pixel 12px Prop zh-Hans，OFL-1.1；详见 `docs/TUTORIAL_FONT_SOURCE.md`），字号 12 px，运行时复制字体资源并关闭抗锯齿/Hinting/次像素定位，`allow_system_fallback = false`；不依赖 Windows 系统字体；
- 如果字体尚未导入，组件仍可解析、提示框会用 Godot 回退字体并记录一次 warning；测试会因缺字失败，不会用 ASCII 冒充中文完成。

## 4. 交互规则

- 进入 56 px：自动显示第 1 页，石碑切到 64 帧流光图；
- F：一次真实按下只翻一页。`InputEventKey.echo`（长按连发）直接忽略，不累计；
- 最后一页按 F：收起提示框，但玩家仍在范围内时石碑继续发光；
- 仍在范围再按 F：从第 1 页重读；
- 离开（>66 px）：隐藏提示、回到第 1 页、切回精确 grey，动画停止；
- R / 落坑 / 房间重置：通过 Main 的 `reset_performed` 调用 `on_player_reset()`；如果在范围内就回到第 1 页，若 R 把玩家送回出生点则下一帧因超距隐藏；
- 失焦：Main 的 `handle_focus_lost()` 调用 `on_focus_lost()`，没有半读页面残留；
- Esc：石碑节点为 `PROCESS_MODE_PAUSABLE`，树暂停时动画帧和 F 输入都冻结；
- F2/F4：Main 在进入前调用 `set_suspended(true)`，石碑立即隐藏、变灰并退出最近石碑协调；返回基础房时解除暂停，若玩家在范围内会重新从第 1 页开始；
- F7：Main 在 `change_scene_to_file` 前先 suspend；F7 目标场景本身不含 TutorialStele，场景切换后不会留下提示；
- 不锁玩家移动、不暂停世界、不加 NPC/头像/选择题；E/Q 等原输入不变。

多石碑协调是轻量的，不新增 autoload 或全局管理器：

- 石碑在 `tutorial_stele` group 中；每帧只在当前场景树里取该 group；
- 只让最近的一块获得 focus；已有 focus 的石碑只有在另一块明显更近（8 px 余量）或自己超出离开范围时才让出；
- 只有获得 focus 的石碑显示提示框、消费 F、播放流光；另一块保持 grey，因此不会两个面板同时翻页或同时显示；
- 玩家在 60 px 仍保持当前石碑，68 px 才离开（10 px 滞回），单帧边界不会闪。

## 5. Main 最小接入

`scripts/main.gd` 的改动只有：

- `@onready var _tutorial_stele: TutorialStele = $World/TutorialStele`；
- `enter_anchor_room()` / `enter_interaction_room()`：`set_suspended(true)`；
- `exit_anchor_room()` / `exit_interaction_room()`：`set_suspended(false)`；
- F7 分支：`change_scene_to_file` 前 `set_suspended(true)`；
- `handle_focus_lost()`：`on_focus_lost()`；
- `_on_player_reset_performed()`：`on_player_reset(reason)`。

没有改 `player.gd`、星核运输、符文石、F2/F4/F7 的既有逻辑，也没有改 HUD 布局或文本。主场景的新节点位置 `(224, 288)` 避开了出生点、台阶和窄台，并且没有实体碰撞。

## 6. 验证结果

执行环境：Godot 4.7.2 stable；Python `D:\minic\envs\2024212971\python.exe`。

| 验证 | 结果 | 日志 |
| --- | --- | --- |
| 概念像素核对 | **22 pass / 0 fail** | `tests/logs/tutorial_stele_fidelity_python.log` |
| TutorialStele 独立验收 | **100 pass / 0 fail** | `tests/logs/tutorial_stele_test_stdout.log` |
| 原基础/借力回归 | **316 pass / 0 fail** | `tests/logs/tutorial_stele_runner_regression.log` |
| 真实引擎截图 | 5 张 640x360 | `screenshots/MANIFEST_TUTORIAL_STELE.txt` |

独立验收覆盖了：资产尺寸/帧数/NEAREST/无碰撞；灰态与入场第 1 页；F 翻页、echo 不翻页、末页收起、范围内重读；离开/重进/滞回；两碑仅最近响应且只翻一页；suspend、R、失焦；Esc 冻结动画且不翻页；左右/顶部/底部夹紧与 50 px HUD 安全线；长中文自动换行；实际页面字符全覆盖；F2/F4 房间切换隐藏与恢复；Main 的 F7 目标场景不含石碑。

截图是真实 Godot 根视口捕获，不是预渲染拼图；它们是脚本固定姿态/脚本 F 键的静帧，**不是人工连续试玩录像**。截图使用主场景真实 HUD、背景和石碑节点：

- `tutorial_stele_01_grey.png`：出生点灰态、无提示；
- `tutorial_stele_02_page1.png`：第 1 页金相；
- `tutorial_stele_03_page2.png`：第 2 页；
- `tutorial_stele_04_page3.png`：第 3 页“F 收起”；
- `tutorial_stele_05_cyan_page3.png`：第二趟青色流光、第 3 页仍可读。

对保存的截图做了像素抽样：第 1 页截图石碑槽内出现精确 `#f4cd63`，青色截图槽内出现精确 `#5fe1e6`，灰态截图不含这两个精确色。截图本身仍只是脚本固定姿态，不代表人工连续试玩。

### 已知回归问题（不是本组件引入）

当前 F7 记录房测试 `tests/test_polarity_record.tscn` 结果为 **168 pass / 42 fail / 0 skipped（总 210）**，日志：`tests/logs/tutorial_stele_record_regression_final.log`。

失败起点是 `EMPTY E / NO FAKE RECORD`，原因可从场景与测试坐标直接对上：

- `scenes/polarity_record_test_room.tscn` 当前 `StartBay = (376, 304)`、`TargetBay = (300, 304)`，场景最后修改时间 `2026-10-31 21:27:11`；
- `tests/test_polarity_record.gd` 的最后修改时间是 `2026-10-31 14:57:23`，其“linked bay”测试仍把玩家放在 `x≈340`，预期靠近 linked bay；但移动后的 StartBay 在 376，340 反而先命中 START，于是从“E: RELEASE CYAN - (START)”开始连锁失败。

按用户要求“不改已有地图节点位置（用户已可能挪过 F7 地图）”，本次没有移动/恢复这些节点，也没有改记录房测试。同一轮 F7 main entry 检查（加载主场景、基本 HUD、F7 入口）仍然全部通过。**记录房测试需要地图 owner 更新测试坐标或恢复原布局后再判定 210 回归**；本组件的主场景 F2/F4/F7 接入和 316 runner 不受影响。

## 7. 运行与复核

主场景：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型"
```

F6 单场景：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型" res://scenes/tutorial_stele_demo.tscn
```

独立测试：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_tutorial_stele.tscn
& "D:\minic\envs\2024212971\python.exe" "D:\godot game\星核旅人\基础场景原型\tests\test_tutorial_stele_fidelity.py"
```

F 输入需要先让 Godot 完成导入（本仓库资产已导入）。GUI 截图工具：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_tutorial_stele_capture.tscn
```

## 8. 未完成/待复核

- F7 的实际场景切换由代码路径和“目标场景无 TutorialStele”测试覆盖；未在本轮做人工从主场景按 F7 到记录房再返回的连续试玩。记录房本身的 42 项失败如上，与地图坐标移动有关，需地图 owner 处理。
- 截图中的玩家位置是脚本设置的固定姿态；真实连续走位、跳跃中翻页和长时间循环观感仍需人工试玩确认。
- 本次未改 `progress.md`、`README.md` 的既有汇总；只在 `ASSET_CREDITS.md` 追加了本项目自制石碑和本地教程字体的署名/许可引用。字体的完整来源、校验和许可原文见 `docs/TUTORIAL_FONT_SOURCE.md` 和 `assets/fonts/tutorial_font_LICENSE.txt`。
