# 章节入口（2026-11-27）

标题页 `开始游戏` 下方新增单行 `章节`，打开同一标题场景内的章节列表；不新建独立网格页、不新建标题场景。

## 入口与解锁

| 序 | 章节 | 场景 | 前置 | 行可见 |
|---|---|---|---|---|
| 1 | 断桥庭院（L1） | `res://scenes/level_01.tscn` | — | 常驻 |
| 2 | 沉寂回廊（L2） | `res://scenes/level_02.tscn` | L1 通关 | 常驻 |
| 3 | 断桥外郭（L3） | `res://scenes/level_03.tscn` | L2 通关 | 常驻 |
| 4 | 星核织机·城内（DLC3 / 第四关） | `res://dlc/star_loom/star_loom.tscn` | L3 通关 | 常驻 |
| 5 | 星核试炼场（DLC1 / 支线） | `res://dlc/trial_chambers/trial_chambers.tscn` | L1 通关 | 进入 L3 试炼碑后 |
| 6 | 裂隙工坊（DLC2 / 支线） | `res://dlc/rift_workshop/rift_workshop.tscn` | L2 通关 | 进入 DLC3 镜面裂隙后 |

- 前四行主线常驻；`trial / rift` 两行只在 `discovered_trial / discovered_rift` 为 true 时出现，发现不等于通关。
- 未解锁行 `disabled`：不可聚焦、鼠标穿透、右侧写 `需先完成 X`。隐藏行同样不可聚焦/点击，并且不加入 ↑↓ 环。
- `Esc` / 鼠标 `返回` 回到标题；↑↓ 只在可见且已解锁行之间循环。
- `开始游戏` 指向列表顺序中第一个未通关、已解锁、已发现且场景存在的章节；全通后回 L1。
- `已完成 N / M` 的 M 只计当前可见行：发现前为 4，发现两个支线后为 6。

## 进度文件

`user://chapter_progress.cfg`，`[chapters]` 下 6 个完成 bool：`l1/l2/l3/loom/trial/rift`，再加两个支线发现 bool：`discovered_trial/discovered_rift`（默认 false；旧文件只有六个完成 bool 时按未发现读取，不崩）。完成只在六个完成回调里写；发现由两个入口在进入时立即写：

- `scripts/level_01.gd` `_on_exit_reached`
- `scripts/level_02.gd` `_try_complete_at_exit`
- `scripts/level_03.gd` `_complete_city`
- `dlc/star_loom/star_loom.gd` `_complete_chapter`
- `dlc/trial_chambers/trial_chambers.gd` `_complete_trial`
- `dlc/rift_workshop/rift_workshop.gd` `_complete_chapter`

缺失/损坏文件读为全 false（只开 L1），不崩；检查点、音频、显示设置文件互不影响。六个关卡脚本各有 `chapter_progress_path` 导出（默认空 = 共享路径），测试可指向临时文件。

## 验证

```powershell
# 功能/解锁/焦点/入口/完成回调
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . `
  res://dlc/chapter_select/tests/chapter_select_test.tscn

# 640x360 证据（非 headless）
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 --path . `
  res://dlc/chapter_select/tests/capture_chapter_select.tscn
```

截图输出到 `screenshots/chapter_select_20261127/`。

## 边界

- 标题页不再有 `试炼场 / 裂隙工坊 / 星核织机` 直达行；DLC 只从章节页或主线里的隐藏入口进入。
- 本章节页没有缩略图、完成度星级、章节回顾或存档槽；只做批准的 6 项列表（发现前显示 4 行）。
- `trial / rift` 从标题页进入（发现后）时仍按普通章节结算为 `返回主界面`；只有从主线隐藏入口进入的支线，完成页才显示 `继续主线` 并回到原章节。
- `dlc/chapter_select/reference/` 是外部参考截图，`.gdignore`，不参与导入/导出。
