# 紧凑顶部 HUD（2026-11-14）

状态：两关正式 HUD 顶部已统一；玩法/地形/人物/对白/背景/L2 状态与恢复未改。

## 改动

- 新增 `scripts/ui/compact_level_header.gd`（`CompactLevelHeader`）共享组件。
- `scripts/level_hud.gd`、`scripts/level_02_hud.gd` 仅替换顶部标题与相性块，改用它；状态块、提示/toast、恢复提示、完成页、暂停菜单与可见性时机不变。
- `get_polarity_text()` 保持；新增 `get_compact_header()` 供聚焦测试。删除旧 `_polarity_panel` 后 `set_polarity()` 不再碰空 panel，只更新共享 header。

## 规格

- 左上：`断桥庭院 / 第一关`、`沉寂回廊 / 第二关 · 石栅通路`；两行均 12px，位置 (12,7)/(12,23)，TEXT_WARM `#e8e2d5` / MUTED `#9fb0b2`，1px `OUTLINE_DARK`。
- 右上：正式 `assets/talisman/talisman_gold.png` 或 `talisman_cyan.png` 原生 5×5，`TextureRect` 20×20（精确 4× Nearest），右接 12px `辉相/澜相`，颜色金/青；图标右缘 600，文字 606..630，右侧留 10px。
- 无 Panel、无“护符相性” caption、无 24px 顶部巨字、无常驻 Q 行；全部 mouse ignore。两关几何完全一致。
- 图标/文字随真实 Q 与 R 切换；L2 新任务/星核/联动记录块仍在 y54，底部失败恢复仍在 y336。

## 验证

- `test_compact_header` **75/0**：两关 12px 字、20×20 5px源、Nearest、右边界/垂直对齐、无 Panel/旧 caption/Q/隔离预览；真实 Q 金青、R 回金、暂停/完成页无空引用、标题菜单隐藏 HUD 后进入恢复。
- L1/L2 headless 载入退出码均 **0**。
- `--headless --editor --import --quit` 重扫退出码 **0**；`CompactLevelHeader` 等类路径均在 `res://scripts/`，无重复 class/解析错误（`tools/verify_class_cache.py` 通过）。
- 保护：`tools/compact_header_protection.py` 212 文件，新增 1（共享组件），授权 2（两 HUD），未授权 **0**；旧保护 77 项亦 0 未授权。

## 截图（真实 640×360，已打开）

- `screenshots/compact_header_20261114/01_l1_cyan.png`（L1，真实 Q 后青相；固定玩家 x100 的实机 setup）
- `screenshots/compact_header_20261114/02_l2_gold.png`（L2 真实出生，辉相）
- `screenshots/compact_header_20261114/header_compare.png`：上两张各裁顶 0..48 后竖排的 640×96 派生对照，未改色/重绘。

## 未验/注意

- 用户若仍开着改前 GUI 编辑器/debug，进程未强杀；新增全局类可能需要重新打开工程才会进入编辑器内存，已保存场景不受影响。
- 本次未重跑旧全量或整条运输路线；只做上述 HUD/载入/输入聚焦检查。

## 协调者复核

- 已打开顶部对照与L2全帧，核12px小标题、右侧放大图标/两色、无框与任务块间距；审共享header与Q/R/显隐测试代码，未重跑75项或运输全程。
- 独立运行保护：212项中仅新增共享组件1、修改授权HUD2，未授权变化0；独立类索引检查确认新组件及原5类均指正式scripts、归档引用0，原10份备份hash一致。
