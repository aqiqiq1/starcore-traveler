# 第三关城门升降与景深 · 实施和复核（2026-11-16）

> 当期历史复核，不用于判断现版启动入口和最终入城表现；见[当前紫晶与门效](L2_GATE_VISUAL_POLISH.md)。

**当前状态：重启续修与协调独立关键复核完成，可交创作者继续F6试玩。最新结论见末节；下文暂停现场、早期窄遮挡和未配对侧面的记录保留为历史，不再代表当前实现。**

状态：**暂停，未完成，未符合用户新图要求**。用户在实施中发来新图，指出拱外侧夹缝附加壁柱左右不对称、
整张固定立面在门前左侧就盖住玩家、右侧大墙与门楼脱节；要求先停手，等协调按新规则核看经典**像素**
游戏门体/遮挡/建筑连接的统一参考简报与层次边界后再续。本文件只记录现场与我已改/新增的文件，
**不代表这些视觉问题已修，也不宣称本轮已交付**。未回滚已落盘改动，未提交推送，未动共享/L1/L2/旧资产。

## 1. 本轮已落盘的内容（仅供续作接手）

- `scripts/level03/l3_gate.gd` 重写为分层门：
  - 从原 144×160 三张 PNG（闭/填/开）派生固定立面、可动门板（闭/填）、暗通道与门洞掩膜；
  - 固定立面含双塔/拱/门楣与**拱两侧的内柱**；门板只做上移，门板作为暗通道层的子节点被门洞 alpha 裁剪；
  - 嵌核短反馈 → 约 1 s 上移；通行高度（progress 0.62）后才解除实际碰撞；`door_opened` 只发一次；
  - 无 Tween，暂停时进度与碰撞同步冻结；`reset_state()` 恢复门板位置/空孔/碰撞；
  - 24px 孔/16px 核/E 距离/`CITY_ENTER_X=2360` 未改。
- `scripts/level03/l3_gate_depth_wall.gd` 新增：右侧前景建筑墙，沿用项目已批准的暖灰石材 strip
  平铺 + 错缝，无碰撞，窗户/顶边不出现矮黑砖/黄圈/第二拱门。
- `tests/level03/test_l3_gate_depth.gd/.tscn` 新增门定向测试；`tests/level03/capture_l3_gate_depth.gd/.tscn`
  新增实机截图脚本（保存前断言状态）。

## 2. 已改 / 新增文件路径

改：
- `scripts/level03/l3_gate.gd`

新增：
- `scripts/level03/l3_gate_depth_wall.gd`（+.uid）
- `assets/level03_gate_depth/gate_fixed.png`、`gate_plate_closed.png`、`gate_plate_filled.png`、
  `gate_passage.png`、`gate_aperture_mask.png`（各含 `.import`）、`manifest.json`
  （来源与派生方式见该 manifest；原 `assets/level03_prototype/gate_*.png` 只读未改）
- `tests/level03/test_l3_gate_depth.gd`（+.uid/.tscn）
- `tests/level03/capture_l3_gate_depth.gd`（+.uid/.tscn）
- 临时诊断脚本（非交付，检查器报“未授权新增”即这 4 个）：`tests/level03/probe_gate.gd/.tscn`、
  `probe_gate2.gd/.tscn`
- 实机截图目录 `screenshots/level03_gate_depth_20261116/`：`g01` 关闭、`g02` 嵌核、`g03/04/05`
  25/50/75%、`g06` 全开、`g07_gate_left/right` 与 `g07_inner_pillars_zoom.png`、
  `g08_doorway_right_pillar.png`、`g09_behind_right_wall.png`、`g10_city_completion.png`、
  连续帧 `g_rise_00..09.png` 与 `g_gate_rise.gif`（均由真引擎帧生成）、`MANIFEST.txt`
- `docs/L3_GATE_DEPTH_REPORT_20261116.md`（本文件）

## 3. 已跑检查（当前代码的实际结果）

- `tests/level03/test_l3_gate_depth.tscn`：**44 PASS / 0 FAIL，GATE_OK，退出码 0**
  （分层 z 与固定门板、双拱内柱同尺寸/同顶、墙无碰撞且高于画面上缘、真实 E、单调上移、
  固定立面/内柱不动、碰撞在通行高度释放、`door_opened` 一次、暂停冻结、reset、关门挡人、
  开门可走、未过 2360 不结算、跨 2360 才完成）。
- `tests/level03/test_level03_revision.tscn`：**194 PASS / 0 FAIL，退出码 0**（门重写后的回归）。
- `tests/level03/test_level03_load.tscn`：**未通过**——`test_level03_load.gd:93` 调用了旧访问器
  `gate.get_barrier_layer()`，新门脚本未保留该函数，`_ready` 抛 Script Error 并在打印
  `LEVEL03_LOAD` 前中止（进程退出码仍为 0，但日志不完整）。续作需二选一：在门脚本补回
  兼容访问器（返回 `_door_body.collision_layer`）或更新该断言；本次按“停手”要求未改。
- 窄基线 `l3_gate_depth_20261116.py`：**UNCHANGED 1310 / CHANGED 1（l3_gate.gd）/ ADDED 25 /
  MISSING 0，OVERALL FAIL**；FAIL 仅因为 4 个临时 `probe_gate*` 不在授权前缀内，其余新增均在
  `assets/level03_gate_depth/`、`scripts/level03/l3_gate_depth*`、`tests/level03/test_l3_gate_depth*`、
  `capture_l3_gate_depth*`、`docs/L3_GATE_DEPTH_*` 授权范围。续作可删除或移出这些临时探针。

## 4. 未完成 / 已被用户新图否定、不得声称已达标的点

1. **拱外侧夹缝的附加细壁柱**：左有、右缺。我的 `get_inner_pillar_world_rects()` 只覆盖拱两侧
   的两条内柱，**不是**用户红框指的夹缝壁柱；未做镜像/补齐，也未定位其像素来源。
2. **门前遮挡错误**：整张 `FixedFacade` 固定层 z=10 高于玩家 z=5，导致玩家在门前左侧就被整座
   立面盖住；用户要求**只有过门后由右侧**遮挡。当前层次顺序需要重做（不是只调数值）。
3. **右侧大墙**：目前是一整块与门楼仅左缘相接的高墙，用户读作“脱节丑大块”；需要按新的参考
   简报重做与门楼连成建筑的关系（轮廓、连接、尺度、层次）。
4. **参考核看**：按新 `AGENTS.md`，需要先实际核看经典**像素**游戏的门体/遮挡/建筑连接连续画面
   再定稿；本会话尚未完成，不能以 HK 静图或本项目 z/裁片数字代替。
5. `test_level03_load` 的 `get_barrier_layer` 兼容问题（见第 3 节）。

## 5. 续作建议的最小步骤（待协调参考简报）

- 先按简报定“门前可见/过门后遮挡”的层次边界与壁柱对象，再决定是否要新的派生掩膜/分层；
- 再修门楼与右侧墙的连接轮廓（用已批准石材 strip 与门楼像素语言），最后重拍连续帧；
- 恢复 load 断言兼容后统一跑：门测试 → load → revision → 窄 1311 检查器。

本文件不把上述截图当“已符合用户新图”的证据；截图只是当前实现的现场记录。

## 重启后续修与证据（2026-11-16 12:00–12:35）

本节是重启后的续作记录。上文第 1–5 节是暂停现场，保留不改；下列结果只针对“重启后续作定稿”那一段。
**本文不替代用户的画面复核**，只记录我实际做/实际看到的。

### 1. 参考与必须纠正的研究推断

- 按新 `AGENTS.md`，呈现修改前已读协调留下的 `previews/l3_gate_classic_research_20261116/reference_review.md`
  与 `sources.txt`（PoP DOS 170.90–171.40 升门、171.80–172.80 穿门；SotN 入口建筑）。本轮没有另做参考核看，
  以协调已核过的证据为准，边界：PoP 只证明“只有门板动、窄框不在入口整片盖人”；SotN 只证明“基座/壁柱/横带
  组织建筑”，不证明遮挡动画。
- **纠正一（对象错了）**：用户红框的“拱外侧夹缝附加细壁柱”**不是门图里的 4px 左拱柱**，也不是
  `get_inner_pillar_world_rects()` 里的两条内柱。它是场景独立装饰节点 `Decorations/ColumnArenaRight`
  （`doric_column_broken.tscn` 实例，position `(2180, 320)`，z 0）。门楼在 `(2220, 320)`、`IMAGE_LEFT = -72`，
  该装饰落在门图 **x≈32**，正好在固定立面左侧夹缝的透明区（孔 x36..42）后面，所以从门缝里透出来。
  研究里“把左边那根柱复制到右边”的建议**不成立，未采用**。
- **纠正二（起点坐标）**：没有照研究的“右沿 +40”。右沿取**真实右拱柱的内沿**：立面图 x88..93
  （右柱其实占 x88..99，x88 正好是洞口右缘），世界 rect `(2236, 251) 6x68`，对应门洞右缘 2236 本身，不是 +40。
- **纠正三（完成点）**：保持 `CITY_ENTER_X = 2360`；研究建议的 2420 未采用。
- 我此前在 `get_inner_pillar_world_rects()` 里写的“左 41..51、右 94..104”与图不符，本轮按像素实测改为
  **左 43..54、右 88..99**（各 12×64，y90..154）。该访问器只用于描述，不作为“像素对称”证据。

### 2. 柱源 A/B（同机位、同状态，只切该装饰节点）

- 做法：门恢复点（`debug_setup_gate_with_key`）、人物 x=2140、门关闭，先拍
  `r00_ab_column_shown.png`，再只把 `Decorations/ColumnArenaRight.visible = false` 拍
  `r00_ab_column_hidden.png`（不清状态、不挪机位）。
- 结果：显示的图里左夹缝有一根**约 8px 宽、76px 高**的浅色多立克柱（含柱头）；隐藏后该缝只剩和右缝一样的天空。
  两图逐像素差集中在屏幕 **x360..367、8 列 × 约 76 行**，就是这根装饰柱，其他差异仅为背景云/粒子的逐帧动画。
- 处理：**从 `scenes/level_03.tscn` 删除 `Decorations/ColumnArenaRight` 这个实例**（原素材
  `scenes/decorations/doric_column_broken.tscn` 未改、未删），右侧**没有**补任何镜像柱。
  门固有的双塔/双拱柱/左右夹缝保持原样。证据：`r00_ab_zoom_pair4x.png`、`r03_gate_structure_640.png`、
  `r04_gate_structure_zoom4x.png`（后两张人物在 2020，不在裁切范围内）。

### 3. 定稿层次（玩家 z = 5，`scenes/player.tscn`）

| 层 | 节点 | z | 世界范围 / 说明 |
| --- | --- | --- | --- |
| 暗通道（同时是门板的裁剪体） | `Passage` | −1 | 门板 bbox 内的深色渐变，**真实绘制**（`CLIP_CHILDREN_AND_DRAW`），alpha 即门洞形状 |
| 可动门板 | `Passage/DoorPlate` | −1（子节点） | 局部 (55,79) 34×73，只上移，顶端被门洞裁掉 |
| 固定门楼（双塔/拱/门楣/双拱柱） | `FixedFacade` | **4** | 世界 `(2148,163) 144×160`；**整张都在玩家后面** |
| 右拱柱内沿真实像素 | `RightPillarLip` | **6** | 世界 `(2236,251) 6×68`（图 x88..93, y88..155） |
| 建筑暗侧面 | `WallReturnSide` | **6** | 世界 `(2292,−80) 12×400`，右塔右缘起 |
| 转角柱 | `WallCornerColumn` | **6** | 世界 `(2304,−80) 16×400` |
| 建筑正面 | `WallFront` | **7** | 世界 `(2320,−80) 292×400`，高出视口(世界 y −80 > 相机上缘 0) |

- 左塔/左拱柱/左夹缝/门前区域**没有任何高于玩家的面**；没有按玩家 x 改 `visible`/alpha，没有瞬移。
- 通行区没有新增实墙碰撞：门障碍仍是 4×100 图层 1，通行高度（progress ≥ 0.62）后释放；`has_wall_collision()` 恒 false。
- 空气隙是**真实绘制**的暗通道，不是只留天空：修掉了此前的 `CLIP_CHILDREN_ONLY`（只当裁剪遮罩、自己没画），
  改成 `CLIP_CHILDREN_AND_DRAW`。

### 4. 右侧建筑（`scripts/level03/l3_gate_depth_wall.gd` 重写）

- 不再是地面 strip 整片平铺的墙纸。三块可见体：**12px 暗侧面 + 16px 转角柱 + 292px 正面**，三者**共用同一条
  世界高度线**，所以接缝处横带/基座是连续的。
- 檐带/腰线画在**世界 y 200**（门楼塔顶/齿带实际所在，图 y37 ⇒ 320−157+37），没有用 world 163。
- 基座亮线在**世界 y 314**：直接沿用门楼自己的基座高光（图 y151 的 `198,187,174`），所以建筑基座和门楼基座连成一条。
- 正面：16px 错缝砌块，石块色调全部取自门楼（94,84,88 / 88,80,88 / 120,104,104 / 80,72,78）；
  **3 根竖壁柱**（世界 x 2344 / 2440 / 2536，各 18px，左亮边右暗边）+ 壁柱间浅凹壁板。
- 无黄圈、无矮黑砖、无第二假拱门、无碰撞。
- 本轮修掉的实现缺陷（都会直接毁掉画面，记录在案）：
  1. 墙体高度算成 `WALL_TOP − GROUND = −720`（负高度 ⇒ `_draw` 直接 early return，右侧**整块没画**）；
  2. `RightPillarLip` 的 sprite 位置用了图内坐标 `(88,88)`，没加 `IMAGE_LEFT/TOP`，会被放到世界 `(2314,408)`
     （画面外右下）；已改为 `(IMAGE_LEFT+88, IMAGE_TOP+88)`；
  3. `get_wall_world_rect()` 之前返回**负高度**矩形，已改为正常 `(2292,−80) 320×400`；
  4. `has_wall_collision()` 重复定义（解析报错），已删旧定义。

### 5. 证据（`screenshots/level03_gate_depth_20261116/`，旧 g* 全部保留未删）

**setup 与真实输入的边界**：门用 `debug_setup_gate_with_key()` 恢复到“守卫已击败、持核”的恢复点；
之后 **E 嵌核、约 1s 上移、向右走入直到 2360 完成**全部是真实 `Input.action_press("interact"/"move_right")`。
每张图保存前都读过实时状态（`is_inserted()` / `is_open()` / `get_plate_progress()` / `global_position`），
探针会把门状态断言失败的分支直接 `quit(1)` 而不是照样存图。

| 图 | 状态 / 真实还是 setup |
| --- | --- |
| `r00_ab_column_shown/hidden.png`、`r00_ab_zoom_pair4x.png` | A/B，门关闭的 setup 恢复点，同机位只切装饰节点 |
| `r01_gate_left_tower_body.png` | setup，门关闭，人物 x2160 站在**左塔正面**上：完整可见（门楼 z4 在玩家后） |
| `r02_gate_full_640.png` | setup，正常 640 全景：门楼 + 右侧建筑（侧面/转角/正面）同框 |
| `r03_gate_structure_640.png` | setup，人物 x2020 在裁切范围外，只拍门楼结构 |
| `r04_gate_structure_zoom4x.png` | `r03` 的 4× 裁切（440,140)-(604,330）：双拱柱、左右夹缝 |
| `r09_gate_fixed_derived_zoom4x.png` | **派生素材** `gate_fixed.png` 的 4× 放大（不是引擎帧） |
| `r05/r06/r07_rise_25/50/75.png` | **真实升门**，progress 0.26 / 0.50 / 0.75 |
| `r08_gate_open_full.png` | **真实全开**，`barrier=0` |
| `r10_front_2130.png` | 真实行走 x=2130，门前，完整可见 |
| `r11_mouth_2190.png` | 真实行走 x=2190，门洞前，完整可见 |
| `r12_mid_2220.png` | 真实行走 x=2220，门洞中线内，完整可见 |
| `r13_right_lip_2245.png` | 真实行走 x=2245，右拱柱内沿 6px 从身体左侧切过（局部遮） |
| `r14_corner_2292.png` | 真实行走 x=2294，转角柱盖住身体右侧大部分（逐渐遮） |
| `r15_behind_wall_2330.png` | 真实行走 x=2330，已在正面之后（全遮） |
| `r16_city_completion.png` | 真实越过 2360 后的完成界面 |
| `r_walk_00..59.png` | 真实连续行走帧（每 4 个物理帧一张，x2120→2360）；49 帧起出现完成遮罩 |
| `r_gate_walk.gif` | **本轮用当前 r_walk_00..48 重建**（12:30，晚于 12:26–12:27 的帧），49 帧、66ms、不循环 |

`MANIFEST_R.txt` 由截图脚本在保存时写入（每张的 state/位置），并在末尾追加了派生图/A-B/GIF 的说明和
`r10..r15` 当时的**实时屏幕矩形**（`body` = 12×30 碰撞盒；角色美术约 30px 宽）。

同一次行走里打印的屏幕矩形（相机上限 cam.x = −1880 之后人物在画面里向右走）：
`r13 body 360.9..372.9 / lip 356..362 / corner 424..440 / front 440..`；
`r14 body 407.6..419.6`；`r15 body 445.9..457.9`（已进入 front）。

### 6. 本轮实际跑过的检查（当前最终代码，2026-11-16 12:3x）

| 检查 | 结果 |
| --- | --- |
| `tests/level03/test_l3_gate_depth.tscn` | **GATE_RESULT pass=52 fail=0，GATE_OK，退出码 0**（新增 1 条：暗通道是 `CLIP_CHILDREN_AND_DRAW` 真绘制；lip 断言按真实柱 x88..99 改） |
| `tests/level03/test_level03_load.tscn` | **LEVEL03_LOAD pass=34 fail=0，退出码 0**；完整打印 `PLAYER/GUARD/GATE (2220.0, 320.0) socket=(2218.5, 288.5) barrier=1/DEVICE/ROUTE/PLAYER textures`，**无 ScriptError**（`get_barrier_layer()` 兼容访问器已补回） |
| `tests/level03/test_level03_revision.tscn` | **REVISION RESULT pass=194 fail=0，REVISION OK，退出码 0** |
| 旧 1311 `l3_gate_depth_20261116.py` | **UNCHANGED 1309 / CHANGED 2 / ADDED 25 / MISSING 0，OVERALL OK，退出码 0**（CHANGED = `scenes/level_03.tscn`、`scripts/level03/l3_gate.gd`） |
| 新 1337 `l3_gate_classic_resume_20261116.py` | **FAIL，退出码 1**：`UNCHANGED 1325 / CHANGED 7 / ADDED 4 / ARCHIVED 4 / MISSING 1`，唯一一条是 **`MISSING UNAUTHORIZED tests/level03/probe_gate.gd.uid`**（见下） |
| 主场景 `res://scenes/level_03.tscn` headless 240 帧 | 退出码 0，日志只有引擎版本行，无报错 |

**1337 这一条不是文件丢失**：`gate_scratch_archive/probe_gate.gd.uid` 与移出前**字节相同**
（sha256 `adf08ed21de279eac738802a77084131a4c7eaec4302928d6169d546eca1a5dd`），另外 4 个探针也是
`byte_identical: true`（记录在 `gate_scratch_archive/manifest.json`）。原因是对应 checker 的
`PROBES` 集合只列了 `.gd`/`.tscn`、**没有 `.gd.uid`**，于是把已归档的 uid 记成 MISSING。
按要求我**没有改**该 checker、也没有改 `l3_gate_classic_resume_before_20261116.json`、更没有把 uid 放回去
（放回去会让旧 1311 变成 ADDED UNAUTHORIZED）。修法只能由 checker 作者把 `.gd.uid` 加进 `PROBES`
（或按归档 basename 通配），这不在我的授权范围。

### 7. 未验证 / 需你复核的点（不做“已完成”声明）

1. **画面验收本身由你独立看**。我实际看过 `r01/r02/r03/r04/r05/r08/r13/r14/r15`、`r00` A/B 与 4× 放大，
   以及 `r_walk` 抽样帧；`r06/r07` 只看了门洞 5× 裁切。
2. **2245..2290 之间人物仍压在右塔石面上**：这是“整张门楼 z4 在玩家后”的直接结果——6px 内沿只切一刀，
   其余身体画在右塔前面。按 brief 的层次这就是字面结果，但如果你要的是“整个人被柱挡住”，那需要把右拱柱
   （或整段右塔）也提到 z6，属于新的层次决定，我没有擅自改。
3. **右侧建筑仍是一大片高墙**：结构上已按 brief 做了侧面/转角/基座/腰线/壁柱，但 2320 起的正面高 400px、
   占画面右半，是否仍读作“大块”要看你实机。若要改体量/轮廓，是新的美术决定。
4. 门洞里是近黑（25,31,33 → 10,14,16）的暗通道；若你要能看见内部石阶，需要新的派生图。
5. `r_gate_walk.gif` 是**抽样帧**（每 4 物理帧一张、66ms/帧），不是逐帧录屏；`r_walk_49..59` 已是完成遮罩。
6. `r14` 的标题写的是 2292，实际在 x=2294 触发（阈值 `>= 2292`），画面与标题一致，特此注明。

### 8. 本轮文件变更

改：
- `scripts/level03/l3_gate.gd`（z4 固定门楼、z6 右内沿/转角、z7 正面、暗通道真绘制、访问器与兼容、rect 修正）
- `scripts/level03/l3_gate_depth_wall.gd`（重写为侧面/转角/正面三块）
- `scenes/level_03.tscn`（只删 `Decorations/ColumnArenaRight` 一个实例）
- `tests/level03/test_l3_gate_depth.gd`（层次/柱 rect/lip/暗通道断言）
- `assets/level03_gate_depth/manifest.json`（右内沿派生与层次说明）

新增：
- `assets/level03_gate_depth/gate_right_edge.png`（+ `.import`，从 `gate_fixed.png` x88..93, y88..155 直接裁出）
- `tests/level03/capture_l3_gate_depth_resume.gd/.tscn`（r* 截图脚本）
- `screenshots/level03_gate_depth_20261116/` 下 `r00/r00_ab_*/r01/r02/r03/r04/r05–r08/r09/r10–r16/r_walk_*` 与 `r_gate_walk.gif`、`MANIFEST_R.txt`
- `.openchamber/verification/gate_scratch_archive/`（5 个探针文件字节归档 + `manifest.json`）

未动：原 `assets/level03_prototype/gate_*.png`、前段/符石/130 平台/守卫/对白/音频/电影/HUD、旧 `g*` 截图、
`l3_gate_depth_before_20261116.json` / `.py`、`l3_gate_classic_resume_before_20261116.json` / `.py`。未提交推送。

## 独立复核后的两项返修（2026-11-16 12:55–13:10）

协调与只读复审（r11/12/13、r_walk30/32/34/36）指出的两项缺陷，按“最小修法、不扩内容”处理。
**本节更正上节第 3 节的层次**：那条 6px `RightPillarLip` 已删除，替换为右侧真实半片前景；其余
（真柱源 A/B、探针归档、固定门楼 z4、2360、E/孔核规则）全部保留未动。

### 1. 右侧遮挡连成连续前景（缺陷一）

问题（旧图 r13/r_walk30/32 实拍，加上按同一套 31px 身体矩形反算）：旧 6px 内沿只在 x2236..2242 挡一条，
x2245 覆盖只有约 0.19，x2257 就回到 0.00，人物在右塔前重新完整可见，到 2292 才被转角切掉——
正是复核说的“短夹一下→再露→墙前消失”。

修法：
- 新增派生素材 `assets/level03_gate_depth/gate_right_foreground.png`：`gate_fixed.png` **x88..143,
  y18..159 的逐像素副本**（右拱柱 + 缝 + 右塔，56×142），z6，位置与固定层同点，所以静止画面像素不变。
  它只覆盖**右半**；左塔/左拱柱/左夹缝仍在 z4（玩家后），没有整张 facade 前景化。
- 右拱柱与右塔之间那条 11px（图 x101..111）透明缝用**派生的侧厚面**填实：2px 阴影棱(60,52,57) +
  7px 暗侧面(78,70,78，每 16px 一条横缝) + 2px 过渡(89,74,81) + 1px 边(94,84,88)，上方加(44,38,43)
  门楣阴影，共 946 像素。目的只有一个：人物走到后面时不会有 11px 的“透视空窗”。
- 前景序列现在是连续的：`RightForeground 2236..2292 → WallReturnSide 2292..2304 → WallCornerColumn
  2304..2320 → WallFront 2320..2612`，中间无缝隙（门测试逐段断言）。

实测覆盖（`get_occlusion_coverage()` 对**真实身体美术矩形** 31×36 计算，不是只看 z）：

| x | 2220 | 2225 | 2230 | 2235 | 2240 | 2245 | 2252 | 2257 | 2294 | 2330 | 2357 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 覆盖 | 0.00 | 0.07 | 0.23 | 0.40 | 0.56 | 0.72 | 0.93 | 1.00 | 1.00 | 1.00 | 1.00 |

- 门测试断言：2220 完全可读（0.00）、2245 只被部分遮（0.35–0.95）、2260 起 ≥0.99、2220→2338 每 2px
  采样的覆盖**单调不减**（不会重新全露）、前景四块连续且没有一块伸到门楼左半。
- 没有用 `player.visible`/alpha、没有按玩家 x 强制隐身或改 z；处在前景后面就是因为层级。

**要请你看的一点（新出现的不对称）**：右缝现在是填实的侧厚面，左缝仍是原图的天空（人物不从那里走，
且你要求“不必封左右透明缝掩盖背景柱”）。r04 放大能同时看到：左边天空、右边凹陷石面。这是本轮
“连续右部实体”的直接结果，不是我又去补右柱；若你要求两侧视觉对称，那是新的美术决定。

### 2. 墙从“棋盘平板”改成有层高的建筑（缺陷二）

- **层高转折**：下部（世界 y200..320）是近平面：12px 暗侧面 + 16px 转角 + 正面；**檐口在世界
  y196..200**（4px，正好压在门楼真实塔顶横带上，测试用 `gate.global_position.y + IMAGE_TOP + 37`
  反算，不是 163），檐口下方 3px 阴影；**上部墙后退 16px**（从世界 x2320 起，下部从 2292 起），
  后退出来的 16px（2320..2336）画成**它自己的暗侧厚面**，所以轮廓在檐口处真的有台阶，不是只加缝。
- 上部墙顶仍出视口（世界 y −80），下部基座仍接地并与门楼基座同高：基座亮线仍是门楼图 y151 的
  `198,187,174`（世界 314）。
- **三个色调**（都在门楼底色附近，不再 124/76 棋盘）：凹壁 88,79,83 / 主面 94,84,88 / 壁柱 108,96,99；
  另加 1px 高光棱 143,128,126 与 1px 暗缝 60,52,57 做结构边。砌块改为**统一的 16px 皮 + 24px 错缝**，
  不再按块随机换色。
- **分仓**：3 根竖壁柱（世界 2364 / 2460 / 2556，各 18px，2px 亮棱 + 1px 暗边 + 2px 侧影）从墙顶一直
  通到基座，只被檐口打断；柱间是浅凹壁板（内左 2px 阴影、内右 1px 亮棱）。下皮同样延续这套竖线。
- 仍是纯绘制、无碰撞、无黄圈/黑砖/第二假拱门。证据：`r02_gate_full_640.png`（640 全景）、
  `r02_wall_storey_zoom3x.png`（3× 檐口/后退/壁柱）。

### 3. 当前最终代码的实际检查（2026-11-16 13:0x）

| 检查 | 结果 |
| --- | --- |
| `test_l3_gate_depth.tscn` | **pass=64 fail=0，GATE_OK，退出码 0**（新增：前景四块连续、无左半覆盖、2220/2245/2260/2294/2330 覆盖阈值、2220→2338 单调、檐口对齐门楼真实横带、16px 后退） |
| `test_level03_load.tscn` | **pass=34 fail=0，退出码 0**，完整摘要 `GATE (2220.0, 320.0) socket=(2218.5, 288.5) barrier=1`，无 ScriptError |
| `test_level03_revision.tscn` | **pass=194 fail=0，REVISION OK，退出码 0** |
| 旧 1311 checker | **UNCHANGED 1309 / CHANGED 2 / ADDED 28 / MISSING 0，OVERALL OK，退出码 0** |
| 新 1337 checker | **FAIL**，仍只有 `MISSING UNAUTHORIZED tests/level03/probe_gate.gd.uid`（其 `PROBES` 不含 `.uid`，归档字节相同；未改 checker/before） |
| 主场景 headless 240 帧 | 退出码 0，无报错 |

### 4. 本轮新增 / 改动

新增：`assets/level03_gate_depth/gate_right_foreground.png`（+`.import`）；截图
`r02_wall_storey_zoom3x.png`、`r13_cover_ramp_3x.png`（`r04/r09/r00_ab_zoom_pair4x/r_gate_walk.gif`
已用当前帧重建）。
改：`scripts/level03/l3_gate.gd`（右侧前景 + `get_foreground_world_rects()` / `get_occlusion_coverage()` /
`get_body_art_rect_at()`；删除 `RightPillarLip`）、`scripts/level03/l3_gate_depth_wall.gd`（层高/檐口/后退/
三色调/壁柱分仓重写）、`tests/level03/test_l3_gate_depth.gd`（覆盖与连续性断言）、
`tests/level03/capture_l3_gate_depth_resume.gd`（每帧/每张打印覆盖）、
`assets/level03_gate_depth/manifest.json`、`MANIFEST_R.txt`。
未动：`gate_right_edge.png`（旧 6px 切片保留但不再运行使用，避免动到 1337 基线）、原 `assets/level03_prototype/`、
前段/符石/130 台/守卫/对白/音频/电影/HUD、2360、1311/1337 的 before 与 checker。未提交推送。

### 5. 仍待你复核

1. 2245 时身体只剩最左约 9px 露在暗门洞里（画面上是一小条披风），覆盖 0.72；若你要“一半身体明显可见”，
   起点必须右移到 2248 之后，那就不再是真实右拱柱内沿。
2. 墙的体量仍是 400px 高、占画面右半；本轮只做了层高/檐口/后退/分仓，没有改体量与镜头。
3. 左缝天空 / 右缝实心的不对称（见上）。
4. `r_gate_walk.gif` 仍是每 4 物理帧抽样、66ms/帧；`r_walk_50` 起是完成遮罩。

## 收尾小修：左夹缝后衬配对（2026-11-16 13:00–13:05）

协调定稿的一项：r04 里左夹缝是天空、右夹缝是实侧面，不配对；用户本来就要求左右门体对称，
不能当新需求回退给用户。本轮只做这一项，不重做前面的遮挡与墙。

### 1. 做法（后景，不是前景）

- 把右缝的衬面配方**镜像**烘进**派生固定层** `assets/level03_gate_depth/gate_fixed.png`（原
  `assets/level03_prototype/` 的 PNG 仍只读未改）：左缝 x32..45（真实开口 11–12px）、行 y82..156，
  逐行填该行真正的透明像素，不覆盖原有石像素。配方与右缝镜像一致：靠塔侧 1px 边(94,84,88) +
  1px 过渡(89,74,81) + 暗侧面(78,70,78，每 16px 一条横缝) + 靠拱柱侧 2px 阴影棱(60,52,57)。
- 这条衬面属于**固定门楼（z4）**，在玩家（z5）之后；它不是前景片，也没进
  `get_foreground_world_rects()`，所以左塔/左缝的遮挡覆盖恒为 0。
- 只填真正的缝：门楣以上（y<18）与基座以下（y>156）一个像素都没画（脚本断言 y0..17 无新增不透明像素），
  不会出现悬空石块；右缝同样从门楣底 y82 起填，修掉了此前右缝顶部露天空的细缝。
- 不是恢复 `ColumnArenaRight`、不是补第三根柱、不是把左半前景化；A/B 真源证据与删除保持原样
  （`r00_*` 仍标注为“衬面前”的历史证据）。

### 2. 本轮实测

| 检查 | 结果 |
| --- | --- |
| `test_l3_gate_depth.tscn` | **pass=65 fail=0，GATE_OK，退出码 0**（新增一条：左塔 2160 与左缝 2186 的遮挡覆盖都为 0） |
| `test_level03_load.tscn` | **pass=34 fail=0**，完整摘要 `GATE (2220.0, 320.0) socket=(2218.5, 288.5) barrier=1`，无 ScriptError |
| 旧 1311 checker | **UNCHANGED 1309 / CHANGED 2 / ADDED 28 / MISSING 0，OVERALL OK** |
| 新 1337 checker（协调已把 `.gd.uid` 精确加入 PROBES） | **ARCHIVED 5（含 `probe_gate.gd.uid`）/ MISSING 0 / OVERALL OK**，归档文件 SHA256 与 before 一致（checker 用 `digest == before[rel]` 判 ARCHIVED OK，未放宽通配） |
| 两侧空隙残留透明 | 派生资源脚本自检：左缝 x32..45 / 右缝 x101..112，y82..156 合成后 **0 个透明像素** |
| 主场景 240 帧 | 退出码 0（本轮未再跑 revision，按协调要求由其独立运行） |

证据：`r01`（人物站左塔前仍完整可见）、`r03/r04`（无人物，两缝都读作凹陷侧厚）、`r11`（左柱/门前完整）、
`r12/r13/r14/r15` 与覆盖序列表、`r_gate_walk.gif`（本轮已用当前帧重建，49 帧，切在完成遮罩前）。
`MANIFEST_R.txt` 已更新覆盖表与层序，并注明 A/B 图是衬面前的历史证据。

### 3. 状态

- 左后衬配对：**完成**（固定层 z4，非前景；左右两侧空隙现在都读作建筑侧厚，只有右侧真实前景遮人）。
- 不再把“左右对称”列为当前未解阻塞；若你要调左衬的具体色调，那是新的一轮微调，不是未完成项。
- 未动：24 孔/16 核/E 规则、升门节奏与碰撞释放、`CITY_ENTER_X=2360`、右墙（本轮未改色/未扩内容）、
  原资产、前段/符石/130 台/守卫/对白/音频/电影/HUD、1311/1337 的 before 与 checker。未提交推送。

## 协调最终独立复核与试玩交付

- **实跑结果**：当前门定向`65 PASS / 0 FAIL`、载入`34 PASS / 0 FAIL`、第三关回归`194 PASS / 0 FAIL`，均退出码0，输出有各自完整成功摘要，无ScriptError或资源退出错误。主场景另跑60帧退出码0。第一次把所有命令串在一起达到120秒工具限时后中断，未把未执行的后续检查算过；主场景和双保护随后分别补跑成功。
- **旧1311独立保护**：1309未变、2授权旧文件改动、28授权新增、0缺失、OVERALL OK。**重启1337独立保护**：1324未变、8授权改动、7新增、5逐字节归档、0缺失、OVERALL OK。`.gd.uid`仅加入精确探针后缀集合，仍要求归档文件SHA256等于原快照；没有重写before或用宽泛通配洗白。
- **参考门槛**：协调实际打开PoP DOS升门/穿门连续取帧和SotN建筑图，并联网核对两个archive视频条目。只借固定门框/移动门板、入口窄框与建筑分仓；不拷贝第三方像素、台词或切场方式。SotN静图不能当连续遮挡实证。
- **额外柱真源**：已看同机位r00显示/隐藏对照，左多柱来自独立装饰`ColumnArenaRight`透门图透明区，不是门图缺右柱。实例已从场景移除，原素材保留；研究此前“补右4px柱”的诊断已纠正。最终左右侧厚配对在门衍生资源完成，左侧为后景，不恢复那根装饰柱。
- **实际画面核查**：已看最终r01左塔前、r11左门口、r12门中人物可读；r13及连续爬升条带、r14/r15人物逐步进入右半门楼/右墙后，没有再全露。已看25/50/75%门板上移帧，拱框与柱固定，核心随门板上升。r04左右夹缝均为相应凹面，不再一边天空、一边墙。
- **指标边界**：代码覆盖率为人物美术包围矩形与遮挡几何的估算，不是逐像素分割的人物可见面积；它只作辅助，不能代替上述连续实机画面核查。新gif由最终当前行走帧重建，是每4物理帧抽样的连续记录，不冒充真人逐帧录屏。
- **建筑观察**：最终全景可见上部退台、檐线/阴影、转角与连续基座；砖色较早期棋盘降低反差，未再用地面带整片铺墙。主体仍是高出画面的建筑墙，是否符合创作者整体美术观感仍待其试玩评价，不宣称主观审美已获通过。
- **交付范围**：F6打开`scenes/level_03.tscn`。保持24孔/16核、E与升门/碰撞、2360实际入城阈值；前段/标准符石/130高台/浮地/守卫/对白/音频/HUD与前两关未在本轮改变。F5旧入口/L2串关未改，不自动提交推送。
- **未验与下一步**：尚未真人连续整关或全显示缩放人工核看；建议创作者重点看门前无遮挡、右侧连续遮挡、门楼墙体构图与升门节奏。项目`AGENTS.md`参考先行硬规则持续生效。

## 用户改布局：城门挪进右侧高墙（2026-11-16 13:5x）

用户标图授权把红框旧门楼挪到蓝框高墙位置。按 `docs/L3_GATE_DEPTH_REPOSITION_20261116.md` 的单套规格执行，
不动玩法规则、不新做美术。

### 1. 实际坐标（真实值，不是估算）

| 项 | 值 |
| --- | --- |
| 城门中心 | **(2380, 320)**（原 2220，向右 160） |
| 门楼尺寸/门洞 | 144×160；门洞世界 2363..2396，右拱柱内沿 2396 |
| 建筑世界轮廓 | **2292..2612 不动**（左端 12px 侧面 + 16px 转角，正面 2320 起，上部退台/檐线 196..200/基座 314） |
| 完成线 `CITY_ENTER_X` | **2460**（门右 72+约 8，在右前景后，距地面末端 2520 还有 60） |
| `GATE_TARGET` / `CITY_TARGET` | 2380 / 2460 |
| 电影触发 `CINE_TRIGGER_X` | **2310**（新门左 70），首次击碎才演出/已看不重播等规则未改 |
| 地面 CityGround / 相机右界 | 2220..2520 / 2520（未延长，无新增空走） |
| 守卫/竞技场/前段 | 未动（GUARD 2050、竞技场、浮地、符石、130 台、三格两击均原值） |

### 2. 层次（门嵌进墙，不是门带墙一起平移）

墙锚点已从门的相对位置解耦（`L3Gate.BUILDING_WORLD_LEFT = 2292`，与 `Gate.position` 无关）：

| 层 | 世界 x | z | 作用 |
| --- | --- | --- | --- |
| 建筑背面（left end 12px + 转角 16px + 正面） | 2292..2612 | **3** | 玩家在它前面走：旧 2292 位置与门前都不会被墙提前藏住 |
| 暗通道 + 门板 | 门洞内 | **4** | 必须高于背面，否则门洞露出墙石；仍 < 玩家 5，人物在门前/门内可读 |
| 固定门楼（双塔/拱/双拱柱/左右衬面） | 2308..2452 | 4 | 玩家之后 |
| 门右侧真实前景（右拱柱+填缝侧厚+右塔） | 2396..2452 | 6 | 过中线后逐步遮 |
| 右侧墙段 | 2452..2612 | **7** | 与建筑背面**同一份正面绘制**，只是按世界 x 裁剪（`clip_world_x`），所以檐线/壁柱/砌块相位在门缝处不跳变，只有右侧这段在玩家前 |

- 旧门位（2148..2292）：**没有**第二门楼、没有碰撞、没有假影；门测试直接断言旧中心 x 处
  `get_occlusion_coverage == 0` 且 `get_fixed_world_rect()` 不含该点；i01 同框可见。
- 门板/孔核在墙里可见：doorway 的暗通道层在背面之前绘制（测试断言 `Passage.z > WallFront.z` 且 `< player.z`），
  i03..i06 的升门阶段孔核/门板/门洞都可见，没有被背墙盖住。
- 没有改 `player.visible/alpha`，没有按 x 改 z 或瞬移；遮挡全部来自真实层级。

### 3. 实测遮挡（真实引擎，人物 31×36 美术矩形，相机钉在 1880）

| x | 2292 | 2341 | 2381 | 2391 | 2406 | 2412 | 2446 | 2459 | 2461 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 覆盖 | 0.00 | 0.00 | 0.00 | 0.24 | 0.73 | 0.94 | 1.00 | 1.00 | 1.00 |

老墙位/门前/门中全可读，过右柱内沿（2396）单调上升，2419 之后到完成线一直 1.00，不重新全露。
i_walk_00..28 每帧打印了覆盖率，全程无回退；`i_gate_walk.gif`（29 帧、66ms、切在完成遮罩前）用当前帧重建。

### 4. 本轮实际检查（当前最终代码）

| 检查 | 结果 |
| --- | --- |
| `test_l3_gate_depth.tscn` | **pass=72 fail=0，GATE_OK**（旧 2220 硬断言已改为从 `_gate` 接口取值；新增旧位空、背面 z3、右侧墙段 z7、门洞层高于背面等断言） |
| `test_level03_load.tscn` | **pass=34 fail=0**，摘要 `GATE (2380.0, 320.0) socket=(2378.5, 288.5) barrier=1`，无 ScriptError |
| `test_level03_revision.tscn` | **pass=194 fail=0，REVISION OK**（2170/2180 的 setup 改为 `gate.x-50` / `gate.x-20`，规则断言未删） |
| 新 1339 `l3_gate_inset_20261116.py` | **UNCHANGED 1331 / CHANGED 8 / ADDED 3 / MISSING 0，OVERALL OK**（`tests/level03/load_probe.log` 是载入测试每次写出的产物；把该检查的**文案**恢复成改布局前原文、断言仍为 `world_right >= CITY_ENTER_X`，重新跑后该日志与 1339 before **逐字节一致**，不是放宽容差） |
| 旧 1311 / 1337 | 仍 **OVERALL OK**（1337 归档 5 项含 `.uid`） |
| 主场景 `res://scenes/level_03.tscn` | headless 120 帧，退出 0，无报错 |

### 5. 证据与边界

- `screenshots/level03_gate_inset_20261116/`：`i01`（同框：旧位空 + 新门嵌墙）、`i02`（3× 放大）、
  `i03..i06`（真实 E + 升门 25/50/75/全开）、`i10..i15`（老墙位→门前→门中→右沿→右塔→墙后）、`i16`（完成）、
  `i13_cover_ramp_3x`、`i_walk_00..59`、`i_gate_walk.gif`、`MANIFEST_I.txt`。旧 `r*`/`g*` 全部保留未删。
- setup/真实输入边界：门用 `debug_setup_gate_with_key`（守卫已击败、持核）到恢复点；E 嵌核、1 s 升门、
  向右走 2292→2460 全是真实按键；每张存图前读实时状态，失败分支直接 `quit(1)`。
- **未验/需你复核**：挪门后的构图观感（门楼在蓝框建筑左三分之一处，右侧为前景墙段，门楼塔顶略高于檐线）、
  旧位空地在正常镜头下的观感、以及 `i02` 是派生素材放大不是引擎帧。另 `test_level03_revision` 已跑过，
  按你的要求最终由协调再独立跑一次。
- 未动：前段/符石/130 台/浮地/守卫/对白/音频/玩家/旧资产/HUD；未提交推送。
