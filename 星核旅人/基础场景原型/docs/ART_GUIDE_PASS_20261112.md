# 全关美术优化＋第一关守望者残响：实现报告（2026-11-12）

本报告记录本轮实际改动、验证证据和未验边界。正式关卡仍只有第一关、第二关；旧 `main/F2/F4/F7` 只作为共享 atlas 的兼容入口检查，没有新建第三关、任务链或场景大替换。

## 1. 实际改了什么

### 1.1 三张运行 PNG 安全替换

替换前逐张核对旧运行图 SHA 与 `assets/art_pass_20261112/manifest.json` 的 pre-replacement source 一致；先把旧运行图按相对路径归档到上级 `项目归档/美术优化前运行资源_20261112.zip`，ZIP 条目逐项 SHA-256/CRC 校验通过后才替换。未覆盖任何既有归档；保持原路径、Nearest、scale/过滤设置（Godot `--import` 会正常刷新 `.import` 元数据）。

| 运行路径 | 当前 SHA-256 | 本轮变化 |
| --- | --- | --- |
| `assets/map/ruin_platform_tiles.png` | `0E4968FB754D1F76122B5319B95C893489523E43A44D36842416C9AF091D095D` | 192×32 RGBA、12×2 个 16 px 格、alpha 逐字节不变；8 色暖灰索引映射 |
| `assets/level02_platform_v3/layer_platform_visual_640.png` | `0849BA133E7A2B8A950EC0B87E959499022A6C538566E5F5121E197847BD181F` | 640×360；左 HighStep 可见下沿收至 y287，y≥288 alpha=0；碰撞底仍 288 |
| `assets/level02_platform_v3/layer_platform_decor_640.png` | `5C2283F9BA29998B57D076A880D444F6B05992930B3A24613A6DF7D0DD53400D` | 640×360；五缝中心 260/284/324/348/372 中性短刻槽；删高台 y289 两旧苔藓像素 |

- 旧 source/pre-replacement 哈希（`3A9FC342…`、`EE8D38E3…`、`58C58508…`）保留在资产文档中只作历史追溯，**不是当前运行 PNG 哈希**。当前哈希与备份说明已写入 `assets/art_pass_20261112/manifest.json` 的 `runtime_application` 和 `assets/level02_platform_v3/manifest.json` 的 `runtime_replacement`。
- 追加的极小局部层级补丁：HighStep 两个可见切片 `V3PlatformVisual/Decor` 设 z=6，详见 1.4；不涉及 PNG 或碰撞。只读批准源稿 `自制素材/第二关平台完整造型预览_V3/layer_platform_{visual,decor}_640.png` 与原美术派生文件未改；没有全局调色罩、没有改材质 alpha 伪装优化。
- 替换后执行 `--headless --import` 重新导入受影响资源；GUI 定帧确认实际使用新图。

### 1.2 第一关守望者残响

- 新增可复用组件：`scenes/narrative/guide_echo.tscn`、`scripts/narrative/guide_echo.gd`（`class_name GuideEcho`）。
- 第一关 `World/GuideEchoMeeting` (250,300) 与 `World/GuideEchoHighstep` (735,300) 替换两块旧石碑；原石碑外壳和读碑输入已从第一关移除。第二关 6 页 `StartStele` 保留。
- 使用美术已完成的 `assets/guide_echo_20261112/guide_echo_idle_4f.png`：192×64、4×48×64、脚底锚 (24,60)、4 帧轻呼吸；Nearest、1 源像素 = 1 逻辑像素。
- 接近只显示短「F 交谈」提示，不自动开页；F 才开第 1 页，之后 F 翻页，末页 F 收起；echo 忽略；离开关闭、回来可重听。对话不暂停、不锁移动、不要求读完才能过关。
- 对话由屏幕空间 CanvasLayer 显示，按相机做世界→屏幕换算并夹 640×360；说话者「守望者残响」，正文 12 px Fusion Pixel，面板位于残响/玩家人体上方。
- 菜单/2.2 s 移镜/开场自动跑入、暂停、完成、返回标题、失焦由关卡挂起并清页；暂停冻结待机/提示/对白且 F 不翻页；R/落坑恢复/失焦清旧页，重玩仍可交谈。残响无碰撞、无力场，不影响符石射线或平台。
- 节点命名明确为 `GuideEcho*`；`get_narrative_stele()` / `get_mechanism_stele()` 仅作为旧名兼容 alias 返回 `GuideEcho`，注释明确石碑已不在，新代码使用 `get_narrative_guide()` / `get_mechanism_guide()`。

### 1.3 HUD/标签可读性

- 第一关 HUD：标题 24 px，章节/相性说明/提示/结算正文统一 12 px；原 8/9/11/14/18 缩放字号移除。玩家相性仍常驻右上。
- 第二关 HUD：标题 24 px，章节/状态/相性/提示/结算正文 12 px；状态面板只显示「任务：…」与「星核：…」，主行动提示与 short toast 共用 y104 的单个槽位，不会同时出现。没有重新加敌人头顶极性字/正负/菱形。
- 第二关世界标签全部 9→12 px；`UpperLabel` 缩短为「嵌缝施力」，完整遮挡解释保留在 12 px 石碑内；`ExitStatus` 只保留「出口 · 未就绪 / 可离开 / 已完成」，并抑制重复门牌「出口」，避免文字互压。
- 两关暂停菜单：标题 24 px，副标题/操作行/提示 12 px；第一关 F 行改为「交谈」，第二关仍是「阅读石碑」/「挥击守卫」等原键位。
- 开始菜单/设置中两个原有 18 px 功能标题（“保留显示设置？”与设置宿主“已暂停”）改为 24 px；已批准主菜单字标、按钮图和显示确认/回退逻辑未换。
- 敌人实验 HUD 经检查仍全部为 12/24 px，未改其玩法或敌人源图。

### 1.4 HighStep 前后遮挡极小补丁（2026-11-12 追加）

- 问题：HighStep 的 V3 可见切片原本 z=0，玩家 z=5；玩家站在台下 32 px 间隙时，高于 30 px 碰撞体的头发会画到真实 14 px 台体前缘上。
- 修复：只把 `HighStep/V3PlatformVisual` 与 `HighStep/V3PlatformDecor` 的 `z_index` 设为 **6**，高于玩家 z=5。没有改玩家 z/碰撞/头像/运动、台阶位置/`block_size`、贴图 alpha 范围、主桥/RightLedge/守卫绘制，也没有加整矩形遮罩。
- 效果：台下时石材前缘遮住 y284..287 的头发；y≥288 仍无额外石面；台上时玩家脚底仍在 y274、`is_on_floor()` 成立，y238..273 的身体像素与隐藏平台时完全一致（仅 y274..275 的 1 px 鞋底/前缘交叠，属于正常接地关系）。z=6 仍低于世界标签 z=100 与 HUD CanvasLayer 10，不遮字幕/HUD。
- 专项日志：`tests/logs/art_guide_pass_highstep_z_order_20261112.log`（17/0）；03 截图已按补丁后状态重出，未额外保存第四/第五张近似图。**147 项聚焦套件是补丁前结果，补丁后未复跑。**

### 1.5 旧首关测试接口同步（2026-11-12 收尾）

- 同步 `tests/test_level_01.gd` 与 `tests/menu_to_exit_smoke.gd` 中本轮直接改变的接口：
  - `TutorialStele` 类型/`get_narrative_stele`/`get_mechanism_stele` → `GuideEcho`/`get_narrative_guide`/`get_mechanism_guide`。
  - 第一处页数 2→3；两处都改为“接近只显示 F 提示、真实 F 才开第 1 页、F 翻 3 页/末页收起”。
  - `is_focused`→`is_in_range`；组名 `tutorial_stele`→`guide_echo`；打开页面后 R/失焦会清页并挂起。
  - 原跳跃/借力/菜单跑入/通关/地形同步等无关断言保留。
- 只对这两个脚本做 `--check-only` 解析/类型检查，**没有启动整套、没有跑两关出生通关**。两项均 `EXIT=0`，日志：
  - `tests/logs/art_guide_pass_legacy_interface_test_level_01_check.log`
  - `tests/logs/art_guide_pass_legacy_interface_menu_to_exit_smoke_check.log`
- 这不代表旧套已运行通过；旧套的实际运行仍需以后再按新交互回归。其他旧 suite、progress/README/CSV 未改。

## 2. 保护项

- 第一关几何/出生/符石/检查点/出口/相机/菜单移镜 2.2 s/自动跑入 120 px/s（ratio 0.75）/物理借力参数未改；测试直接比较了场景真实字段。
- 第二关桥几何、5 条 8 px 真缝、HighStep 56×14/底 288、RightLedge 32×24/底 300、100/40/64/18 力场、620/300 加速度、E 入仓 80 px、守卫脚点/巡逻/相性/HP/8 s 重组逻辑均未改；测试比较了关键字段与一次真实信号受击。HighStep 补丁只改两个 Sprite2D 的 z_index=6，不涉及碰撞/位置/alpha/主桥/守卫绘制。
- `scenes/player.tscn`、`scripts/player.gd`、共享运输/核/仓/DS03 背景与 `project.godot` 未改；主角与守卫仍 scale 1。
- 旧 `main/F2/F4/F7` 共用地面 atlas 仍走原路径；`main.tscn`、`star_core_interaction_room.tscn`、`polarity_record_test_room.tscn` 载入检查通过。本轮未重跑旧 F7 硬编码 suite。
- 未做 git 提交、未清理/终止未知进程、未下载或购买外部素材。

## 3. 验证与证据

### 3.1 聚焦测试（真实 Godot 4.7.2）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_art_guide_pass.tscn
```

- 结果：`TEST_SUMMARY pass=147 fail=0`，`RESULT: PASS`。
- 日志：`tests/logs/art_guide_pass_test_20261112.log`、`tests/logs/art_guide_pass_test_stdout_20261112.log`。
- 覆盖：四入口解析/实例化（level01 默认菜单、level02、敌人实验、旧 main + 两个旧沙盒）、共享 atlas/新图层导入、第一关无旧石碑且恰好 2 个 GuideEcho、接近不自动开页、真实 F 开/翻/收/回声忽略/离开重听、菜单/暂停/完成/R/失焦门控、第一关几何与参数、第二关 5 缝/高台/右短台/力场/运输/标签 12 px 不裁切、HUD 单提示/ toast 互斥、一次真实信号同相扣血与重复 swing 不结算、实验 HUD 字号。
- **注意：这是 HighStep z-order 补丁前的结果；补丁后按协调者要求没有复跑 147 项。**

### 3.1A HighStep z-order 专项（补丁后，唯一新增验证）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/check_art_guide_pass_highstep_z.tscn
```

- 结果：`HIGHSTEP_Z_SUMMARY pass=17 fail=0`，`RESULT: PASS`。
- 日志：`tests/logs/art_guide_pass_highstep_z_order_20261112.log`、`tests/logs/art_guide_pass_highstep_z_order_stdout_20261112.log`。
- 一次 GUI 载入，两种渲染状态：台下重出 03 图；台上只做内存像素对比，不保存第四/第五图。属性检查覆盖 z=6/玩家 z=5/玩家碰撞 12×30/HighStep 56×14/主桥与 RightLedge z 未变/守卫 z=3 未变。
- 像素检查：台下石材遮挡 y284..287 头发（changed=160），y289..300 无额外石面（changed=0）；台上 y238..273 身体与隐藏平台时完全一致（changed=0），脚底 y=274 且 `is_on_floor()`。

### 3.1B 旧首关测试接口 check-only（不运行整套）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" --check-only --script res://tests/test_level_01.gd
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\godot game\星核旅人\基础场景原型" --check-only --script res://tests/menu_to_exit_smoke.gd
```

- 两项均 `EXIT=0`；只做解析/类型检查，没有启动整套或两关出生通关。
- 日志：`tests/logs/art_guide_pass_legacy_interface_test_level_01_check.log`、`tests/logs/art_guide_pass_legacy_interface_menu_to_exit_smoke_check.log`。
- 同步内容见 1.5；这不代表旧套实际运行通过。

### 3.2 资产级验证（Python）

```powershell
D:\minic\envs\2024212971\python.exe tests/art_guide_pass_assets.py --stage verify
```

- 结果：`SUMMARY stage=verify pass=66 fail=0`，`RESULT: PASS`。
- 日志：`tests/logs/art_guide_pass_verify_20261112.log`。
- 覆盖：3 张运行 PNG 与 derived 逐字节一致；尺寸/RGBA/alpha；atlas 12×2 与 alpha 不变；HighStep y≥288 alpha=0、y287 仍可见；五缝刻槽存在；主桥/右短台切片未动；guide 192×64/4 帧/锚点/哈希；ZIP 三条目 SHA/CRC；只读 V3 源稿未动。

### 3.3 GUI 定帧（3 张，脚本固定姿态，不是人工连续试玩）

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\godot game\星核旅人\基础场景原型" res://tests/capture_art_guide_pass.tscn
```

- `screenshots/art_guide_pass_01_level01_echo_dialogue.png`：第一关残响与第 1/3 页对白。setup：关闭开始菜单、开场缩到 0.15 s、玩家定点；F 为真实 `InputEventKey`。
- `screenshots/art_guide_pass_02_level02_guard_seams.png`：第二关守卫/五缝/12 px 标签/新版 HUD。setup：守卫 AI 暂停、玩家/守卫定点，不是连续巡逻截图。
- `screenshots/art_guide_pass_03_level02_under_highstep.png`：玩家站在 HighStep 下方 32 px 间隙。此图已由 z-order 专项在补丁后重出（唯一重出的 03）：V3 slices z=6 遮住 y284..287 的头发，y≥288 仍无额外石面，碰撞底 288；未保存台上第四/第五张图。
- 日志：`tests/logs/art_guide_pass_capture_20261112.log`、`tests/logs/art_guide_pass_capture_stdout_20261112.log`。
- 三张均由运行中 Godot 640×360 根视口捕获，不是 UI setup 图冒充完整流程。

## 4. 入口与启动

- 正式第一关：打开 `基础场景原型/project.godot`，双击 `scenes/level_01.tscn` 按 F6；默认进开始菜单 → 开始游戏 → 2.2 s 移镜/自动跑入 → 第一关。
- 第一关两处残响：(250,300)、(735,300)。接近显示「F 交谈」，F 开页/翻页/收起；不要求读完。
- 第二关：`scenes/level_02.tscn` F6；运输/守卫/石碑规则不变。
- 敌人实验：`scenes/experiments/polarity_golem_experiment.tscn` F6。
- 旧 main：F5 / `scenes/main.tscn`，仍走旧入口；本轮只共享新地面 atlas。

## 5. 未验 / 保留风险

- 未做人工连续试玩；三张 GUI 是脚本定帧。未验证玩家对残响体量、对白面板位置、暖灰地面/缝刻槽强度、桥面施力站位的主观观感。
- 未重跑旧 119/448/355/162 等大套；HighStep z 补丁后也未复跑 147 项，只跑了 17 项专项。`test_level_01` / `menu_to_exit_smoke` 的 GuideEcho 接口已同步（类型/新 getter/3 页/F 打开/清页），但只做了 `--check-only` `EXIT=0`，没有运行整套，不能声称旧套通过。
- 未遍历暂停/完成/菜单/失焦的所有排列；覆盖了菜单、暂停、完成、R、失焦返回的关键门控。返回标题通过代码检查（先挂起再 `LEVEL_FLOW.return_to_title`，场景卸载释放 CanvasLayer），未做同实例跨场景残留自动化。
- 未做真实 8 秒守卫重组、完整运输+战斗连续流程、真实 E 入仓全流程；本轮只保留一次真实信号同相扣血集成关键点。第二关五缝可见性依赖美术刻槽，射线/实体遮挡仍按原几何。
- 原始角色/守卫/地图许可仍按既有记录，部分未知；本轮未重新核实 Szadi art. 等第三方许可。守望者残响为本项目本地 Pillow/AI 辅助派生，不是人类手绘，权属说明在 `自制素材/守望者残响_20261112/README_权属说明.md`。
