# 守望者残响 · 最终形象接入正式关（2026-11-13）

## 1. 结论

已批准的最终 NPC 表 **逐字节** 接入正式游戏，像素、比例、帧数、锚点都没有再改。第一关两处残响现在显示这份新表；第二关没有 NPC，未改动。

- 批准表：`previews/art_reference_20261112/watcher_echo_idle_6f.png`
  SHA-256 `2ACAA0E55E8F68DE8881295F82E04B7361187C8E08977C37CFB13C59C80BC233`
- 运行表：`assets/guide_echo_20261113/guide_echo_idle_6f.png`
  同一 SHA-256（直接字节复制，未重跑 derive、未调色、未补像素），288×64，6 帧 × 48×64。
- 说明：`assets/guide_echo_20261113/manifest.json`（来源、逐帧 bbox、脚底锚、播放参数）。

## 2. 代码改动（只有三处常量 + 场景两行）

| 文件 | 改动 |
|---|---|
| `scripts/narrative/guide_echo.gd` | `SHEET_PATH` → `res://assets/guide_echo_20261113/guide_echo_idle_6f.png`；`FRAME_COUNT` 4 → **6**；`IDLE_FPS` 3 → **4**；docstring 同步 |
| `scenes/narrative/guide_echo.tscn` | `ext_resource` 贴图 → 新运行表；`hframes` 4 → **6** |

保持不变：`FRAME_SIZE` 48×64、`FOOT_ANCHOR` (24,60)、`SPRITE_OFFSET` (-24,-60)、`centered=false`、`scale=1`、`TEXTURE_FILTER_NEAREST`（脚本与场景两处都设）、整数坐标。

## 3. 正式入口

- 第一关 `scenes/level_01.tscn`：`World/GuideEchoMeeting` (250,300)、`World/GuideEchoHighstep` (735,300)，两处实例化同一 `scenes/narrative/guide_echo.tscn`，各 3 页原台词未改。
- 第二关 `scenes/level_02.tscn`：仍无 `GuideEcho`，仍用自己的 6 页石碑。
- 运行时只读 `assets/guide_echo_20261113/`，**不依赖 `previews/` 或 Temp**。

## 4. 交互与门控（未改）

接近只显示「F 交谈」；F 开第 1 页、再 F 翻页、末页 F 收起；离范围关闭、回来可重听；`echo` 忽略。暂停/菜单/开场/完成/失焦由关卡挂起并清页；暂停中原生帧冻结、F 不翻页。残响无碰撞、无力场，不影响符石射线、平台或门。

## 5. 实测（聚焦 check，未跑旧大套）

临时聚焦 harness（用后删除）加载真实 `level_01.tscn`/`level_02.tscn`，全部通过，日志 `tests/logs/guide_echo_production_20261113.log`：

- 运行表 288×64、可切 6 帧；
- 两处残响的 `Sprite2D` 都指向新表、`hframes=6`、Nearest、偏移 (-24,-60)、scale 1、不居中、脚底锚 (24,60)；
- 关卡载入时无对白、页索引 -1；
- 待机帧会推进（f0→f2，4 fps）且始终在 0..5；
- 靠近只出提示、不自动开；真实 F 开页 1 → 翻到 2 → 翻到 3 → 收起；收起后提示回来；
- 暂停：帧冻结、F 不翻页、解除暂停后对白与页号不变（无输入泄漏）；
- 离开范围提示与对白都关闭；
- 第二关载入一次：没有 `GuideEcho`，玩家正常实例化。

GUI 定帧（真实生产第一关，非从出生通关）：
`screenshots/guide_echo_production_20261113.png`（640×360，玩家被摆到 (286,300)、真实 F 打开第 1 页）。

## 6. 保护 / 未改

只读文件未改，mtime 仍为 11-01/11-12，SHA-256：

| 文件 | SHA-256（前 16） |
|---|---|
| `scenes/level_01.tscn` | `5E9186FA4B30E490` |
| `scenes/level_02.tscn` | `0A5ED2378C4A9747` |
| `scenes/player.tscn` | `3B48294B267E4E1F` |
| `scripts/player.gd` | `5711828A3FF6C9E0` |
| `scripts/level_01.gd` | `D4493F5DEBFCB77E` |
| `scripts/level_02.gd` | `29B2AAF82A3D89C6` |
| `scenes/enemies/polarity_golem_guard.tscn` | `5CB9958CA397FED2` |
| `scripts/experiments/polarity_golem_enemy.gd` | `50C54AE0F64DB4CE` |
| `assets/map/ruin_platform_tiles.png` | `0E4968FB754D1F76` |

- 旧 4 帧素材 `assets/guide_echo_20261112/guide_echo_idle_4f.png`（`35C9AE73…`）保留未覆盖。
- 背景 DS03、两大桥、UI 布局与字体、第一关几何/物理/借力/相机/出生/检查点、第二关 6 页石碑/守卫/3HP8s/运输/洞口全部未改。
- `project.godot` 仅被 `--import` 重写同一内容（984 bytes，viewport 640×360 等原样），无内容变化。

## 7. 回退

把 `guide_echo.gd` 的 `SHEET_PATH`/`FRAME_COUNT`/`IDLE_FPS` 与 `guide_echo.tscn` 的贴图/`hframes` 改回旧值即可，旧 PNG 未动。

## 8. 未验

- 没有从出生开始的完整通关跑图，也没有人工连续试玩；GUI 图是固定位姿 setup。
- 未跑旧 147/162 完整 suite 与全关跑图；只做了上面的聚焦 check（`tests/test_art_guide_pass.gd` / `tests/art_guide_pass_assets.py` 里的 4→6 帧与资源路径断言已同步，未整跑）。
- 用户尚未看正式关内的实际观感。

## 9. 协调者复核

- 亲看正式第一关GUI截图、关键组件代码与聚焦检查日志，日志`RESULT fails=0`。
- 独立核对运行PNG与批准预览逐字节一致，SHA-256为`2acaa0e55e8f68de8881295f82e04b7361187c8e08977c37cfb13c59c80bc233`；288×64、6帧、4fps、原偏移，运行组件不依赖预览目录。
- 独立用生产`level_01.tscn`做headless三帧载入，退出码0、无脚本报错；日志在本机Temp `guide_echo_production_coordinator_20261113.log`。
- 未重复开发的交互测试或9文件保护，未人工连续通关。此次只接入人物；样张中的小HUD/底部对白与恢复暗部atlas没有借本任务自动推广。
