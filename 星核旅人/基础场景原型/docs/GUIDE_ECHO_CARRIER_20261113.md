# 守望者残响 · 石碑载体与靠近显现（2026-11-13）

## 1. 体验

第一关两处残响改成「碑是载体、靠近才现形」：

- **远处**：只有一座灰色石碑留在原处 (250,300) / (735,300)，没有残响、没有 F。
- **靠近到 96 px 内**：残响从碑体上部 **0.25 s 淡入**，站在碑前像从碑里投出来。
- **进入56px**：出现「F交谈」；**靠近不会自动开页**，F开第1页、再F翻页、末页F收起。交谈状态有迟滞，超过66px才关闭页面。
- **越过 112 px**：残响 **0.20 s 淡出**，碑仍在。淡出途中走回来会平滑反向，不会闪断。
- 初始 alpha 0；标题/开场不会凭空出现；暂停冻结淡入淡出与待机帧且 F 不翻页；R/落坑/失焦清页，重玩可再次显现交谈。

第二关的石碑、守卫、运输、地图与第一关几何/物理/相机全部未动。

## 2. 参数

| 项 | 值 |
|---|---|
| 显现开始 | ≤ 96 px（`manifest_range`，可 export） |
| 淡出开始 | > 112 px（`hide_range`，可 export） |
| 96..112 | 保持当前状态（迟滞，防边界闪烁） |
| 淡入 / 淡出 | 0.25 s / 0.20 s（可 export） |
| F 范围 | 56 / 离开 66（沿用旧值，未改） |
| 上抬 | **18 px**（`PROJECTION_LIFT`；看图后选的整数，碑基仍露在残响脚下） |
| 石碑 | `tutorial_stele_grey.png` 26×52，`centered=false`、`(-13,-52)`、Nearest |

## 3. 实现

- `scenes/narrative/guide_echo.tscn`：新增 `CarrierStone`（纯 `Sprite2D`）与 `EchoProjection`（`(0,-18)`），`EchoSprite` 挂到 `EchoProjection` 下，仍是 48×64、偏移 `(-24,-60)`、scale 1、Nearest、6 帧。
- `scripts/narrative/guide_echo.gd`：
  - `_ensure_carrier()` 只加载灰碑 PNG 当贴图；**不实例化 `TutorialStele`**，无碰撞、无读碑输入、不进 `tutorial_stele` 组；
  - `_update_manifestation()` 用 `move_toward` 做迟滞淡入淡出，只写 `Sprite2D.modulate.a`——**PNG 一个像素都没改**；
  - F 在 alpha 仍为 0 时不接收，开始可见后正常；提示同样要求已可见；
  - 对话/提示的定位减去 18 px 上抬，面板不会盖住头；`prompt_hud_safe_top` 夹屏不变；
  - 新增 `get_manifestation() / is_manifestation_visible() / get_manifest_range() / get_hide_range() / get_carrier_stone() / get_carrier_texture() / get_projection_lift()`；旧 getter 与交互 API 未动。
- 运行图 `assets/guide_echo_20261113/guide_echo_idle_6f.png` 的 SHA-256 仍是 `2ACAA0E55E8F68DE8881295F82E04B7361187C8E08977C37CFB13C59C80BC233`（未改）。

## 4. 实测

临时聚焦 harness（用后删除）在真实 `level_01.tscn` 上跑，日志 `tests/logs/guide_echo_carrier_20261113.log`，**fails=0**：

- 两处都有纯视觉灰碑（26×52、(-13,-52)、Nearest），无碰撞、不在 `tutorial_stele` 组，场上没有 `TutorialStele` 组件；
- 远处 alpha=0、无提示；用真实 A/D 走入 96 内开始淡入，56 内 alpha=1 且出提示、不自动开页；
- 真实 F 开页 1 → 翻页；离开 66 先关页；越 112 淡出到 0；
- 淡出途中回到范围内 alpha 从 0.44 反向升到 0.47（无 reset）；
- 真实 Esc 暂停：待机帧与 alpha 冻结、F 不翻页；Esc 恢复；
- R 清页，走回后再次显现；
- 第二显现点：提示/对白正常，对话矩形 x=200 w=300，完全在 640×360 内；
- 释放关卡后无残留 `guide_echo` 节点。

关卡载入：`level_02.tscn` 一次性 headless 载入 30 帧，无报错。

GUI 定帧（同一生产第一关构图，均为定点 setup，不是从出生通关）：
- `screenshots/guide_echo_carrier_far_20261113.png` — 远处只有碑；
- `screenshots/guide_echo_carrier_near_20261113.png` — 靠近显现 + F 对白第 2 页。

## 5. 保护 / 未验

- 只读未改：`scenes/level_01.tscn` `5E9186FA…`、`scenes/level_02.tscn` `0A5ED237…`、`scenes/player.tscn` `3B48294B…`、`scripts/player.gd` `5711828A…`、`scripts/level_02.gd` `29B2AAF8…`、`polarity_golem_guard.tscn` `5CB9958C…`、`polarity_golem_enemy.gd` `50C54AE0…`、`ruin_platform_tiles.png` `0E4968FB…`、`tutorial_stele_grey.png` `AD4BBEBB…`；mtime 仍为 11-01/11-12。
- 未改：任何 PNG、源包、preview、第一关几何/物理/相机/出生/检查点、第二关石碑/守卫/运输、WORLD_BIBLE/TODO/progress/根 README。
- **预览兼容（2026-11-13 收尾）**：`previews/art_reference_20261112/first_level_sample.gd` 的旧 body 隐藏段已改成先取 `EchoProjection/EchoSprite`、取不到再回退旧 `EchoSprite`，并额外隐藏锚点上的 `CarrierStone`；只改这一段，未改/未重拍任何预览 PNG、预览 tscn、旧素材或正式 carrier 行为。headless 三帧载入该预览实例断言（`tests/logs/guide_echo_carrier_preview_compat_20261113.log`，fails=0）：正式 body 隐藏、carrier 隐藏、样张自己的 NPC 可见、浮动对白 UI 隐藏。
- 未验：未从出生完整跑图、未人工连续试玩；未跑旧 147/162 完整 suite；用户尚未看这一版实景观感。

## 6. 协调者复核

- 已亲看远处/近处生产GUI图、关键状态代码和`fails=0`日志，确认石碑保留、残响从碑上部显现，形象没有重新绘制。
- 独立核PNG与批准预览逐字节相同（2acaa0e5…）、两正式关scene哈希与载体改动前相同，载体不实例化`TutorialStele`且无新增碰撞；两张图均640×360。
- 独立生产`level_01.tscn`三帧headless载入退出0，无脚本报错；未重复开发的交互检查/9项保护或完整通关。
- 历史隔离预览另做最小隐藏路径兼容，避免新增载体意外进入旧样张；未重拍或覆盖任何旧PNG。
