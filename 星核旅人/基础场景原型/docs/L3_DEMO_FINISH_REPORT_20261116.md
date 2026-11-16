# 第三关Demo末关收尾 · 实施报告（2026-11-16）

范围：按 `docs/L3_DEMO_FINISH_BRIEF_20261116.md` 与 `docs/L3_DEMO_FINISH_WALL_DETAIL_20261116.md`。
门 2380 / 墙 2292..2612 / 完成 2460 / 电影 2310 / 相机地面 2520 未动；前段、符石共享数值、130 台、守卫、音频、电影、玩家、共享 UI、L1/L2 未改。
守卫脚本本轮**只读**。未提交、未推送。

## 1. 根因与实际修法

### 1.1 完成后“返回主界面/重玩”无反应
- **根因**：`scripts/level_03.gd` 只连了暂停菜单的 `restart_requested/return_to_menu_requested`，
  **HUD 的 `replay_requested/return_to_menu_requested` 从未被连接**。按钮自己 emit 了，没人接。
  与 F6/F5 入口无关。
- **修法**：`_ready` 用 `is_connected` 各连一次；`_on_hud_replay_requested` → 等 2 帧 → `_restart_level()`；
  `_on_hud_return_to_menu_requested` → `_return_to_main_menu()`。暂停菜单那条旧连接保留。
- **重玩后能真动**：`_restart_level` 复位稳定阶段/守卫三格/初始核/装置/门/检查点，再走
  `_player.reset_to_spawn()`；L3 子类在这里清 `_completion_locked` 与输入覆盖。
  额外用现有输入覆盖挡 3 个物理帧：实测不加时，完成页按 Space（按钮确认）会在重启后第一帧
  变成跳跃（y 320→313.7、vy=-375）；加了之后 y 恒 320、A/D 正常。
- **返回**：先确认 `level_01.tscn` 存在 → 中止电影/挂起守卫/清输入 → 暂停菜单 `prepare_scene_change()`
  → `LevelFlow.return_to_title()`（真实 `SceneTree.change_scene_to_file`）。
  `_verify_title_transition` 若发现仍停在本场景，就恢复按钮并显示“无法返回主界面”，不会永久禁用。
- **页面文案**（沿用现 PixelMenuButton/面板样式，不新画 UI）：标题 **感谢游玩**、
  副文 **本次试玩到此结束**、按钮 **返回主界面** / **重玩本关**，
  提示行 `Enter / 空格 确认 · Tab 切换 · R 重玩 · Esc 暂停`。R 走现暂停菜单的 `reset` 轮询。

### 1.2 墙底透出人物、右沿漏
- **实测**（同帧“人物可见/隐藏”像素差，真实引擎）：

| 位置 | 修前可见像素 | 修后 |
| --- | --- | --- |
| x=2455 idle / walk / attack | 18 / 18 / 30（y 316..320；walk/attack 另有 1px 竖缝 y 295..319） | **0 / 0 / 0** |
| x=2414、2446 | — | 0 |
| x=2398、2406 | 门洞里应有的部分可见（149 / 43 px） | 同（未改遮挡关系） |

- **原因**：人物所有动画（idle/walk/run/jump/fall/fall_loop/combo）alpha 最低行都是 frame y=79 →
  世界 y=320..321；前景美术底边却停在 world 319（门楼右塔基座到 322），门楼右塔最后一列美术在
  world 314 截断（8px 缺口 + 5 个 1–2px 透明点）。所以墙下恒有 1px 人物带、右沿有 1px 竖缝。
- **修法（未 hide/alpha/改脚底/加碰撞）**：
  - 右前景墙段 `base_drop = 3`：同基座石补 world 320/321，world 322 一条深色接触行，与门楼基座同底。
  - 门楼自身脚：在其原色上补 22×3 行（94,84,88 石面 + 60,52,57 接触行）。
  - 右沿：1px 深色列（60,52,57）放在右前景精灵**之下**，艺术自身透明点仍显示这层深色，接成塔身边线。
- 视觉前后对照：`f19_foot_before_after_6x.png`（上=修前，下=修后，同一帧同机位）。

### 1.3 右端旧素材
- 隐藏/显示 `Decorations/ColumnCityLeft`、`ColumnCityRight` 的同帧差 = **0 像素**（早前实测，墙后完全不可见）。
  按授权已从 `scenes/level_03.tscn` 移除这两个无用实例；`assets/bridge_stone_v1/columns/*` 原文件只读未改。
- **未复现**：除这两根柱外，当前代码在右端没有找到其它“旧素材”实例（`capture_l3_demo_finish_audit` 已列出
  2200 以右全部 CanvasItem）。门楼右塔（2396..2452）是已批准的“门嵌墙”构图，地面条是既有地形。
  若用户所指仍是别的残件，请指图。

### 1.4 城墙细化（按补充规格）
- **参考**：本轮实际打开 `previews/l3_wall_detail_20261116/refs/sotn_outerwall_stone_crop.png` 与
  `sotn_entrance_stone_crop.png` 看结构；门/人物层次沿用此前 PoP 连续帧结论（本轮不改门运动）。
  借用：腰线/檐口“亮面+暗底”分层、每开间固定节奏的窄龛、柱头外挑、低对比错缝、基座接地；
  不借：紫夜/红砖/窗玻璃/阳台/垛口/任何第三方像素，墙顶仍出画。
- **已落数值**：腰线 world 104..107（1px 亮+2px 石带+1px 暗底+下投影）；壁柱柱头 6px、外挑 2px；
  柱脚 8px 并入 world 196 檐线；每上部开间一处**盲拱龛 16×36**，底 world 164，三级 2px 阶梯拱头，
  1px 亮左/2px 暗右/暗底，龛内 (76,67,72) 只比墙面 (88,79,83) 稍暗（不发光、不是纯黑窗），
  另加 1px 出挑窗台；16/24 世界网格错缝不变；约十分之一石块有 1px 缺角 / 2–4px 短裂 / 极低对比色差
  （固定哈希，重绘不闪变），且只在上部、门周克制。
- 背景面与右前景用同一份 `_draw_front` 与世界网格裁剪，接缝无图案跳变；无碰撞、无新贴图、无第二门。

## 2. 落盘文件

- 变更（5）：`scripts/level_03.gd`、`scripts/level03/l3_hud.gd`、`scripts/level03/l3_gate.gd`、
  `scripts/level03/l3_gate_depth_wall.gd`、`scenes/level_03.tscn`（仅删两根旧柱实例）。
- 新增测试（前缀授权内）：`tests/level03/test_l3_demo_finish.{gd,tscn}`、
  `capture_l3_demo_finish.{gd,tscn}`、`capture_l3_demo_finish_guard.{gd,tscn}`、
  `capture_l3_demo_finish_probe.{gd,tscn}`、`capture_l3_demo_finish_audit.{gd,tscn}` 及同名日志。
- 证据：`screenshots/level03_demo_finish_20261116/`（f01..f19、`MANIFEST_FINISH.txt`、`probe/`、`guard/`）。
- 保护：`.openchamber/verification/l3_demo_finish_20261116.py` →
  **UNCHANGED 1338 / CHANGED 5 / ADDED 21 / MISSING 0，OVERALL OK**（旧 before 未覆盖）。

## 3. 实测

| 项 | 结果 |
| --- | --- |
| `test_l3_demo_finish.tscn` | **47 PASS / 0 FAIL，DEMO_FINISH_OK** |
| `test_level03_load.tscn` | 34/0，`LEVEL03_LOAD pass=34 fail=0` |
| `test_l3_gate_depth.tscn` | 72/0，`GATE_OK` |
| `test_level03_revision.tscn` | 194/0，`REVISION OK` |
| 1343 保护 checker | 见上，OVERALL OK |

- 键盘/鼠标均为真实事件，不是 `emit pressed`：viewport `push_input`（鼠标按下/松开）+ `Input.parse_input_event`
  （Tab/Enter/Space/Q/E/D/J/R，走真实 InputMap 与节点 `_input`）。
- 关键链（真实输入）：真实走入 2460（x=2460.3）→ 页面 → **鼠标点重玩** → 页面关闭、
  `is_completed()=false`、`is_completion_locked()=false`、位置 (40,320)、稳定阶段 0、守卫三格、初始核回起始仓、
  门关闭且有碰撞 → **真实 D 移动 40.1px**（y 保持 320）→ 第二次完成（setup+真实 E+真实走）
  → **鼠标点返回** → `current_scene = Level01 / res://scenes/level_01.tscn`，L3 场景被释放、测试驱动仍存活；
  另测 harness-owned（无 current_scene）与 **Enter** 聚焦主按钮两种路径同样真实切场。
- 日志：专项/载入/门/探针无 ScriptError、无 Parse Error、无资源错误。`test_level03_revision` 有一次非 verbose
  运行出现退出期 `WARNING: 4 ObjectDB instances were leaked at exit`；随后重跑（含 `--verbose`）不再出现，
  该文件注释已说明这是 Ogg 流在进程退出期的老警告，不是功能失败，也不是本轮新增对象。

## 4. 图证（`screenshots/level03_demo_finish_20261116/`）

| 文件 | 内容 |
| --- | --- |
| `compare_before_after.png` | 左=旧 i01（同布局旧代码），右=f01（本轮）；下排为墙区放大 |
| `f01_wall_detail_640.png` / `f02`(3×)/`f03`(4×) | 门嵌墙 + 城墙上部细化（腰线、柱头柱脚、盲拱龛、低对比磨损） |
| `f04..f10_walk_*.png` | 真实按键从 2301 走到 2452：门前可读 0.00 → 门中 → 右柱 0.46/0.78 → 右塔/墙后 1.00 |
| `f11_wall_foot_full.png` / `f12`(5×) | 身体完全在墙后时，墙脚/右沿无人物像素 |
| `f13_right_end_zoom5x.png` | 右端墙身、壁柱、龛、基座连续；旧柱实例已移除 |
| `f19_foot_before_after_6x.png` | 墙脚 6× 前后对照（上=修前有红/肤带，下=修后无） |
| `f14_completion_page.png` | 感谢游玩 / 本次试玩到此结束 / 返回主界面 / 重玩本关 / 提示行 |
| `f15_replay_spawn.png`、`f16_replay_moved.png` | 鼠标重玩后出生状态与真实移动 |
| `f17_second_completion.png`、`f18_level01_menu.png` | 第二次完成；鼠标返回后的真 level_01 主菜单 |
| `guard/a_pre_teaching_ordinary_hit.gif`（42 帧） | 真实 J：教前普通一击 → 碎石 → 等教学；三格 3→3 |
| `guard/b_post_teaching_ordinary_hit.gif`（113 帧） | 真实 J：教后普通一击 → 碎裂 → 重组；三格 3→3（蓄力阶段三格条可见） |
| `probe/`、`guard/*_contact.png` | 像素差测量帧与关键帧拼图；`probe/d01_before_fix_*`（关掉脚部/右沿补齐的同一版本 A/B 前）与 `d02_after_fix_*`（现行代码）是保留的前后对照 |

> 证据更正说明：断电前 15:11 的旧探针帧在同一 `probe/` 目录同名重跑时被覆盖；保留的“修前”证据改为
> 同版本 A/B（`d01_before_fix_*`，仅运行时关闭 3 处补齐，不改文件）与 `f19_foot_before_after_6x.png`，
> 修前计数 18/18/30 与修后 0/0/0 都来自真实引擎像素差。`screenshots/level03_gate_inset_20261116/` 等旧目录未删。

## 5. 无效受击：实测到的事实（未改规则）

- 两段都是真实 J：教前 42 帧→`WAIT_RUBBLE`，教后 113 帧→碎裂后重组回 `ACTIVE`；两次 `get_remaining_marks()` 都是
  3→3、`true_marks_taken=0`。帧序列连续（碎石停在最后一帧，重组从最后一帧回退），锚点在守卫脚底，未发现缺帧/重复帧/错锚点。
- **音效缺陷（明确的期望/实际，供协调决定，本轮未改）**：
  - 实际：教前普通一击**完全没有声音**（攻击后 10 帧 `get_last_played()` 仍为空）；教后普通一击只在**开始重组**时
    播 `reassemble`，碎裂瞬间无声；J 本身也没有挥击/命中音。
  - 期望：无效命中至少要有一次“挥击/石壳碎裂”反馈音，而不是只有安静地碎掉。
- 主观观感（“表现不满意”）仍需用户指认具体段：闪白时长、碎裂速度、碎石停留、重组位置/速度、还是缺音效。
  本轮只读，不改生命/状态机/蓄力/时长。

## 6. 未验 / 待你复核

1. 未做真人整关试玩；以上完成链是明确 setup（门恢复点）+ 真实输入，不是整关通关记录。
2. 审美主观项未获认可：腰线/盲拱龛/磨损的疏密与深浅、门楼与墙的明暗差、加厚 3px 基座是否合意。
3. 用户所说的“右侧旧素材露出”未能复现；已按 A/B 移除两根完全被墙盖住的旧柱实例，其余请指图。
4. 音效缺陷（见 5）未修：需要协调确认后再动音频。
5. 完整 640×360 正常镜头与 2× 窗口缩放的最终观感，建议你在实机再走一遍门前→门中→墙后与完成页。

## 7. 协调独立关键复核

- 独立运行`test_l3_demo_finish.tscn`：47 PASS / 0 FAIL，`DEMO_FINISH_OK`，退出0，无ScriptError/解析或资源错误；保留`tests/level03/test_l3_demo_finish_coordinator.log`。这是引擎注入键鼠事件的自动关键节点测试，不是人工操作或整关通关。
- 独立原1343项保护：1338不变 / 5授权修改 / 22授权新增 / 0缺失，OVERALL OK。新增数比工程报告多1为协调日志；守卫、音频、电影、共享玩家/UI、L1/L2及原资产未改。
- 已实际看正常640图f01、门中f06/右柱遮挡f08/墙后f10、墙脚同版本A/B放大f19、感谢页f14、真实主菜单f18，以及两段守卫关键帧拼图。门前人物可见、过右柱逐步遮、墙脚补齐与窄龛/腰线可读；不把几何覆盖率当实际像素面积，也不将拼图当完整节奏听审。
- 已核工程载入34/0、门72/0、revision194/0完整摘要及相关日志错误关键词；这些三项仅审日志，没有无必要重复全跑。只完成页专项与保护为本轮协调独立重跑。
- **交付边界**：完成按钮/感谢页、已复现墙脚漏像素、城墙细化可交创作者继续试玩；“右侧旧素材”的具体对象仍未复现，移除A/B不可见旧柱不证明修中了用户对象。受击两段已录但不改规则/节奏；音效事件未触发是代码/日志观察，未进行独立听审，不等于确认这是用户不满意的主因。
- 旧probe同名覆盖已在第4节明确更正，不把新生成图当断电前原证据。没有提交推送、没有打包或公开发行许可结论。工程已停手，下一步由创作者F6核画面并指认受击/右侧残件。
