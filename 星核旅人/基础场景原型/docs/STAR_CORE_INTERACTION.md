# 星核仓 + 星核交互原型（单屏沙盒）

更新日期：2026-10-31。本文说明当前可试玩版本、入口、规则、可调参数、实际测试与边界。

> **状态：可试玩的交互原型，不是正式谜题/关卡，也不是最终美术定稿。**
> 本轮只验证“释放 → 异极拉行 → 手动 E 入仓 → 再释放回运”的小闭环；不做门、三关、锚点新组合、搬运/投掷、极性转换机关。

## 1. 入口与按键

默认主场景按 **F4** 进入/退出独立交互房；基础房顶部提示已加入 **F4: CORE BAY**。**F2** 仍是原单锚点借力房。两房互切会关闭对方地板碰撞、核心物理和外力。

| 按键 | 交互房功能 |
|---|---|
| `A/D` 或方向键 | 走（沿用原 100 px/s）；左 Shift + 方向为 160 px/s |
| `Space` | 跳（沿用 -375） |
| `E` | 靠近有核仓：释放；玩家近空仓、活动核也近玩家且在该仓小座位内：**STORE**；否则不动作并显示原因 |
| `Q` | 只切玩家自身极性；开罩中按 Q 不改已快照的核 |
| `R` | 全房恢复：起始仓锁定紫核、目标仓空开、活动核隐藏、玩家回出生点、GOLD |
| `Esc` | 暂停；物理和罩动画一起冻结 |
| `F3` | 显示作用范围、中心连线、力箭头和空仓小座位区 |
| `F2` | 切到原锚点借力房（先清理交互房） |
| `F4` | 切回基础房 |

独立入口：

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godot game\星核旅人\基础场景原型" res://scenes/star_core_interaction_standalone.tscn
```

独立入口 F4 返回 `main.tscn`。房间场景 `scenes/star_core_interaction_room.tscn` 可直接打开编辑地形/仓位/出生点。

## 2. 房间布局（编辑器可见）

`scenes/star_core_interaction_room.tscn` 是场景节点，不是运行时代码生成整张地图：

| 节点 | 内容 |
|---|---|
| `TerrainTop` / `TerrainFill` | `TerrainStrip` 重复图块视觉；可在检查器改 `strip_size`、`region`、位置 |
| `TerrainBody/CollisionShape2D` | 640×40 连续地面碰撞（顶部 y=320） |
| `Bays/StartBay` | 起始仓，`(120, 304)`，`start_locked=true` |
| `Bays/TargetBay` | 目标仓，`(520, 304)`，`start_locked=false` |
| `Core` | 唯一活动星核载体，初始隐藏，`(120, 312)` |
| `PlayerSpawn` | 出生点 Marker2D，`(48, 320)` |
| `StartBayLabel` / `TargetBayLabel` | 场景内可编辑标签 |

主场景复用现有 Player/HUD；独立入口自带一套 Player/HUD。`StarCoreBayInteractable` 只负责仓状态与开合动画，不拥有活动核。

## 3. 当前交互规则

- 起始仓初始**紫锁定**；仓内核心不参与吸斥。目标仓初始**开罩空仓**。
- **释放**：靠近有核仓按 E：
  - 立即快照 `核心极性 = 玩家极性取反`；
  - 罩从**顶部中央先打开**，左右沿弧面向两侧/底座下降；约 **0.25 s**；
  - 完全打开前不生成活动核；完全打开后核在仓的**远离玩家一侧**地面出现，初速 0，保持快照金/青；落点距仓心 40 px，避开玩家身体和底座；100 px 试玩范围下，出仓瞬间核与玩家中心距离约 76～83 px，仍在场内，不会出现“出仓即脱力”；
  - 开启中 Q 只切玩家，不改变快照。
- **拉行**：活动核与玩家双向受力；异号吸引、同号排斥。当前试玩作用范围为 **100 px**（协调者指定，非最终定稿）；普通 walk 越过核之后进入跟随，稳定拖行约 **38～52 px**，不绑定位置、不自动寻路。40 px 内为稳定区，不施力；超出 100 px 立即零力，不追出范围。玩家可走到核右侧，用普通 walk 把异号核吸引到右侧目标；反方向同理。
- **手动入仓**：没有自动捕获、没有无键减速/吸附。当
  1. 玩家在空仓交互距离内（46 px）；
  2. 活动核也在玩家附近（`store_player_core_range=80 px`）；
  3. 核中心在该仓小座位区（±24×18 px）内；
  
  HUD 显示 `E: STORE CORE (仓名)`。按下 E 才把核制动、对齐到仓中心、变紫，并让罩从两侧向顶部中央合拢。**不检查速度，不要求正负匹配。**
- 空仓保持开罩；手动合罩后无自动再捕获。入座对齐不超过座位半宽/半高（24×18，最大对角约 30 px），不是远程收核。
- 空仓/核不满足条件时，E 显示不可用原因（无活动核、核离玩家太远、核不在座位内），且不会误触释放/入仓。
- 入仓后靠近该仓按 E 再次释放，按当时玩家极性取反。
- 目标仓成功入仓只显示 `TARGET BAY REACHED` 提示，不停止物理、不禁用仓交互；可继续释放/回运。
- 出仓/关罩中的 E 被忽略；按住/echo 不重复；一次 E 不会在出仓后同一次按键立即收回。
- 核出界或 R 全房恢复；唯一活动核。

## 4. 物理与参数

| 参数 | 默认 | 位置 |
|---|---:|---|
| 作用范围 | **100 px（试玩，非最终）** | `StarCoreInteractionRoom.field_range` |
| 近距安全 / 全强度 / 外圈渐弱 | **40 / 64 / 18 px** | 同名导出 |
| 核加速度 / 玩家加速度 | 620 / 300 px/s² | 同名导出 |
| 核水平 / 向上 / 下落限速 | 120 / 180 / 500 px/s | `StarCoreCarrier` |
| 核重力 / 地面阻尼 | 1100 / 420 px/s² | `StarCoreCarrier` |
| 玩家—核入仓邻近范围 | 80 px | `store_player_core_range` |
| 小座位区 | ±24×18 px | `StarCoreBayInteractable.store_half_extents` |
| 释放距离 / 罩时间 | 40 px / 0.25 s | 同名导出 |

100 px 是协调者要求先试的值，不是定稿。近距 40 px 内不施力，避免贴身抖动；普通 walk 由异极力加速后靠动量跟随，实测稳定拖行约 38～52 px；停步后靠地面阻尼靠近到约 27～34 px 并静止。它仍是“范围力”，不是把核固定在某偏移、导航或越界回追。

实现取舍（均明确）：

- **接地运输取水平投影**：核心在地面时把中心连线力投影到水平方向，避免玩家站上方用同号排斥把核直接抬飞；空中仍使用完整方向。
- **玩家身体不推核**：核碰撞层为 4，玩家 mask 不包含 4；核只扫地形层 1，并对玩家加碰撞例外。玩家可从核旁/核上走过，不会顶推或撞飞；不是精确刚体碰撞。
- **无自动仓口辅助**：没有自动捕获、速度门槛、仓口慢区 drag 或释放后捕获锁存；手动 E 只看三方位置。
- **出料是瞬时定位**：`_core.activate_at(...)` 直接把核切到远侧 40 px 落点并开始物理，**不是**连续出料动画、平滑滑动或发射轨迹；该落点只负责避开玩家/底座。
- **近距跟随不绑位置**：100 px 内才计算真实中心线吸/斥力；40 px 内为零力稳定区；没有目标偏移、自动寻路、瞬移或越界回追。停步靠近靠核的剩余动量和地面阻尼完成。
- **玩家正常运动不变**：无外力时仍是 100/160、跳跃 -375、Shift/双击、重力/加速度。

### 旧自动捕获缺陷（已移除）

旧版本在释放锁存结束后会自动把核捕获回起始仓，导致异极拉行中途消失；现已移除自动捕获、速度门槛、仓口慢区和捕获锁存，改为显式 E STORE。该缺陷与本次 100 px 范围调整无代码关联。

### 100 px 近距跟随实测

独立 `tests/follow_near_distance.tscn` 用真实 InputMap、60 Hz 物理测得：

- 向右普通 walk（越过核后采样）：拖行 **38.2 / 42.6 / 51.9 px**（min/mean/max），0 帧 OUT OF RANGE；
- 停步：核从 37.2 px 靠近到 **27.5 px** 后静止，末段 30 帧距离/位置抖动 0.00 px，vx=0；玩家松开方向键后漂移 1.87 px；
- 停步后再走：核从 x≈272 继续跟随到 x≈363，gap≈37.9 px，仍在内；不是停住后绑定；
- 目标仓 E 入仓后再释放、向左走回：拖行 **38.2 / 41.9 / 46.5 px**，0 帧 OUT OF RANGE；停步从 38.4 px 靠近到 **34.0 px**，末段抖动 0.00 px，玩家漂移 -1.88 px；
- 同号 42 px 仍为 REPEL，核/玩家受力方向相反；
- run 按住 Shift+D 90 帧：gap **≈91.8 px**，仍 ATTRACT；继续到 210 帧，玩家到右边界，gap **≈375.4 px**、OUT OF RANGE，松开输入后核自行停住，不再追。

### run 边界

普通 walk 是推荐的可控运输方式。核限速 120 px/s 高于 walk 100、低于 run 160：短跑仍能维持一段时间，长跑会脱离 100 px 范围。实测 1.5 s 时 gap≈91.8 px，3.5 s 时 gap≈375.4 px、已 OUT OF RANGE 且停止追随；不承诺无限跟随。该结果与 100 px 试玩范围一致，长跑脱离是预期边界。

## 5. 罩动画

`StarCoreBayVisual` 不再使用整体 `scale.y` 压缩或均匀 alpha 淡出。当前使用 32×32 原玻璃图的**逐像素弧线遮罩 shader**：

- **合罩**：左右下缘/侧边先显现，沿罩弧向顶部中央推进，顶部中央最后合拢；
- **开罩**：顶部中央先消失，左右沿弧向两侧下降；完全打开时原图隐藏；
- 玻璃保持 1:1 位置/缩放，颜色/主色不改，不越底座；遮罩硬边，带 1 px 浅色推进边。
- 旧 `occupied` 静态默认行为保留；`set_lid_open_immediately()` 兼容旧显示。

真实引擎关键帧：`screenshots/star_core_lid_keyframes.png`，六个 4× 实例同屏，顶行合罩 66%→33%→闭合，底行闭合→开罩 33%→66%。像素检查：行轮廓左右对称，顶部中央条带在 33/66% 为 0、闭合时 >0；左侧白反光/右侧暗部会使原始左右颜色计数不同，因此对称性按轮廓判定。来源 `tools/preview_star_core_lid.tscn`，不是后期拼图。像素结果见 `screenshots/MANIFEST_LID.txt`。

## 6. 代码文件

```text
scenes/
  star_core_interaction_room.tscn
  star_core_bay_interactable.tscn
  star_core_carrier.tscn
  star_core_interaction_standalone.tscn
scripts/
  star_core_interaction_room.gd   # 排程、手动 E、力场、HUD、F3、重置
  star_core_bay_interactable.gd   # 仓状态/开合/小座位
  star_core_carrier.gd            # 核物理/限速/地面阻尼
  terrain_strip.gd                # @tool 可编辑地板视觉
  star_core_bay_visual.gd         # 分层视觉 + 双侧向中心遮罩罩动画
  main.gd / hud.gd / input_setup.gd
tests/
  test_star_core_interaction.gd/.tscn
  follow_near_distance.gd/.tscn
  test_star_core_bay_visual.gd/.tscn
  test_star_core_visual.gd/.tscn
  test_runner.gd/.tscn
tools/
  preview_star_core_lid.gd/.tscn
  capture_star_core_interaction.gd/.tscn
```

## 7. 实际测试结果

- 交互测试：**207 通过 / 0 失败 / 0 跳过，退出码 0**；日志 `tests/logs/follow_interaction_final.log`。
- 独立近距跟随测试：**54 通过 / 0 失败 / 0 跳过，退出码 0**；日志 `tests/logs/follow_near_distance.log`。
- 原全量 runner：**314 通过 / 0 失败**；日志 `tests/logs/follow_original_runner.log`。
- 三态视觉：**100 通过 / 0 失败**；仓视觉/双侧罩动画：**151 通过 / 0 失败**（上轮记录，本轮由并行视觉任务负责，未复跑）。
- GUI 白底渲染、罩关键帧像素检查为上轮记录，本轮未复跑。
- 实际固定输入闭环（测试真实 60 Hz）：
  `GOLD 玩家 → E 释放 CYAN 核 → 不 Q、普通 walk 向右越过目标仓（到 x≈555）→ 核异极跟随并停入目标座位 → 不按 E 目标保持 OPEN → 玩家/核/目标三方邻近 → E STORE → 目标合罩 LOCKED → E 再释放 CYAN（玩家在右侧，核落到 x=480）→ 向左走到起始仓左侧（x≈80）→ 核跟随并停入起始座位 → E STORE`。
  同号物理推送、两种初始极性（GOLD→CYAN 与 CYAN→GOLD 均实测拉行）、Q 开罩快照、快速/按住 E、玩家远/核不在座位/无核时的无效 E、高速度核 E 接受、暂停、R、F2/F4、唯一核、出界恢复均覆盖。
  实测跟随：右行拖行 38.2/42.6/51.9 px（min/mean/max，0 帧越界），停步 27.5 px、尾段抖动 0.00 px；左行 38.2/41.9/46.5 px，停步 34.0 px。run 90 帧 gap 91.8 px，210 帧 gap 375.4 px、OUT OF RANGE，松开后核停止、不回追。
- 测试日志：`tests/logs/follow_interaction_final.log`、`follow_near_distance.log`、`follow_original_runner.log`。

## 8. 截图

- `screenshots/interaction_01_opening.png`：起始仓开罩中、E 快照 CYAN -、核仍在仓内。
- `screenshots/interaction_02_transport.png`：GOLD 玩家 / CYAN 核异极跟随向右，VX=120，无自动入仓。
- `screenshots/interaction_03_target_capture.png`：手动 E STORE、目标合罩中、成功提示，物理仍活。
- `screenshots/interaction_04_target_release.png`：目标再次释放 CYAN 核，目标空开。
- `screenshots/star_core_lid_keyframes.png`：合/开罩六个实际引擎关键帧。
- `screenshots/MANIFEST_INTERACTION.txt`、`screenshots/MANIFEST_LID.txt`：来源、模式、像素结果。

这些是**真实引擎 viewport 捕获的脚本物理静帧**，不是人工连续试玩，也不是预渲染合成图；没有对连续手感作人工验收。现有截图拍摄于 190 px 阶段，本轮 100 px 调参未重拍截图；近距跟随证据以上面的实际 60 Hz 测试数值和日志为准。

## 9. 边界与未验证

本轮没有做：正式谜题/门/三关/正式关卡、锚点—核组合、多个核、极性转换机关、手持搬运/投掷/瞬移、音效/菜单/结算/存档、独立 exe。

仍需用户确认：

- 100 px 是试玩值：正常 walk 跟随约 38～52 px、停步约 27～34 px 是否合适仍需用户实际连续试玩；不是最终定稿。
- run 会拉开距离并在约 3.5 s 越出 100 px；普通 walk 是当前推荐运输方式。
- 手动 E STORE 的三方邻近范围和座位大小；
- 双侧向中心罩动画的速度、顶部落点/开合方向；
- 编辑器 GUI 拖放检查未做（房间/地形/仓位已是场景节点；主场景实例默认隐藏，建议打开 `star_core_interaction_room.tscn`）；
- 未做人工完整连续试玩；角色授权仍未知；未 git 提交；`progress.md`、`ASSET_CREDITS.md` 未编辑。
