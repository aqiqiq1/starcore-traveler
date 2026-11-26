# UI 图标（2026-11-27 美术审计）

本目录只放**独立图标资产**，不改 `scripts/ui/*.gd` 的 HUD 绘制代码。现有三关与三章 HUD 仍按 `polarity_phase_icon.gd` / `hit_pips.gd` / `key_glyph.gd` 运行时绘制；这些 PNG 供后续统一替换或说明页/预览使用。

| 文件 | 尺寸 | 用途 | 边界 |
| --- | --- | --- | --- |
| `affinity_sun_20.png` | 20×20 | 辉相（金太阳）带深色底板 | 1 px 深边 + 18×18 底板 + 1 px 相性描边；与 HUD 同几何 |
| `affinity_moon_20.png` | 20×20 | 澜相（青月）带深色底板 | 同上；月牙缺口用底板色，不透明 |
| `heart_10.png` | 10×10 | 生命/受击红心 | 1 px 深边；生命红 `#d95757`，高光 `#ff7b7b` |

- 色值：金 `#f4cd63`、青 `#5fe1e6`、生命红 `#d95757`、末格红 `#ff7b7b`，与 `dlc/PRESENTATION_SYSTEM.md` 第 2 节一致；没有新增第五套强调色。
- 键帽仍使用 `assets/ui/keycaps/` 现有 18×18 源图（Q/J/E/F/R/Enter/Esc/Shift/Space），由 `scripts/ui/key_glyph.gd` 按 `INLINE_HEIGHT=16` 等比显示为 16 px 高；本轮未改、未覆盖。审计确认其深蓝底 + 金字的样式与图标底板一致。
- 生成：`dlc/star_loom/tools/gen_city_assets_v2.py` 的 `make_ui_icons()`，Pillow 程序化绘制，无第三方像素/下载素材。
- 预览：`screenshots/art_audit_20261127/ui_icons_4x.png`（4× 最近邻，非运行时引用）。
