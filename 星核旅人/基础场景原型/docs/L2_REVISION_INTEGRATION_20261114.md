# L2 修订正式接入（2026-11-14）

## 状态

用户已在确认页批准 transport / return / gate / echo，`gateVersion=v2_8f`、`echoSaturation=0.4`、`allowFormalIntegration=true`。本轮把这四项接入正式第二关；**完成接入不等于自动获得最终验收**，手感/观感仍由协调者与用户确认。L1 scene、DS03、player、project.godot、正式 HUD 布局、rune 逻辑、100px/内圈/强度/摩擦/尺寸/E/Q 均未改。

## 正式改动

- `scenes/level_02.tscn`
  - 移除旧低廊 `CorridorEntryPier`、`CorridorExitPier`、`BeamA..E`，换成完整 `ConductiveRoof`：`256x32 @ (464,268)`，底边 y=300，下方 20px 核通道。
  - `LinkedWall` 160x60、`LinkedLip` 40x12 使用批准导相石贴图；新增 `ReturnPlatform` 48x12 @ (1264,280)，底 292，28px 净空，无立柱。
  - `StartStele` 换成 `GuideEcho` 实例：process_mode pausable、位置 (80,320)、F 56/66、96/112、抬 18、s40、4 页；第三页改为完整特殊石构透力。
  - `Exit` 增加 `gate_portal_fx_enabled=true` 与 v2 sheet，锚点/Nearest/正常 alpha 由 LevelExit 统一处理；原门框/完成图不改。
  - CorridorLabel 改为“低廊 · 实体导相石 · 仅护符力”。
- `scripts/level_02.gd`
  - `_stele: GuideEcho`；`get_start_stele() -> GuideEcho`，新增 `get_start_guide()`。
  - 登记恰好四个 special body RID，在正式 Level02 覆盖 `_is_line_blocked()`：仅玩家—核力射线排除它们；普通 layer 1 地形和 RuneStoneField 仍遮挡。
  - 每 tick 把真实 `is_exit_gate_ready() and not _completed` 交给 LevelExit；恢复/R/完成主动撤效。
  - `get_platform_rects()` 增加四个正式几何矩形；HUD 的“取核后穿过低廊”改为“取核后沿实体盖向右”。
- `scripts/level_exit.gd`
  - 新增默认关闭的 `gate_portal_fx_enabled` / `gate_portal_fx_sheet`；仅在 opt-in 时创建 8 帧 Sprite2D，z=-1、Nearest、正常 alpha、锚 (38,99)；`_process` 8 fps 且 Esc 冻结；completed/E/R 隐藏。
  - L1 不设置 opt-in，因此无 FX、无几何/触发变化。
- `scripts/narrative/guide_echo.gd`、`scenes/narrative/guide_echo.tscn`
  - 共用 s40 贴图路径；原 `guide_echo_idle_6f.png` 保留。L1 两个同角色点位自动使用 s40，位置/页数/显隐范围/F/碰撞未改；L2 使用同一实例化场景。
- 正式新增资产（与预览批准文件逐字节一致）：
  - `assets/level02_conductive_stone/conductive_roof_256x32.png`
  - `.../conductive_sill_160x60.png`
  - `.../conductive_lip_40x12.png`
  - `.../return_platform_48x12.png`
  - `assets/checkpoint_exit/gate_portal_fx_v2_8f.png`
  - `assets/guide_echo_20261113/guide_echo_idle_6f_s40.png`
  - `assets/level02_conductive_stone/source_manifest.json`（来源/尺寸/hash/运行规则；仅记录来源，不作为 runtime 引用）
- 旧测试中 5 处 `TutorialStele` 静态类型改为动态兼容，仅用于保持旧归档脚本可解析；本轮 **不运行** 旧 183/24/全关 suite。新增本轮的 smoke/transport/return/gate 聚焦测试与捕获；旧 preview 仅做最小“正式节点已存在则复用”的兼容，不成为正式 runtime 依赖；preview 入口 headless 载入退出码 0。

## 关键验证（实际日志）

- `tests/test_l2_integration_20261114.tscn`：**43 PASS / 0 FAIL**（正式 L2 节点/四 RID/普通墙遮力/rune 遮力/v2 sheet/GuideEcho/L1 opt-out）。
- `tests/test_l2_transport_formal_20261114.tscn`：**15 PASS / 0 FAIL**；正式 L2 setup 后真实走/跳，同一核过右端 `x>728`，人在右侧地面；Q 只切玩家。
- `tests/test_l2_active_return_formal_20261114.tscn`：**22 PASS / 0 FAIL**；正式 mode2 active GOLD 场，两跳、两次真实 Q、E 取核、无 R/死亡/场重置，核/场保持。
- `tests/test_l2_gate_echo_formal_20261114.tscn`：**51 PASS / 0 FAIL**；真实 E/R/Esc，闭/开单核、8 帧 FX、完成原图、GuideEcho F/pause/R/远离，无旧碑双输入。
- L1/L2 headless 载入退出码 0；`--headless --editor --import --quit` 重新导入退出码 0，无 parse/重复类错误（见 `tests/logs/l2_integration_import_20261114.log`）。
- 保护：`tests/logs/l2_integration_protection_20261114.json`；before 212 项中 **207 same / 5 authorized changed / 0 unauthorized / 0 missing**。5 项为 `level_02.tscn`、`guide_echo.tscn`、`level_02.gd`、`level_exit.gd`、`guide_echo.gd`。
- 6 张正式新资产与批准预览 **6/6 逐字节一致**；原残响 `2acaa0e5…e233`、L1 scene、player、DS03、project.godot 哈希不变；10 份源备份 **10/10** 一致。
- 正式截图（3 张真实 640×360，已打开）：`screenshots/l2_formal_integration_20261114/01_gate_closed_setup.png`、`02_gate_open_setup.png`（同机位，真实 gate 状态）、`03_l2_echo.png`；无预览覆盖提示、无双碑，门 FX 在门洞内可见。`manifest.json` 标明固定 setup、非通关。

## 未验/风险

- 三张正式图是固定 setup，不是完整通关；未做人工连续试玩，手感/门效可读性由用户最终判断。
- 门关闭截图的 HUD 是 setup 状态（核在联动仓、最终仓空），不是正常流程到达；已标注。
- 旧测试中仍有历史断言（如 L2 旧 TutorialStele 六页、无 GuideEcho）不再代表当前正式行为；本轮不改写它们为“通过”，也没有运行旧 suite。
- 备份 `.uid` 当前缺失、成因未核实；本轮未触碰归档/旧工具/UID。
- 未提交/推送；根 progress/TODO/计划未改。

## 协调者关键验收（工程交付后）

- 已审正式场景/门组件/透力例外/残响生命周期、正式样段测试代码与4份实际日志（43/15/22/51项PASS，FAIL=0），打开门关/门开/残响3张正式实机图。工程记录不冒充协调者亲自全程游玩。
- 独立运行正式L1/L2入口各12帧，均退出0；独立对比before212项，确认仅5个授权源文件改变、无缺失/未授权变化；6张新PNG与批准预览逐字节一致、残响alpha同、原残响2ac源保留，10份源备份hash一致；授权源文件无`res://previews/`或截图依赖。
- 接受本轮正式接入及相关关键验证；计划末步已勾，根导航/进展/待办已更新。未重复工程131项或完整人工通关；主观手感与连续流程仍交创作者试玩。
