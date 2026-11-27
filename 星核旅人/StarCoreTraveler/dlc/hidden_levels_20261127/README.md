# 隐藏支线入口（DLC1 / DLC2）

DLC1 星核试炼场与 DLC2 裂隙工坊不再从标题直接出现。它们变成两个主线里的可选入口；章节页在玩家真正进入入口之前不显示这两行。

## 入口

| 支线 | 主线位置 | 坐标 | 提示 |
|---|---|---|---|
| DLC2 裂隙工坊 | DLC3 星核织机，检查点之后、Boss 竞技场触发之前 | `x=420`（检查点 `x=410`，竞技场触发 `x=430`） | `镜面裂隙 · 可进入支线` |
| DLC1 星核试炼场 | L3 断桥外郭，城门之前 | `x=2250`（城门 `x=2380`，城终点 `x=2460`，距终点 210 px） | `试炼碑 · 可进入支线` |

- 两个入口都是无碰撞的背景节点：镜面用 `mirror_face_cyan_broken_48x48.png` + 冷石壁龛/青色裂缝；试炼碑用 `tutorial_stele_cyan.png` 原生 26×52 + 低石座。没有新动词、没有常驻提示、没有新 PNG。
- 玩家靠近 56 px 时由 `ApproachHint` 只提示一次；离开 200 px 后可重新触发（10 s 冷却）。E 使用现有 `interact` 动作进入。
- 进入即写 `discovered_trial` / `discovered_rift`，不要求通关。

## 进入与返回

- 入口把来源章节、返回位置和 L3 的主线状态快照写进进程内静态 `SideRoute`，然后执行真实 `change_scene_to_file`。
- 支线通关后，完成页的主按钮由 `返回主界面` 改成 `继续主线`；按钮发 `mainline_requested`，支线做完整清理后 `SideRoute.return_to_origin()`。
- 支线中途暂停/失败回标题时走原 `return_to_title()`，同时 `SideRoute.abort()`：不写通关、不留下恢复种子。
- 从标题章节页（发现后）进入支线时 `claim_entry()` 为 false，完成页仍是 `返回主界面`，不会误回主线。

### 回到 DLC3（镜面裂隙）

使用 `StarLoom.resume_from_side` 一次性种子（正常开局为 false）：

- 玩家回到检查点 `(410, 320)`，检查点标记为已记录；
- 青核放在仓内 `socket_x=330`，仓为 occupied；
- 第一道门恢复为辉相（玩家辉相，门开）；第二道门由仓+检查点供电，代理为澜相，门幕可通行（`is_second_gate_powered()` 与 `get_gate_second().is_open()` 均为 true）；
- 不重播开场电影/说明页，Boss 未启动；
- 入口提示被压制 3 s，HUD 显示 `回到检查点 · 继续主线`。

### 回到 L3（试炼碑）

`Level03.resume_from_side` 使用入口时拍下的真实快照：

- 玩家回到进入试炼碑时的位置（通常在 `x≈2250` 城门前）；
- 守卫击败/未击败、钥匙已取/已嵌入、城门开/关、检查点记录、`_stable_stage`、近门回响电影已播状态都按快照恢复；
- 稳定出生点改为返回位置；检查点标记与 HUD 目标同步；
- HUD 显示 `回到城门前 · 继续主线`。

## 进度字段

`user://chapter_progress.cfg` 的 `[chapters]` 新增：

```ini
discovered_trial=false
discovered_rift=false
```

- 旧文件只有六个完成 bool 时照常读取，两个发现字段按 false。
- `kskbl` 仍一次写满：六章完成 + 两个发现 true。
- 章节页前四行常驻；`trial/rift` 行只在发现后 `visible=true`，锁定规则不变（`requires` 仍是 L1/L2）。
- `已完成 N / M` 的 M 只计当前可见行：发现前 4，发现后 6。

## 验证

```powershell
# 功能：字段、章节页、两个入口、56 px 提示、进入/中止/通关返回
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . `
  res://dlc/hidden_levels_20261127/tests/hidden_levels_test.tscn

# 640x360 截图（非 headless）
D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 --path . `
  res://dlc/hidden_levels_20261127/tests/capture_hidden_levels.tscn
```

截图输出到 `screenshots/hidden_levels_20261127/`，说明见该目录的 `CAPTURES.md`；参考核看见 `REFERENCE_20261127.md`。

## 边界 / 未做

- 没有给支线做新的剧情、配音、额外奖励或独立章节介绍页。
- 没有把两个入口做成可破坏墙/新机关；它们是现有素材的静态背景入口。
- DLC3 的返回位置按需求固定在检查点，而不是入口 `x=420`；L3 则回到进入时的真实位置。
- 支线完成后再次站在入口 56 px 内仍会看到“可进入支线”的一次提示（发现/通关状态没有改提示文案）；这是现有 `ApproachHint` 的通用行为，未新增第二套文案。
