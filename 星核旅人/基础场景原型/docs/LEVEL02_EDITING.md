# 第二关「沉寂回廊」编辑与验收记录

当前编辑入口是 `scenes/level_02.tscn`；F5 从第一关进入完整路线，需要单关时用 F6。正式第二关仍为 1792px、四仓、无守卫；守卫实际在第三关。参照[重制首版布局](LEVEL02_REBUILD_20261113.md)与[当前晶面及门效](L2_GATE_VISUAL_POLISH.md)，状态以[当前交接](../../progress.md)为准。下方第五轮及更早均为旧 640px 版，坐标、守卫和测试数不用于现版验收。

当前地形使用`assets/bridge_stone_v1/generated/`原生尺寸视觉；修改碰撞尺寸后需用`source/build_block.py`生成匹配PNG并更新引用，不能拉伸贴图、覆盖10px真缝或占20px核通道。仓/符石/链接和出生点均可在正式`level_02.tscn`编辑。

## 第五轮：暖灰地面/缝刻槽/高台收口与 12 px 标签（2026-11-12）

本轮只接入已由美术 Agent 生成、协调者审过成图的派生运行图与 UI 可读性修改；不重做第二关几何/碰撞/运输/守卫参数。

### 运行资源（原路径安全替换）

| 运行路径 | 当前 SHA-256 | 变化 |
| --- | --- | --- |
| `assets/map/ruin_platform_tiles.png` | `0E4968FB…091D095D` | 192×32、alpha、12×2 格不变；8 色暖灰映射 |
| `assets/level02_platform_v3/layer_platform_visual_640.png` | `0849BA13…7BD181F` | 640×360；左 HighStep 可见下沿收到 y287，y≥288 alpha=0，碰撞底仍 288 |
| `assets/level02_platform_v3/layer_platform_decor_640.png` | `5C2283F9…53400D` | 640×360；五缝中心 260/284/324/348/372 中性短刻槽；删除高台 y289 两旧苔藓像素 |

- 替换前运行图备份：上级 `项目归档/美术优化前运行资源_20261112.zip`，按相对路径保存三张并逐项 SHA-256/CRC 校验；不覆盖已有归档。
- 旧 source/pre-replacement 哈希（`3A9FC342…`、`EE8D38E3…`、`58C58508…`）不是当前运行图哈希；当前哈希与说明见 `assets/art_pass_20261112/manifest.json` 的 `runtime_application`、`assets/level02_platform_v3/manifest.json` 的 `runtime_replacement`。
- 5 个 `AtlasTexture` 切片坐标、父节点、Nearest、scale 1、白 modulate 均未改；真实 8 px 缝、实体梁/墩、相机、核通路和地面 y≥320 未改。2 个只读批准 V3 源稿与美术生成脚本未动。
- 两张运行图重新导入后实际渲染；不在场景上叠全局调色罩，也不改材质 alpha 伪造“优化”。

### 标签与 HUD 减冗余

- `StartBayLabel` / `TargetBayLabel` / `CorridorLabel` / `UpperLabel` / `ExitStatus` 全部从 9 px 升为 **12 px Fusion Pixel**。`UpperLabel` 缩短为「嵌缝施力」，完整的“实体石段遮挡”仍在石碑第 2 页；`CorridorLabel` 盒宽从 86 增到 110 px。
- `ExitStatus` 的重复门牌「出口」被抑制（`Exit.label_text = ""`），只保留状态行「出口 · 未就绪 / 可离开 / 已完成」，并上移到 y196..212，避免与门顶文字互压。
- L02 HUD：标题 24 px，章节/状态/相性说明/正文 12 px；状态面板只显示「任务：…」与「星核：…」，主行动提示与短 toast 共用 y104 的单个槽位，二者不会同时出现。玩家护符相性仍常驻右上；未新增敌人头顶极性字/符号/菱形，颜色辨敌规则保持。
- 石碑 6 页保留，不替换 NPC；文字仍为 12 px，规则未删。

### 验证与证据（本轮只跑聚焦套件）

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/test_art_guide_pass.tscn
```

- 结果 `TEST_SUMMARY pass=147 fail=0`，`RESULT: PASS`；日志 `tests/logs/art_guide_pass_test_20261112.log`。
- 覆盖本关：5 条 8 px 真缝、HighStep 56×14/底288、RightLedge 32×24/底300、100/40/64/18 力场与 620/300/E 80、玩家边界、守卫脚点/scale、5 个世界标签 12 px 与不裁切、HUD 全 12/24、单提示/ toast 互斥、一次真实信号同相扣血与重复 swing 不结算。
- 资产级验证：`tests/art_guide_pass_assets.py --stage verify` `pass=66 fail=0`；日志 `tests/logs/art_guide_pass_verify_20261112.log`。
- GUI 定帧：`screenshots/art_guide_pass_02_level02_guard_seams.png`、`art_guide_pass_03_level02_under_highstep.png`；日志 `tests/logs/art_guide_pass_capture_20261112.log`。它们是脚本定帧（守卫 AI 暂停/玩家定点 setup），不是人工连续试玩。
- 未重跑旧 119/448/355 大套；未验证人工运输+战斗连续手感、真实 8 秒重组、E 入仓全流程（本轮只做一次守卫受击集成关键点）。

### HighStep 台下遮挡补丁（2026-11-12 追加）

- 问题：`HighStep/V3PlatformVisual` 与 `V3PlatformDecor` 原本 z=0，玩家 z=5；玩家在台下 32 px 间隙时，高于 30 px 碰撞体的头发会画到真实 14 px 实体石台前缘上。
- 修复：只把这两个 HighStep 可见切片的 `z_index` 设为 **6**（高于玩家 z=5）。没有改玩家 z/碰撞/头像/运动、HighStep 位置/`block_size`、纹理 alpha 范围、主桥/RightLedge/守卫绘制，也没有加整矩形遮罩。
- 结果：台下时石材前缘遮住 y284..287 的头发，y≥288 无额外石面；台上时玩家脚底 y274、`is_on_floor()` 成立，y238..273 身体像素与隐藏平台时完全一致；仅 y274..275 约 1 px 鞋底/前缘交叠，属于正常接地。z=6 仍低于世界标签 z=100 与 HUD layer 10，不遮字幕/HUD。
- 专项：`tests/check_art_guide_pass_highstep_z.tscn`，`HIGHSTEP_Z_SUMMARY pass=17 fail=0`，日志 `tests/logs/art_guide_pass_highstep_z_order_20261112.log`。只重出 `screenshots/art_guide_pass_03_level02_under_highstep.png`，台上仅内存像素检查，没有第四/第五张图。
- 保护：HighStep 56×14/底 288、5 条 8 px 真缝、RightLedge 32×24/底 300、玩家 12×30、主桥/守卫 z 序均未变；未复跑 147 项（那是补丁前结果）。

## 第四轮：极性守卫接入上层主桥（2026-11-12）

用户已授权把独立极性石怪原型放入正式第二关上层主桥，并要求以本体颜色辨相、修右端可钻入下层的碰撞缺陷、更新石碑规则页，同时保持既有运输与手感。本轮只做该集成和实际发现的集成 bug，不改第一关、共享玩家/运输/字体/批准美术。

### 实值与接入方式

| 项目 | 实值 / 做法 |
| --- | --- |
| 守卫场景 | 新增 `scenes/enemies/polarity_golem_guard.tscn`，复用 `scripts/experiments/polarity_golem_enemy.gd`，碰撞 20×30 |
| 出生脚点 | (344, 264)，直接站在主桥顶 y=264 |
| 巡逻 | x=260..376，速度 60 px/s |
| 追击/推拉安全范围 | x=244..388（两侧各留约 12 px 半身余量） |
| 平台合法范围 | 主桥 x=232..400、顶 y=264；守卫脚点始终 y=264，不解算重力、不进入低廊/地面/目标仓 |
| 初始相性 | 固定辉相（橙金），正式关没有 Tab 切敌相 |
| 头顶读数 | 保留 3 格血条；默认 `show_polarity_label=false`，不画极性字/符号/菱形/正负号；仅击散等待/重组保留中性倒计时 |
| 玩家攻击 | 第二关 Player 实例覆盖 `polarity_golem_player.gd`；共享 `player.gd`/`player.tscn` 未改 |
| J 输入 | 第二关原始按键 latch，非 echo；按住不连发；设置/暂停/完成页不触发 |
| 暂停右栏 | 新增“挥击守卫 / J” |

守卫参数化只新增少量导出项：`patrol_left/right`、`pursuit_left/right`、`alert_vertical_tolerance`、`attack_vertical_tolerance`、`show_polarity_label`。独立实验场景的默认值仍是原来的 240..520 / 200..536 / y=288，加载实验关不改变原地面布局；只有正式守卫场景覆盖为高台值。`_can_alert_player` 的垂直门限在正式关为 40 px，因此地面玩家与桥面守卫的 56 px 高差不会被当成近战目标；实际拳落框仍只覆盖守卫前方、脚点附近的 26×20 px，并继续受真实身体/地形射线检查。

### 状态、重置与完成

- 3 HP、同相 1 伤害+击退打断、异相牵引无伤且不取消砸击、举臂 0.28 s/有效 0.12 s/收招 0.30 s/间隔 0.15 s 全部沿用原型。
- 击散→die 末个非空帧 11（12 空白）可见→默认等待 8 s→倒放 11..0→原地满血；没有恢复自绘方块碎石。
- `_reset_room_state` 是 L2 的单一重置出口：activate、R、暂停重开、玩家坠落、核越界都会同步恢复守卫出生点/相性/HP/ACTIVE AI，取消在途砸击/牵引/击退/击散计时，并清除玩家挥击与受击保护；J latch 同时清空。
- 暂停使用现有共享暂停页与 tree pause；守卫节点显式 PAUSABLE，AI/砸击计时/等待计时随之冻结。窗口失焦额外 `set_ai_suspended(true)` 并清 J latch，失焦回来再解冻。
- 完成页调用 `freeze_for_completion()` 与 `lock_completion_input()`：停守卫、取消玩家挥击、结束受击反应并保持输入锁；受击反应结束不会再 `end_input_override()`，J 也不能穿透完成页。

### 右端可钻入下层缺陷（已修）

`RightLedge` 原为 `position(400,276)`、`block_size(32,10)`，底 y=286，与地面 y=320 净高 34 px，30 px 高的玩家可从右侧钻入下层。最小修正为 **`block_size(32,24)`，底 y=300**，与已批准右短台饰面下沿一致；下廊净高变为 20 px，16 px 高的星核仍可右出/回收，玩家 12×30 不能进入。未封整条下廊、未改角色尺寸、未关闭射线或改批准纹理。

### 石碑与标签

- 只改 `level_02.tscn` 上 `StartStele.pages` 实例数据，共享碑组件/美术未改。现为 6 个短页（每页 2~3 行、原生 12 px），覆盖：E 释放取相反相性；核下廊/人走桥、五处真缝施力与实体遮挡；橙金=辉相、青蓝=澜相，用颜色识别守卫；J 同相扣血击退打断、异相牵引无伤且不取消砸击；举臂后迅速砸下可跳开/绕背；击散只暂离约 8 秒后原地重组；右侧拉核 E 入仓→出口。没有写“必须击杀”或“自动入仓”。
- 为避让守卫血条（约 y=208..214），仅把世界标签 `CorridorLabel`/`UpperLabel` 从 y=212..224 上移到 **y=188..200**；水平位置、文案、字体、颜色不变。HUD 相性/血条/运输提示未删改。

### 本轮验证（只跑相关节点，未跑旧大套/第三关）

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/test_level02_guard.tscn
```

实际结果：`TEST_SUMMARY pass=119 fail=0`，`RESULT: PASS`。覆盖：

1. 正式关/实验关真实载入；守卫出生、3 HP、橙/蓝两相颜色与贴图、头顶无极性字、血条存在、实验调试 HUD 仍可诊断。
2. 四秒真实巡逻不越 260..376、脚点始终 y=264，不落到 288/420；地面玩家 56 px 下方不触发砸击，强制举臂也只能 BLOCKED/MISS。
3. 真实 J latch/echo；同相扣 1 HP+击退并打断举臂；异相零伤害、牵引一次且不取消砸击；真实 Q 切玩家相。
4. 右短台 32×24、净高 20；步行/奔跑/跳入均被真实碰撞挡住，核被同相力场推出并可反向拉回；上层真实 8 px 缝仍通过吸引射线并让核移动，实体梁仍遮挡。
5. 击散等待 die 11、8.0 秒中性倒计时；Esc 冻结等待；R 真键恢复守卫/玩家/攻击/保护；暂停中 R、玩家坠落、核越界三条重置路径也分别恢复守卫与玩家。
6. 一条带明确 setup 的局部集成路径：setup 核已过左喉 `(343,312)`、玩家 `(142,320)`，目标仓仍 EMPTY；随后真实跳上主桥、与守卫真实 J 交战、右侧下台、100 px 力场拉核、真实 E 入仓、真实出口完成。完成页 J 无效、守卫冻结、受击结束不解除输入锁；之后真实 R 恢复。
7. 该路径不是从出生点重跑全程，也没有在关键断言前改核/仓/出口结果；日志 `tests/logs/level02_guard_test.log`、`tests/logs/level02_guard_stdout.log`。

真实 GUI（脚本定帧，非人工连续试玩；仅两张）：

```text
D:\Godot\Godot_v4.7.2-stable_win64.exe --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/capture_level02_guard.tscn
```

- `screenshots/level02_guard_01_bridge.png`：主桥守卫、橙金本体、3 格血条；标签 y=188..200 与血条 y=208 不互盖；头顶无极性字。
- `screenshots/level02_guard_02_stele_rules.png`：石碑第 3/6 页，原生 12 px、三行短句，显示橙金/青蓝辨相与 J 同相规则。
- 日志 `tests/logs/level02_guard_capture.log`、`tests/logs/level02_guard_capture_stdout.log`。

### 文件清单（本轮）

修改：

```text
scenes/level_02.tscn                              (守卫实例、Player 攻击子类、RightLedge 32x24、碑 pages、两标签 y188..200)
scripts/level_02.gd                               (守卫/攻击/重置/暂停/失焦/完成集成)
scripts/level_02_hud.gd                           (仅 controls 文案加入 J)
scripts/experiments/polarity_golem_enemy.gd       (巡逻/追击/垂直门限参数化、suspend/完成冻结、头顶标签开关)
scripts/experiments/polarity_golem_player.gd      (完成输入硬锁、受击结束不解锁)
```

新增：

```text
scenes/enemies/polarity_golem_guard.tscn
tests/test_level02_guard.gd / .tscn
tests/test_level02_guard_stele_reset.gd / .tscn
tests/capture_level02_guard.gd / .tscn
tests/logs/level02_guard_test.log
tests/logs/level02_guard_stdout.log
tests/logs/level02_guard_stele_reset_test.log
tests/logs/level02_guard_stele_reset_stdout.log
tests/logs/level02_guard_capture.log
tests/logs/level02_guard_capture_stdout.log
tests/logs/level02_guard_protection.json
screenshots/level02_guard_01_bridge.png
screenshots/level02_guard_02_stele_rules.png
```

未改：第一关 scene/script、共享 `scripts/player.gd`/`scenes/player.tscn`、`project.godot`、运输/仓/核/碑/出口/暂停/显示脚本、字体、批准平台美术、源素材、旧 main/F7/截图归档。独立实验场景未改；因其敌人头顶默认已改 false，旧的“头顶显示辉相 +”断言若重跑需按最新要求更新，本轮未重跑旧套。

### 完成态石碑恢复补丁（2026-11-12）

审查发现：完成页为防 F 穿透调用 `_stele.set_suspended(true)`，但共用重置出口 `_reset_room_state` 原先没有恢复 `set_suspended(false)`。共享 `TutorialStele.on_player_reset` 在挂起时会直接 return，因此完成页按 R 重玩后石碑会永久保持挂起，回到起点靠近 x=80 也无法阅读。

最小修复：在 `Level02._reset_room_state()` 中、调用 `super` 之后增加 null 安全的 `_stele.set_suspended(false)`。所有正式关重置路径（activate、R、暂停重开、玩家坠落、核越界）都经过该函数，所以只需这一处；共享石碑脚本/场景未改。

专项回归：新增 `tests/test_level02_guard_stele_reset.gd/.tscn`，只跑该测试，不重跑 119 项或旧套。
- setup 明确：通过目标仓自身公开 API `start_store_core(true)+finish_store()` 预锁目标仓，使玩家到出口即可触达真实完成门；之后是真实完成页、真实 R 键、真实走路与真实 F 键。
- 覆盖：完成态石碑挂起且 F 不翻页/不出提示 → 真实 R 后 `suspended=false` → 走回 x=80 自动显示第 1 页 → 真实 F 只翻到第 2 页。
- 实际结果：`TEST_SUMMARY pass=13 fail=0`，`RESULT: PASS`。
- 日志：`tests/logs/level02_guard_stele_reset_test.log`、`tests/logs/level02_guard_stele_reset_stdout.log`。未生成新截图。

### 未验证 / 保留风险

- 没有人工连续试玩；两张 GUI 是脚本定帧。守卫手感（在窄桥上同时运输是否过难）仍需用户实机确认。
- 没有重跑旧 104/84/31/448 大套或第三关；本轮仅相关 119 项与两张图。
- 守卫仍无碰撞阻挡（`collision_layer=0`），与原型一致；它靠真实拳落框/射线判定，不靠身体推挤。
- 低廊 20 px 净高与核 16 px 的通行窗口很窄，运输仍需玩家在右侧对准；这是已批准几何，本轮未放宽。

第三轮历史：2026-11-05。状态：**V3 连续顶缘/双大拱桥身/统一端部视觉已接入本关；旧褐色 atlas 绘制在本关关闭，真实碰撞/缝/力场/运输参数未改。headless 448/0，GUI V3 八帧＋修后标签单帧与受控引擎平台渲染已出。** 下文“第二轮/初版灰盒”段落保留为历史记录；与其冲突的视觉和证据，以本轮及第二轮实际尺寸为准。

## 第三轮：V3 平台视觉接入（2026-11-05）

用户已批准 `自制素材/第二关平台完整造型预览_V3/` 的连续顶缘、双大拱桥身、统一端部方案，并要求接入实际第二关、验证原运输闭环/缝处施力/行走跳跃/核通路不受影响。本轮只做本关视觉接入和必要引导文案修正，不另改美术或玩法。

### 实际接入方式

- 批准源只读：`自制素材/第二关平台完整造型预览_V3/layer_platform_visual_640.png`（SHA-256 `EE8D38E3…CB04290`）与 `layer_platform_decor_640.png`（`58C58508…52A0…`）。运行副本逐字节复制到 `assets/level02_platform_v3/`；源文件未改。
- 不把整张带背景/人物/地面的预览叠进游戏。两个批准图层按原坐标裁切成 5 个非碰撞 `Sprite2D`，通过 `AtlasTexture.region` 直接引用图层，Nearest、scale 1、白 modulate、`centered = false`。

| 节点 | 父节点 | 世界矩形 | 图层区域 |
| --- | --- | --- | --- |
| `V3PlatformVisual` | `UpperDeck` | x232..399, y264..299 | visual `Rect2(232,264,168,36)` |
| `V3PlatformDecor` | `UpperDeck` | x232..399, y264..299 | decor `Rect2(232,264,168,36)` |
| `V3PlatformVisual` | `HighStep` | x152..207, y274..299 | visual `Rect2(152,274,56,26)` |
| `V3PlatformDecor` | `HighStep` | x152..207, y274..299 | decor `Rect2(152,274,56,26)` |
| `V3PlatformVisual` | `RightLedge` | x400..431, y276..299 | visual `Rect2(400,276,32,24)` |

- 左高台视觉跟 `HighStep` 整根节点、右短台视觉跟 `RightLedge` 整根节点；主桥视觉跟 `UpperDeck` 整体。**不是**每块梁自动生成桥身：移动/缩放单根 `DeckBeam*`/`WalkBeam*` 不会自动重排桥身纹理；改主桥几何时须同时调整 `AtlasTexture.region` 与 `UpperDeck` 下视觉位置（或重新按批准图切片），不能只改碰撞就声称视觉会自动匹配。
- `scripts/level02_block.gd` 只新增本关开关 `legacy_art_enabled`（默认 `true` 保持旧行为），`level_02.tscn` 的 11 个原 `Level02Block` 全部设 `false`。这不是隐藏 physics 节点：节点、`CollisionShape2D`、尺寸、位置、层、射线遮挡都原样参与物理与测试；仅停止旧褐色 atlas 的 `_draw`。编辑器辅助轮廓线仍由脚本在编辑器绘制，但不透明 V3 切片覆盖处可能遮住它；编辑器里以 V3 切片和节点变换/Inspector 为准。
- 没有给任何装饰加碰撞，没有改 `TerrainTop`/`TerrainFill` 属性或图源，没有改地面、背景、玩家、核、仓、出口、碑、共享脚本、`project.godot` 或字体。
- 5 条 1px 嵌缝由批准 decor 层提供，是视觉提示，不是新洞；真实 8×6 缝仍在原坐标，8px 缝仍小于 12px 玩家/核，未发现也不会通过视觉接入产生新的掉落。
- 所有新增视觉像素在 y≤299；核通路 y300..319 与地面 y≥320 不被覆盖；208..232 跳跃空隙保持空。核对方式：headless 资源/几何/射线测试 + 受控引擎平台-only 渲染。

### 引导文案与上层标签布局（小修，不重做系统）

- `UpperLabel` 改为“嵌缝可施力 · 实体段遮挡”，不再写“上层石栅 · 缝隙可施力”。
- 说明碑第 2 页改为“低廊只容星核通过，人要走上层桥面。桥面五处嵌缝可施力，实体石段会遮挡。”
- 协调者检查发现原 `UpperLabel`/`CorridorLabel` 的 y246..258 会以 z100 穿过站在上层的人物躯干；本轮只做标签布局修复：两标签改为 **y212..224**，水平位置、文案、字体、颜色全部保留。人物站立头部约 y229，标签底 224 留约 5px 间隙。
- 没有移平台、改碰撞、改美术或其他 UI；没有新增巨大 HUD、F3 强制常开、世界亮线或新发光。
- 连续桥面仍可能让玩家不易看出施力位置，这是本轮明确保留的待试玩风险，不是已解决。

### 本轮验证

- 运行前置：新增 PNG 后先执行一次 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`，避免引擎缓存仍指向旧导入；本轮导入日志 `tests/logs/level02_v3_import.log`。
- Headless 主套件：`TEST_SUMMARY pass=448 fail=0`，`RESULT: PASS`。保留了原几何/射线/两相作用/实体阻挡/100px 范围/复制隔离/E/R/暂停/失焦/完整真实输入闭环；仅更新过期视觉断言，并新增 V3 资源、父节点、scale/Nearest/白 modulate、无碰撞、旧图关闭、视觉覆盖真缝但射线仍穿缝/实体仍阻挡、地面属性与原文件哈希一致、两枚上层标签不与站立人物矩形交叠等检查。日志：
  - `tests/logs/level02_v3_test_stdout.log`（本轮独立 stdout）
  - `tests/logs/level02_v3_test.log`（与固定 `level02_textured_test.log` 同内容的版本化副本）
  - `tests/logs/level02_textured_test.log`（主套件固定路径，已被本轮运行写入）
- 真实上层 24 帧数据仍成立：core 343.17→364.14（+20.97），player 383.27→382.78，未落缝；同相 REPEL 264.00→241.86，异相 ATTRACT 264.00→273.56。
- GUI 真实引擎 640×360，脚本定帧（非人工连续试玩）：
  - `screenshots/level02_v3_01_start.png`
  - `screenshots/level02_v3_02_jump_face.png`（人物在新增高台饰面前起跳，正常帧）
  - `screenshots/level02_v3_02b_under_step.png`（人物在地面走到高台下方，检查视觉/碰撞垂直差）
  - `screenshots/level02_v3_03_upper_seam.png`（修前干净帧；保留为标签布局修复前证据）
  - `screenshots/level02_v3_03_upper_seam_labels_fixed.png`（修后干净帧：两标签 y212..224，人物躯干不再被文字穿过）
  - `screenshots/level02_v3_04_upper_seam_debug.png`（同位置既有 F3 调试射线/力向，仅供证据）
  - `screenshots/level02_v3_05_target.png`
  - `screenshots/level02_v3_06_stored.png`
  - `screenshots/level02_v3_07_complete.png`
  - `screenshots/MANIFEST_LEVEL02_V3.txt`、`tests/logs/level02_v3_capture.log`、`tests/logs/level02_v3_gui_stdout.log`
  - 修后标签帧另有 `screenshots/MANIFEST_LEVEL02_V3_LABELS_FIXED.txt`、`tests/logs/level02_v3_labels_fixed_capture.log`、`tests/logs/level02_v3_labels_fixed_gui_stdout.log`
  - 路线仍为真实 InputMap/按键：出生→E 释放→Q 同相推过低廊→跳高台/主桥→缝处推/拉核→右侧拉核→E 入仓→人到出口→同实例完成；最终 `completed=true count=1 core_x=520.0`。
- 受控引擎渲染（`tests/test_level02_v3_visual.gd`）：在生产场景实例里只隐藏本测试的非平台视觉，640×360 透明 SubViewport 输出平台+decor；与批准两层精确 alpha 合成参考逐像素一致（`mismatch=0`，6 个半透明像素按透明背景回读的预乘编码解码；`semi=6`）。日志/报告 `tests/logs/level02_v3_visual_render.log`、`.json`；图 `screenshots/level02_v3_platform_only_render.png`（直通 alpha 便于查看）与 `_raw.png`（引擎预乘回读原样）。
- 保护：`before.json` 的 142 个脚本/场景/资源/`project.godot` 中，仅允许的 `scenes/level_02.tscn`、`scripts/level02_block.gd` 变化；`scripts/level_02.gd`、地面两节点、原 atlas、V3 原稿均未改。新增文件单列。`tests/logs/level02_v3_scene_geometry.json` 另核所有物理字段不变，仅允许 `StartStele.pages`、`UpperLabel.text` 及两标签 `offset_top/bottom` 变化。

### 已知风险 / 未验证

- **连续视觉掩盖施力位置**：物理仍是 5 个 8px 真缝、6px 梁，玩家可站窗口约 4~6px；视觉只在缝中心留 1px 嵌缝。玩家可能不知道“站哪里”或误以为整段桥面都能施力；HUD 的 BLOCKED/ATTRACT/REPEL 与碑页能帮助发现，但未做人工试玩证明足够。若试玩后仍不足，应由用户决定是否调整提示/美术，不擅自放宽遮挡或加新发光。
- 8px 缝本身不是本轮新增掉落风险；原版已测 12px 玩家不会落入。不能把“视觉盖住缝”误报成新出现的物理漏洞。
- **高台/右短台视觉与薄碰撞的垂直差**：批准图把左高台立面画到 y299、右短台整合到 y299，但真实碰撞底仍是 y288 / y286。玩家在地面从下方走到廊口时物理可通过（高台底到地面净空 32px，玩家 30px），但批准视觉把可见净空压到约 20px，人物上半身会与立面下半部重叠；因为平台在人物后绘制，画面上是人物挡在立面之前，而不是被石体遮住。GUI 帧 `level02_v3_02b_under_step.png` 已看到此现象。未加碰撞掩盖；若用户认为观感不可接受，需要由用户决定是否改批准高台/右短台切片的垂直范围或构图，不能靠新增碰撞或改通行规则解决。
- GUI 为脚本定帧，不是人工连续试玩；未独立打开用户编辑器 UI 验证“编辑器所见”，但场景/资源在 headless 载入和 GUI 实际渲染无脚本错误。主桥单梁重排不会自动生成新桥身，见上文编辑边界。
- 仍无战斗/自动入座/跨关/正式音效/存档；第一关/菜单/F5/F7/共享运输参数未改。

## 本轮修订（2026-11-05，第二轮）

用户要求：①灰盒示意色块换实际地形贴图；②上层高度须使人物极性能够影响下方星核；③目标仓移近出口。用户明确选择“真实镂空通路”，不是取消遮挡或特殊透力楼板。

### 实际几何（本轮）

| 项目 | 值 |
| --- | --- |
| 逻辑视口 | 640 × 360，地面顶 y = 320 |
| 下层低廊 | x = 232 .. 304（含两侧实体墩）；喉部 y = 300 .. 320，净高 20 px |
| 低廊入口/出口实体墩 | 各 8 × 36 px，x = 232..240 / 296..304，y = 264..300 |
| 低廊中间开放截面 | x = 240..296，y = 270..320，净高 50 px（真实开放，但玩家无法从地面进入） |
| 上层石栅 | 顶 y = 264，梁厚 6 px，x = 232..400 |
| 真实石缝 | 宽 8 px，位于 x = 256..264、280..288、320..328、344..352、368..376；缝高 6 px |
| 高位短台阶 | x = 152..208，顶 y = 274，底 y = 288，56 × 14 px（贴图边缘裁切，未缩放） |
| 右侧下行台 | x = 400..432，顶 y = 276，底 y = 286，32 × 10 px |
| 起始仓 | (118, 304)，座心 (118, 312)（未改） |
| 目标仓 | (520, 304)，座心 (520, 312)；标签同步居中于 x = 520 |
| 出口 | (600, 320)，沿用 36 × 76 触发区（未改） |
| 出生/释放 | 出生 (36, 320)；核释放远侧 40 px、clamp 16..624（未改） |

### 地形贴图

- 第二轮曾把 11 个 `Level02Block` 统一改为旧 `assets/map/ruin_platform_tiles.png`（16 px tile、Nearest、白 modulate、非 16 尺寸只裁切不缩放）。第三轮 V3 接入后，这些区块仍保留 atlas 路径/尺寸元数据，但 `legacy_art_enabled=false`，运行时不绘制旧褐色图；可见平台改由上述 5 个批准 V3 非碰撞 Sprite2D 切片绘制。
- 石缝仍是分段节点之间的真实空节点，不是整张 PNG 覆盖。物理竖向射线：5 个缝中心无碰撞；实体墩/梁中心有碰撞。V3 连续顶面只隐藏视觉，不关闭这条射线或实体遮挡。

### 上层作用与可用站位

- 力场参数未改：100 px 范围、40 px 内零力、64 px 满力、18 px 外缘渐弱；620/300 双向加速度；核限速 120、地面阻尼 420；射线 mask 仍为 1；接地水平投影仍保留。
- 上层顶 264 → 玩家中心 249，核中心 312，垂直差 63 px。模拟布置扫描得到的可用站位（仅布置是模拟，力场/射线/载体物理是真实房间）：
  - core 248 / player 268，dist 66.1，force x ≈ -187.6
  - core 264 / player 294，dist 69.8，force x ≈ -266.6
  - core 272 / player 292，dist 66.1，force x ≈ -187.6
  - core 304 / player 334，dist 69.8，force x ≈ -266.6
  - core 312 / player 332，dist 66.1，force x ≈ -187.6
  - core 328 / player 358，dist 69.8，force x ≈ -266.6
- 6 px 梁 + 8 px 缝的站立窗口约 4~6 px（dx≈20~40），不是 36~40 px 厚竖缝的像素级窗口；但仍需在缝旁停稳，未加自动吸附。第三轮 V3 连续桥面把真缝视觉盖住，只留 1px 嵌缝；物理窗口与 4~6 px 结论未变，不能把视觉连续误当作力场变宽或可任意站。
- 同相 REPEL（核从静止开始）：core 264.00 → 241.86，24 帧，live force_x 最小 -347.6；异相 ATTRACT：core 264.00 → 273.56，live force_x 最大 +245.1。两者玩家均保持 y≈264、站在梁上。
- 实体段（player/core 正上方 x=310）仍 `BLOCKED`，20 帧核位移 0；距离 >100 px 仍 `OUT OF RANGE`，加速度精确为 0，核不移动。
- 正上方水平分量为 0 是原接地投影规则，本轮没有改公式；上述站位都带水平偏移。

### 目标仓与完整路线

- 目标仓从 372 移到 520；出口保持 600。玩家在右侧距仓 46 px 内拉核、E 入仓；入仓后玩家仍在仓旁，不会一接核就自动到出口。
- 真实完整路线（headless 与 GUI 都走通）：出生 → x≈100 按 E 释放 → Q 同相 → 推核穿过 20 px 喉部到 x≈312.5，惯性停到 x≈343 → 退回 x≈142 → 跳高台 274 → 跳上层石栅 264 → Q 异相 → 沿石栅走到缝上（player≈383, core≈343, dist≈74.7）→ 缝处真实水平力把核推/拉到 ≈364 → 走到右端 → 落到地面 x≥432 → 分段右拉核到 520 → E 入仓锁定 → 走 600 出口完成 → R 恢复。
- 主线记录：t≈20.8 s，player (383.3, 263.9)，core (343.2, 311.9)，force=(+332.9, -523.0)，blocked=false，grounded=true；24 帧核 343.2→364.1（+20.9），玩家未落缝。
- 先到出口未入仓只提示、不完成；取核后出口恢复未就绪；重新入仓后再完成并锁定。R/暂停/失焦/出界/复制隔离等原覆盖保留。

### 本轮验收

> 以下为 2026-11-05 第二轮历史证据；第三轮 V3 的最新计数与图片见本文顶部，不要把 355/0 当作 V3 验证。

- Headless：`TEST_SUMMARY pass=355 fail=0`。日志：
  - `tests/logs/level02_textured_test.log`
  - `tests/logs/level02_textured_test_stdout.log`
- GUI：真实 Windows 引擎 640×360 五帧：
  - `screenshots/level02_textured_01_start.png`
  - `screenshots/level02_textured_02_upper_gap.png`
  - `screenshots/level02_textured_03_target.png`
  - `screenshots/level02_textured_04_stored.png`
  - `screenshots/level02_textured_05_complete.png`
  - `screenshots/MANIFEST_LEVEL02_TEXTURED.txt`
  - `tests/logs/level02_textured_capture.log`、`tests/logs/level02_textured_gui_stdout.log`
- 上层帧临时开启既有 player debug field 覆盖层显示射线/力向，未改物理；其余帧关闭。所有图是脚本定帧，不是人工连续试玩。
- 共享文件保护：138 项 SHA-256 全部一致，`changed=0`、`pass=true`；报告 `tests/logs/level02_textured_protection.json` / `.log`。

### 未验证 / 建议

- 未验证人工连续手感、美感认可、音效、手柄/触屏、正式长关卡/多屏；GUI 是脚本定帧，不能替代用户试玩。
- 8 px 缝的站立窗口约 4~6 px，需在缝旁停稳；若用户觉得偏窄，最小几何调整是把石梁厚度 6→4 px（窗口约再宽 1.5 px），不建议把缝加宽到 ≥12 px（玩家支撑会只剩约 1 px/侧）。未在冻结的 100/620/300/120/420/接地投影/射线 mask 上做任何改动。
- 没有战斗、守卫、自动入座、跨关、正式第二关美术、音效/存档。

## 入口与操作

- 入口场景：`scenes/level_02.tscn`。在 Godot 中打开该场景按 F6，或
  `Godot_v4.7.2-stable_win64.exe --path 基础场景原型 res://scenes/level_02.tscn`。
- 默认出生点：`(36, 320)`，玩家初始为辉相（+）。
- 操作：`A/D` 或方向键移动，左 `Shift` 奔跑，`空格` 跳跃，`Q` 切换相性，
  `E` 释放/入仓，`F` 阅读说明碑，`R` 重来，`Esc` 暂停。
- 单屏 640×360，固定相机，世界原点 0。没有复制第一关菜单、2.2 秒移镜或英文 F4 调试面板。

## 初版实际尺寸（历史，已被上一节替换）

| 项目 | 值 |
| --- | --- |
| 逻辑视口 | 640 × 360 |
| 地面/楼板顶 | y = 320 |
| 低廊天花板底 | y = 300 |
| 低廊净高 | 20 px（核 12×16，玩家 12×30） |
| 低廊长度 | x = 232 .. 296，64 px |
| 起始仓节点 | (118, 304)，座心 (118, 312) |
| 目标仓节点 | (372, 304)，座心 (372, 312) |
| 高位短台阶 | x = 152 .. 208，顶 y = 274，底 y = 288（下方可走人） |
| 上层通路顶 | y = 240，x = 232 .. 400（低廊上方 + 右侧高架） |
| 右侧下行台 | x = 400 .. 432，顶 y = 276（可从上落下，也可从下方走过） |
| 出口 | (600, 320)，沿用 `LevelExit` 的 36×76 触发区 |
| 核心硬边界 | x = 4 .. 636，kill_y = 380（共享默认，未改） |
| 玩家世界边界 | x = 6 .. 634，kill_y = 400 |

尺寸是可解性优先的紧凑灰盒，不是最终关卡长度或示意图像素比例。左侧推行极限实测到 x≈226（被低廊天花板挡住），核在 x≈312.5 时已完整通过 64 px 低廊；右侧玩家从 x≈404 的 100 px 力场边缘可以把核拉回座位。

## 完整解法（真实输入路线）

1. 从出生点向右走到起始仓附近（x≈100），按 `E` 开罩释放星核。释放快照取按 E 时玩家的相反相性（默认辉相玩家 → 澜相核）；开罩中按 `Q` 只改玩家，不改快照。
2. 按 `Q` 到与核同相，按住右方向把核推过下方 64 px 低廊。玩家会被 20 px 净高的天花板挡在廊口，核 16 px 高可以通过；地形射线遮挡与接地水平投影保持共享实现。
3. 玩家退回左侧，跳上高位短台阶（顶 y=274），再跳上上层通路（顶 y=240）。高位台阶悬空，底部 y=288，玩家可以从下方走到廊口，不会被台阶提前挡住。
4. 沿上层通路走到右侧，从 x≈400 下落/下台阶到地面。在右侧按 `Q` 切到与核异相，利用 100 px 吸引把核拉进目标仓座位。
5. 玩家—仓 46 px、玩家—核 80 px、核在座位 ±24×18 px 内时按 `E` 入仓。没有自动捕获；核在座位停留不会自动入座。
6. 目标仓锁定后才可以用本关出口门控完成。若先把核从目标仓取出，出口立即恢复“未就绪”；重新入仓并锁定后再到出口才会完成。
7. `R` 回到出生点、恢复辉相、起始仓锁核/目标仓空开、清完成和记录。`Esc` 暂停冻结物理/罩动画/背景，失焦清输入。

## 机制参数（未改共享实现）

- 力场：100 px 范围、40 px 内零力稳定区、64 px 满力、18 px 外缘渐弱。
- 双向加速度：核 620、玩家 300；核限速 120、地面阻尼 420、重力 1100。
- 入仓：玩家—仓 46 px、玩家—核 80 px、核座位 ±24×18 px；仅 `E` 接受，无速度门槛、无自动捕获。
- 释放：远侧 40 px、初速 0、0.25 s 罩动画、快照为玩家相反相性；开罩中 Q 不改核。
- 玩家：移动 100/160，跳跃初速 -375，重力 1100；碰撞 12×30。
- 核碰撞 12×16；玩家与核互不推挤（共享 collision exception）。

## 验收证据

### Headless 真实输入验收（历史 195 项，已被本轮 355 项替换）

命令：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_level_02.tscn
```

结果：`TEST_SUMMARY pass=195 fail=0`，`RESULT: PASS`。日志：

- `tests/logs/level02_headless.log`
- `tests/logs/level_02_test.log`（测试脚本自身写出的同一轮日志）

覆盖点包括：默认真实出生；真实 E 释放（快照相反相性）；开罩中 Q；同相推行；核 x 158.3→312.5、y≈311.9 的真实穿廊；玩家 x≤226 的真实碰撞阻挡；真实跳上高位台阶和上层；上层可行走；低廊天花板射线遮挡；右侧异相吸引；核在座位 4 帧无自动捕获；E 三方范围入仓；目标仓锁定/记录；出口先到不完成；取核后出口恢复未就绪；重新入仓；到出口才完成；R 完成中/开罩中/合罩中；暂停冻结物理与罩；失焦清 Shift/双击；核出界恢复；碑重入页 0。

### GUI 真实引擎截图（历史灰盒四帧，已被本轮五帧替换）

命令（GUI 可执行文件，无 `_console`）：

```
D:\Godot\Godot_v4.7.2-stable_win64.exe --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_level_02.tscn
```

结果：`Capture level 02` 输出 `CAPTURED ... size=(640, 360)` 四次，最终 `completed=true count=1 core_x=372.0`。这是脚本定帧，不是人工连续试玩，也不是自动跑到目标的演出。路线本身使用真实 InputMap/真实按键，没有传送、测试力或直接调用完成/入仓。

- `screenshots/level02_01_start.png`：起点、起始仓、说明碑、中文 HUD；明确使用 DS03 背景与现有仓/碑/地砖/出口图作临时灰盒美术。
- `screenshots/level02_02_split.png`：核已过下方低廊，玩家在真实上层通路。
- `screenshots/level02_03_target.png`：核在右侧目标座位，玩家在 46 px 内，中文“E 可入仓（目标座）”提示。
- `screenshots/level02_04_complete.png`：目标仓锁定、玩家在出口、“第二关完成”面板。
- `screenshots/MANIFEST_LEVEL02.txt`
- `tests/logs/level02_capture.log`
- `tests/logs/level02_gui_stdout.log`
- `tests/logs/level02_editor_load.log`（headless 编辑器静态载入 `scenes/level_02.tscn`，无场景/脚本错误；不宣称已做 GUI 拖拽验证）

补充：本轮 HUD 修正后未重跑 GUI 截图（按协调者要求）。现有 `level02_04_complete.png` 的完成帧仍保留补丁前的 `(CYAN -)` 记录文本；本轮 headless 断言已确认代码现在显示“星核：目标仓（澜相）”。截图其余几何/路线内容未变。

### 共享文件保护（历史基线；本轮 138 项见上一节）

基线：`C:\Users\aqiqiqi\AppData\Local\Temp\opencode\level02-greybox-44b74ba93d654b0b801ee3993608cebc\protected.json`。

核对结果：138 项全部存在、SHA-256 一致，`changed=0`、`missing=0`、`pass=true`。报告：

- `tests/logs/level02_protection.json`
- `tests/logs/level02_protection.log`

没有修改 `project.godot`、`scenes/main.tscn`、`scenes/level_01.tscn`、第一关脚本、共享核/仓/玩家/符石/碑/出口脚本、菜单/显示设置，也没有覆盖任何既有 PNG 或源图。

## 文件清单

第三轮 V3 新增：

- `assets/level02_platform_v3/layer_platform_visual_640.png`（批准层逐字节副本）
- `assets/level02_platform_v3/layer_platform_decor_640.png`（批准层逐字节副本）
- `assets/level02_platform_v3/level02_v3_platform_expected.png`（两层精确 alpha 合成，仅验证用）
- `assets/level02_platform_v3/manifest.json`
- `tests/capture_level02_v3.gd` / `.tscn`
- `tests/capture_level02_v3_labels_fixed.gd` / `.tscn`
- `tests/test_level02_v3_visual.gd` / `.tscn`
- `screenshots/level02_v3_*.png` 八帧、`screenshots/level02_v3_03_upper_seam_labels_fixed.png`、`screenshots/MANIFEST_LEVEL02_V3.txt`、`screenshots/MANIFEST_LEVEL02_V3_LABELS_FIXED.txt`
- `screenshots/level02_v3_platform_only_render.png` / `_raw.png`
- `tests/logs/level02_v3_*`

第三轮修改：

- `scenes/level_02.tscn`（V3 Sprite2D 切片、11 个 Block 的 `legacy_art_enabled=false`、两处引导文案、两枚上层标签 y246..258→y212..224）
- `scripts/level02_block.gd`（仅新增默认 true 的本关旧图开关与绘制拆分；纯注释纠正“empty gaps”）
- `tests/test_level_02.gd`（仅更新过期视觉断言并新增 V3/标签交叠检查；玩法路径未改）
- `docs/LEVEL02_EDITING.md`

未改：`scripts/level_02.gd`、`TerrainTop`/`TerrainFill` 属性与图源、原 11 块碰撞、共享核/仓/玩家/碑/出口脚本、背景、第一关、菜单、`project.godot`、字体、所有既有源 PNG。

第二轮及更早新增：

- `scenes/level_02.tscn`
- `scripts/level_02.gd`
- `scripts/level_02_hud.gd`
- `scripts/level02_block.gd`
- `tests/test_level_02.gd`
- `tests/test_level_02.tscn`
- `tests/capture_level_02.gd`
- `tests/capture_level_02.tscn`
- `docs/LEVEL02_EDITING.md`
- 上述截图、manifest、日志、保护报告

`Godot.uid` / `.import` 自动生成的新增文件属于正常导入副产物；未改写既有资源。

### 交付前一致性补丁（2026-11-05）

- `Level02Block._ensure_collision_node()` 现在会校验缓存的 `CollisionShape2D` 是否真是本 Block 的子节点；编辑器 `duplicate()` 复制出的 Block 不会再操作原块的子节点。
- `_refresh_collision()` 在写入尺寸前 `duplicate()` 现有 `RectangleShape2D` 并设 `resource_local_to_scene = true`，每个 Block 拥有独立 shape；只在 ready/属性变更时执行，不逐帧重建。
- 新增 `get_collision_top_left()` 供“图与碰撞同源”断言；测试实际 `duplicate()` `CorridorCeiling`，改副本尺寸后断言原块 shape 对象/尺寸/位置不变、副本碰撞跟随。
- `get_corridor_rect()` / `get_upper_platform_rect()` 改为从 `CorridorCeiling` 与 `TerrainBody` 真实节点推导；测试临时移动天花板 16 px 再恢复，初始仍为 64×20 / 64×60。
- 目标仓锁定时 HUD 将共享记录映射为中文“辉相/澜相”；开罩阶段按 `_release_bay` 显示“起始仓/目标仓”，不改共享记录逻辑或字体。

## 未实装 / 未验证边界

- 没有战斗、守卫、敌人、攻击系统；上层守卫位置留空。
- 没有自动入座、核导航、拾取/绑定/投掷、隐形推力、固定符石联动新谜题。
- 没有跨关切换；F5/第一关出口不衔接本关；未改 `project.godot` 主场景。
- 没有正式第二关美术；DS03 背景、现有仓/碑/地砖/出口图是临时灰盒复用。
- 没有音效/配音、手柄/触屏适配、正式关卡长度、相机跟随或存档。
- GUI 截图是脚本定帧；真实键盘的完整人工连续试玩仍建议由协调者用 F6 走一遍确认手感。
- 当前只验证了 640×360 单屏紧凑灰盒；不是最终示意图比例，也未验证更长走廊/多屏版本。
- `R` 在“合罩中”的边界用隔离状态设置覆盖（不是主路线重复跑第三次），日志中已明确标注；主路线本身仍是真实输入。
