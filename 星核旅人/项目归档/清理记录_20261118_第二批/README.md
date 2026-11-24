# 第二批清理记录（2026-11-18）

本目录记录本轮“删除已确认无用的测试截图/派生预览”的可逆操作。清单见 [`manifest.csv`](manifest.csv)（UTF-8 BOM，979 行）；旧记录 `项目归档/整理盘点_20261118.md`、`项目归档/全项目分类清单_20261118.csv` 原样保留，未覆写。

## 0. 根 `待删除/` 与上一轮 4 个视频的实际状态（如实记录）

- 本轮开始时根 `待删除/` **不存在**（`Test-Path` 为 False，目录列表无此项），本轮结束时仍不存在；未重建该目录。
- 上一轮记录中移入 `待删除/` 的 4 个外部参考视频，在原路径与 `待删除/` 目标路径**均不存在**；本轮未重新生成、未猜测删除者。可核对的历史记录仍在 `整理盘点_20261118.md` 与 `全项目分类清单_20261118.csv`，但上一轮的 `待删除/manifest.csv` 已随目录消失。
- 已知的上一轮对象（仅供追溯，**文件当前不存在**）：

| 原相对路径 | 字节 | SHA-256（上一轮移动时核对值） |
| --- | ---: | --- |
| `基础场景原型/previews/player_hurt_20261116/refs/terraria_vanilla_part6.mp4` | 167,620,280 | `ca90f9c0f4428a745c0bafb26983a4b0d6ec5aa1daa1301867885df0020a5a52` |
| 同目录 `terraria_part6.mp4` | 133,742,351 | `bd5d485255c9a32539f6c851191ceec42c473beffe1abd063c95b019774d6660` |
| 同目录 `terraria_26s.mp4` | 11,608,401 | `7c0279714fc182a586260bb4d71a889c3fc884220e6eb8600d1a80636ed52f8d` |
| `previews/audio_movement_refs_20261117/refs/video/outland_g4tv_gameplay_trailer_2011.mp4` | 7,319,824 | `c0c01440a1f55c12862f286a6346dc3de9bc673b76e044c44f251f423486fab6` |

- 如需重看 Terraria 整片，仍可按 `docs/FLOW_HURT_AUDIO_BRIEF_20261116.md` 记录的 archive.org 地址重新获取；抽帧 PNG/GIF 仍在原位。

## 1. 本批删除（全部为可逆回收站）

**979 个文件，20,413,921 字节（19.47 MiB）**，已逐项送入 **D: 盘 Windows 回收站**；无永久删除、无目录递归删除、无链接/越界。

| 分组 | 文件数 | 大小 | 删除对象 | 保留代表 |
| --- | ---: | ---: | --- | --- |
| G1 invalid 运行截图 | 328（164 PNG + 164 .import） | 3.66 MiB | `opening_hud/invalid_*` 下 captures 派生图 | 每个 `invalid_*` 的 NOTE.txt（若有）、logs/、seq/MANIFEST.json；顶层 captures/ 当前证据 |
| G2 superseded 重复运行 | 112（56 图 + 56 sidecar/log/json） | 1.20 MiB | `_2115`、`_2125`、`_2135` 三套 | `superseded_valid_run_20261117_2105/` 全套 + 顶层 NOTES.md/captures |
| G3 守卫逐帧 | 155 PNG | 4.07 MiB | `level03_demo_finish_20261116/guard/` 42+113 帧 | 同目录 2 个 GIF、2 个 contact 拼图、MANIFEST_GUARD.txt |
| G4 门深度行走帧 | 55 PNG | 1.12 MiB | `level03_gate_depth_20261116/r_walk_*` 中间帧 | r_walk_00/24/48/49/59 + r_gate_walk.gif + g/r 关键静帧 + MANIFEST |
| G5 门嵌入行走帧 | 55 PNG | 1.10 MiB | `level03_gate_inset_20261116/i_walk_*` 中间帧 | i_walk_00/14/28/29/59 + i_gate_walk.gif + i01..i16 + MANIFEST |
| G6 复活过渡条 | 66 PNG | 1.13 MiB | `l3_recovery_20261116/strip/` | transition.gif、transition_review.png、a01..d01 关键帧、MANIFEST/ANALYSIS |
| G7 Celeste 裁切帧 | 208（104 JPG + 104 .import） | 7.18 MiB | `experience_alignment_art_20261117/refs/frames/seq_*` 未引用帧 | SOURCE_NOTES 引用的 12 帧 + 2 张总览 sheet + manifest/HUD_SPEC |

处理原则：

- 先查 `res://`、`.gd/.tscn/.tres`、HTML、文档、测试/生成器引用；删除项均不被运行代码或活页面引用。
- 保留仍能证明结论的关键帧、GIF、contact 拼图、失败 NOTE、日志、manifest 与来源说明，不按“批次所有帧”一刀切。
- 315 个 `.import` 是随源图的 Godot sidecar，与源图一并回收；不单独恢复。
- 删除前后运行中的并行返修文件未触碰；`assets/interaction_projection_20261117/layered_core/`、`scripts/narrative/`、L2/门当前验收证据及其 manifest 全部排除。

## 2. 核对后保留（未删）的素材/截图

| 位置 | 现状 | 保留理由 |
| --- | --- | --- |
| `previews/`（191.43 MiB，1777 文件） | 保留 | 外部参考（Celeste/CrossCode/HLD/Terraria/Outland）、CC0 音频源包与许可证据、BGM/Q 试听源、L3 v2–v7 批准/否决链、roof crack 诊断各版；均被文档/HTML/来源说明引用，或属唯一源 |
| `tests/`（20.38 MiB） | 保留 | 当前 L2/门证据受保护；其余测试入口与日志为现有测试链，未全量清理 |
| `screenshots/`（16.50 MiB，513 文件） | 保留代表 | 关键静帧、GIF、contact、MANIFEST、失效说明 |
| `assets/`（10.40 MiB） | 保留 | 运行依赖；本批未改任何产品文件 |
| `自制素材/`（6.31 MiB） | 保留 | V1/V2/DS01/DS02/DS03、概念稿与生成脚本，属唯一原稿/可复现源 |
| `素材库/`（1.90 MiB） | 保留 | 第三方原包与许可，未据文件名推定 |
| `individual_sheets/` | 保留 | 主角原始 sheet，许可待确认 |
| 根 `微信图片_20261103105157_105_1570.png`（2.07 MiB） | 保留 | 用户原始图片，用途未判 |
| `项目归档/` 旧 ZIP、清理 JSON、旧清单 | 保留 | 历史记录，不覆写 |
| `previews/audio_review_20261116/candidates/` 与运行资源字节相同的试听副本 | 保留 | 试听页/文档仍引用，属对照入口 |
| `tests/logs/` 中同字节旧日志 | 保留 | 日志是独立运行记录，未证明可弃 |

未删的待定项：根用户图片用途、`l3_asset_review` 中间版本能否再压缩、`tests/logs` 的旧日志、两首未接 runtime 的 BGM。

同字节重复另核：全项目 367 组（约 16.4 MiB 冗余），逐一比对后，运行资源、试听页、前后对照与不同运行日志仍分别引用同名/同字节文件，未按“重复”删除；本批只删除已由 GIF/contact/保留帧覆盖的派生序列。

## 3. 校验

- 删除项：979/979 原路径已不存在；0 失败、0 越界、0 链接、0 目录递归删除。
- 回收站：D 盘回收站文件项 119 → 2075（978 个批量文件 ×2 + 测试项已在 119 内），与逐项回收一致；`$I` 元数据抽样可读出原路径（如 `previews/experience_alignment_art_20261117/refs/frames/seq_140_229/f_089.jpg.import`），确认按原路径可还原。
- 侧车：全项目孤立 `.import` 0、孤立 `.uid` 0。
- 产品文件：排除并行返修路径后，624 个 `scenes/`、`scripts/`、`assets/`、`project.godot` 文件（含 `.import`）在删除后与 headless 载入后哈希 **0 缺失、0 变化**。
- 引用：工程内 1228 处字面 `res://` 引用，实际缺失 0；扫出的 5 处为测试故意构造的 `__missing__`/路径前缀。
- 受保护路径均在：`assets/interaction_projection_20261117/layered_core/`、`scripts/narrative/`、`l2_visual_polish_20261118`、`l2_spot_finish_20261118`、`l2_second_platform_v3_20261118`、`screenshots/l3_gate_shadow_20261118`、`level_exit_unfold` 相关证据与 manifest。
- 并行返修在本轮期间自行新增/改动了 L2 第二高台 v3 与 layered_core 文件；这些变化**不是**本清理脚本所为，本记录不做归因。
- Godot 4.7.2 headless 快速载入（`--quit-after 90`，日志 `load_level_01/02/03.log`）：`level_01`、`level_02`、`level_03` 均 exit 0，日志无 ERROR/SCRIPT ERROR。未跑专项测试或自动通关；载入时无其他 Godot 测试进程占用。

## 4. 恢复方式

- 在 Windows 资源管理器打开回收站，按“原位置”还原即可回到上表原路径；哈希逐项见 `manifest.csv`。
- 若回收站已清空，则只能按清单哈希与来源说明重新获取；`.import` 会由 Godot 重新导入生成（证据图不被运行代码引用，UID 变化不影响场景）。
- 本批未动 `待删除/`（其不存在），也未重建上一轮文件。

## 5. 边界

- 未修改根 `README.md`、`TODO.md`、`progress.md`，未改任何产品场景/脚本/资产/文档结论。
- 未操作 Git 索引/提交、工作区配置、同级其他项目或项目外数据（仅 D 盘系统回收站接收文件）。
- 未跑全套测试、未自动通关、未做真人试玩；本轮以 diff/依赖/清单核验为主。
