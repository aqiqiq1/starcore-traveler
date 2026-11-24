# 非运行资料搬移与旧预览测试删除记录（2026-11-19）

本记录对应根目录 `非运行资料/` 的建立与搬移，以及两个报错旧预览测试的回收站删除。旧记录（`整理盘点_20261118.md`、`清理记录_20261118_第二批/`）未覆写。

## 1. 实际搬移

**1666 个文件，105,052,795 字节（100.19 MiB）**，从 Godot 工程内移到工程外同盘目录：

| 分类 | 来源 | 新位置 | 文件数 | 大小 |
| --- | --- | --- | ---: | ---: |
| 预览参考 | `基础场景原型/previews/` 25 个目录 | `非运行资料/预览参考/previews/` | 1343 | 97.13 MiB |
| 历史测试与证据 | `基础场景原型/tests/` 4 个目录 | `非运行资料/历史测试与证据/tests/` | 291 | 2.25 MiB |
| 历史测试与证据 | `基础场景原型/screenshots/` 3 个目录 | `非运行资料/历史测试与证据/screenshots/` | 32 | 0.80 MiB |

- 逐文件原→新路径、字节、SHA-256、恢复方式：`manifest.csv`（1666 行）。
- 每组搬前/搬后逐文件 SHA-256 一致；原路径均已不存在；无目标覆盖、无 reparse/symlink、无路径越界（同盘 `rename`）。
- 移动保留组内相对结构（`previews/<目录>/...`、`tests/<目录>/...`），预览 HTML 的内部相对路径仍可用；`res://` 路径在移出期间不再可用，需按清单移回才能运行历史预览，这是用户允许的预期。

## 2. 删除（回收站）

**6 个文件，42,269 字节**，已确认无运行/场景/HTML 引用，送入 Windows 回收站：

| 原路径 | 字节 | SHA-256 |
| --- | ---: | --- |
| `previews/l2_revision_20261114/tests/art_v2_checks.gd` | 9,964 | 见 `deleted_recycled.csv` |
| `…/art_v2_checks.gd.uid` | 20 | 见 CSV |
| `…/art_v2_checks.tscn` | 213 | 见 CSV |
| `previews/l2_revision_20261114/tests/preview_checks.gd` | 31,824 | 见 CSV |
| `…/preview_checks.gd.uid` | 20 | 见 CSV |
| `…/preview_checks.tscn` | 228 | 见 CSV |

同目录的 `art_v2_checks.log`、`preview_checks.log`、`README.md`、`README_V2.md` 与 `mode2_active_return.*`（其他旧测试）未强删，随 `l2_revision_20261114` 移入非运行资料归档。逐项见 `deleted_recycled.csv`。

## 3. 就地保留

- **运行/导出**：`基础场景原型/assets/`、`scenes/`、`scripts/`、`project.godot`、`export_presets`（若存在）及其 sidecar 未动；冻结中的 `scripts/narrative/`、`assets/interaction_projection_20261117/` 未动。
- **当前验收**：整个 `tests/interaction_projection_20261117/`、`tests/level03/`、顶层测试入口、`tests/logs/`、`screenshots/l3_gate_shadow_20261118/`、`screenshots/level03_*`、`screenshots/l3_recovery_20261116`、`screenshots/flow_hurt_*`、`previews/layered_core*`、`previews/l3_gate_shadow_20261118`、`previews/roof_crack_*` 均保留。
- **活跃试听**：`previews/audio_demo_v2_20261116`、`audio_movement_20261117`、`audio_movement_refs_20261117`、`dialogue_feedback_20261117`、`echo_*`、`hurt_*` 页面引用 `../../assets/` 运行音频，保持原位以免活链接断开；`hurt_e_plus_half` 生成器仍写 `assets/`，也保留。
- **原稿/许可**：`自制素材/`、`素材库/`、`individual_sheets/` 仍被生成器、资产 manifest、测试按项目根相对路径引用，移出会破坏可复现链，故原位保留；见 `非运行资料/素材原稿与许可/README.md`。
- **根文档/归档/用户图**：`README.md`、`TODO.md`、`progress.md`、`项目归档/`、根 `微信图片…png` 未动。

## 4. 核验（本轮只做 diff/依赖/清单，不跑冒烟）

- 搬移：1666/1666 文件搬后哈希一致、原路径不存在；0 覆盖、0 失败。
- 删除：6/6 文件原路径不存在；回收站可还原。
- 活动工程孤立 `.import` 0、孤立 `.uid` 0（搬移目录连同 sidecar 整组移动）。
- 工程内保留代码不再引用被移出的 `res://previews/<目录>` / `res://tests/<目录>` 运行路径；被移出的历史预览/测试自身仍保留内部 `res://` 文本，移回即可恢复。
- 保留代码字面 `res://` 引用 1139 处，实际缺失 0；扫出的 5 处为测试故意构造的 `__missing__`/路径前缀。
- 移出的 45 个 HTML 中，活动试听页面的组内相对链接均可解析；4 个断链均在已保存的外部许可/来源快照（CC deed、OGA 页面）内，属快照外部资源，不是本项目的活试听入口。
- 本脚本只移动 `previews/`、`tests/` 历史子目录、`screenshots/` 历史子目录；未改场景/脚本/资产。并行返修期间 `project.godot`（01:42）与 `scenes/level_02.tscn`（01:56）有自身改动，非本记录操作。
- 三关冒烟与全套测试按协调要求待并行首台工作结束后统一进行；本记录不以清单/静态检查代替运行验收。

## 5. 恢复

见 `非运行资料/README.md`、各旧目录新增的 `README_MOVED_20261119.md` 和 `manifest.csv`。恢复时同盘移回原路径，先比对 SHA256，禁止覆盖。
