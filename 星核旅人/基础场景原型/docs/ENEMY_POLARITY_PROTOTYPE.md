# 独立极性石怪原型（实验）

> 状态：**独立实验原型，已完成最小可玩闭环。** 未接入 F5 主场景、正式第一/第二关或主菜单；
> 没有修改 `project.godot`、`player.gd`、`player.tscn`、正式两关、共享移动/力场/运输/菜单参数，
> 也不处理本轮无关的第二关右端通行缺陷。
>
> **2026-11-12 可读性修订**：移除自绘碎石，等待期直接保留源 die 纹理最后一帧；
> 实验文字统一为 Fusion Pixel 原生 12 逻辑 px；相性统一为“辉相/澜相”。
>
> **2026-11-12 敌人干扰行为**：石怪不再静止。新增有界巡逻、120 px 警戒接近、
> 0.28 s 举臂预警、0.12 s 真实落拳窗口、0.30 s 收招、0.15 s 间隔；
> 命中只短退玩家（无 HP 伤害），每砸击最多一次、0.6 s 保护。
> 仍只改独立实验关；正式两关、共享 `player.gd`、`project.godot`、源图/字体未动。

## 0. 最新接入：正式第二关主桥守卫（2026-11-12）

> 本节只追加最新接入与参数变化；下文 1~8 节保留为独立实验原型的历史证据。

- 正式第二关新增 `scenes/enemies/polarity_golem_guard.tscn`，复用本实验的敌人脚本与 12 张源图副本；没有复制第二套千行敌人脚本，也没有改共享 `player.gd`/`player.tscn`。
- 守卫实值：出生脚点 `(344,264)`，主桥顶 y=264；巡逻 `260..376`；追击/推拉安全范围 `244..388`；碰撞 `20×30`；初始辉相（橙金）；固定相性，正式关没有 Tab 切敌相。
- 敌人脚本新增少量导出：`patrol_left/right`、`pursuit_left/right`、`alert_vertical_tolerance`、`attack_vertical_tolerance`、`show_polarity_label`。实验场景不覆盖时仍为原 `240..520 / 200..536 / y=288`，独立实验关原功能保留。
- 正式关 `alert_vertical_tolerance=40`：地面玩家在桥下 56 px，不会被桥面守卫当作近战目标；拳落框和射线仍是真实身体/遮挡判定，不能隔 56 px 砸中地面玩家。
- 头顶读数改为**默认不显示极性字/符号/菱形/正负号**（`show_polarity_label=false`），只保留 3 格血条；击散等待/重组仍显示中性的 `8.0秒后重组`/`重组中`。独立实验关头顶也随之更新，实验 HUD 仍保留敌方相性文字作为调试诊断。
- 第二关 Player 实例覆盖 `scripts/experiments/polarity_golem_player.gd`，接入真实 J raw-key latch（echo 不重复）、同相 1 伤害+击退打断、异相牵引无伤不取消砸击、0.15 s 反应/0.6 s 保护；暂停菜单右栏新增 J。
- 完成页调用 `freeze_for_completion()`/`lock_completion_input()`：停守卫 AI/砸击、取消玩家挥击、受击反应结束也不能解除完成态输入锁。R/暂停重开/坠落/核越界恢复守卫出生/相性/HP 与玩家攻击/保护。
- 本轮只验证相关节点：`tests/test_level02_guard.tscn` 实际 `TEST_SUMMARY pass=119 fail=0`；GUI 仅两张 `screenshots/level02_guard_01_bridge.png`、`level02_guard_02_stele_rules.png`。没有重跑旧 104/84/31 大套或第三关，也没有做人工连续试玩。
- 旧 `test_polarity_golem_readability` 中“头顶显示辉相 +”的断言已与最新要求相反；若重跑旧套需更新该断言，本轮没有把旧套当成本轮证据。

## 1. 已批准内容（按用户确认实现）

- 场地：640×360 单屏遗迹训练场；地面 + 一处可选小矮墙（右端 x=544..576），石怪初始不被墙挡。
- 敌人：一个 Golem2/Golem_1 实例，固定两种相性显示：
  - **澜相 -**（蓝澜）；
  - **辉相 +**（橙辉）。
  头顶有 3 格血条 + 相性/状态文字；另提供实验本地 `Tab` 切换敌人相性。
  - 本轮新增：在场地内**有界巡逻 → 警戒接近 → 停步举臂 → 向前下方砸击 → 收招**；
    不再使用上一轮提议的冲撞，也不做全屏震地/身体接触常驻伤害。
- 主角：保留 A/D、方向键、左 Shift、空格、Q 的现有行为；新增 `J` 单次近战挥击。
  - 按住 J 不连发，OS key-repeat echo 不触发第二击；
  - 每次挥击对同一敌人最多结算一次；
  - 攻击方向和玩家相性在挥击开始的瞬间快照，Q 变化只影响下一击。
- 相性规则：
  - 同相命中：扣 1 HP + 可读击退；
  - 异相命中：仅短促牵引到角色面前的安全距离，不扣血；
  - 反面、越距、实体墙阻断 → 不命中/不牵引；
  - 牵引与击退均不穿过地形，敌人不被推出世界边界。
  - 同相命中会立即取消石怪当前举臂/未命中的砸击；被取消的攻势不会延迟命中。
  - 异相牵引不扣血，也不取消既有举臂/砸击，只改变石怪位置；结束后回到正常 AI。
- 状态闭环：
  `活动 → 受击 → HP 0 击散 → 重组等待（默认 8 s，源 die 末帧可见）→ 倒放重组 → 满血活动`。
  - 击散位置 = 等待/重组位置，不回初始出生点；
  - 等待和重组期间不受攻击、不产生旧身体阻挡；
  - **击散/等待/重组期间一律不巡逻、不追击、不攻击**；复活后先 0.4 s 间隔，
    再走完整 0.28 s 举臂预警，不会零预警瞬间命中；
  - **不再自绘碎石**：等待期直接显示 `golem_1_die.png` 的索引 11（13 格中索引 12 为空白）；
  - 重组倒放 die 11..0，重组前有闪烁与“即将重组”/倒计时提示；
  - 敌人与玩家**没有实体互碰**（敌人 `collision_layer = 0`），玩家站在等待点不会被卡住；
  - 重组保持相性；只有 R 才回初始位置/极性/满血。
- 操作：`R` 整个实验重开；`Esc` 简单暂停/继续；窗口失焦自动暂停并清输入。
- 隔离：实验入口是独立的 F6 场景，不修改正式关和主菜单；`J`/`Tab` 由实验场景监听原始按键，
  没有写入正式项目 InputMap。

## 2. 操作与入口

### F6 入口

在 Godot 4.7.2 中打开：

```text
res://scenes/experiments/polarity_golem_experiment.tscn
```

按 **F6** 运行当前场景。也可以用命令行：

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path "D:\godot game\星核旅人\基础场景原型" res://scenes/experiments/polarity_golem_experiment.tscn
```

### 键位

| 键 | 行为 |
| --- | --- |
| A/D、左右方向 | 移动（现有行为） |
| 左 Shift / 双击方向 | 跑（现有行为） |
| 空格 | 跳跃（现有行为） |
| Q | 切换玩家辉相/澜相（现有行为；影响下一击） |
| **J** | 单次挥击；按住不连发 |
| **Tab** | 切换敌人辉相/澜相（实验本地；重组等待期间锁定） |
| **R** | 整个实验重开（含暂停中） |
| **Esc** | 暂停/继续（简单覆盖层，不是正式菜单） |
| 失焦 | 自动暂停并清输入 |

初始对局：玩家**辉相 +**，敌人**辉相 +** → 第一刀就是同相命中，便于立即试手感。
按 Q 变澜相后可测试异相牵引；按 Tab 可改变敌人相性。

## 3. 临时原型参数（集中可调，非正式平衡）

### 3.1 玩家挥击（`scripts/experiments/polarity_golem_player.gd`）

| 参数 | 值 |
| --- | --- |
| 素材 | `male_hero-combo_1.png` 3 帧 + `male_hero-combo_1_end.png` 4 帧 |
| 前摇/命中开始 | 0.06 s |
| 命中窗口结束 | 0.20 s |
| 挥击帧率 | 14 FPS |
| 收招帧率 | 14 FPS |
| 挥击总长 | 0.50 s |
| 收招后冷却 | 0.12 s |
| 攻击前方距离 | 52 px（中心到中心） |
| 垂直容差 | 30 px |

实现方式：`polarity_golem_player.gd` **继承** `PrototypePlayer`，通过新场景里的脚本覆盖接入；
没有复制玩家场景/大框架，也没有改动 `player.gd`。挥击期间只接管 `CharacterSprite` 的
texture/hframes/frame，结束后恢复基础状态动画。

### 3.2 敌人与相性（`scripts/experiments/polarity_golem_enemy.gd`）

| 参数 | 值 |
| --- | --- |
| HP | 3（同相每击 1） |
| 同相击退 | 初速 260 px/s，摩擦 900 px/s² |
| 异相牵引范围 | 130 px |
| 牵引安全距离 | 46 px（中心到中心，不重叠） |
| 牵引时长 | 0.10–0.24 s |
| 重组等待 | **默认 8.0 s**（可调 `scatter_wait_time`） |
| 等待期视觉 | **源 die 纹理索引 11，Sprite 保持 visible；不自绘碎石** |
| 重组预警 | 等待最后 1.0 s 闪烁 + 头顶/HUD 倒计时提示 |
| 击散动画 | die 0..11 帧 @16 FPS（约 0.75 s；跳过空帧 12） |
| 重组动画 | **倒放 die 11..0** @20 FPS + 闪烁（无独立重组素材） |
| 敌人活动边界 | x = 28..612 |
| 敌人身体 | `collision_layer=0`，不与玩家实体互碰 |

### 3.3 敌人 AI 与砸击（本轮新增，全部集中在脚本顶部常量）

| 参数 | 实值 |
| --- | --- |
| 巡逻区 | x=240..520，脚点 y=288 |
| 追近守区 | x=200..536（不越过矮墙 544..576） |
| 巡逻速度 | 60 px/s，使用源 walk 10 帧 |
| 接近速度 | 100 px/s；玩家约 120 px 内且胸线无遮挡才触发 |
| 丢失警戒 | 玩家超出约 148 px、离开守区或墙体遮挡 → 返巡逻 |
| 停步/攻击触发 | 目标约 42 px 内（停步距离 34，会停在约 34~42 px） |
| 举臂预警 | 0.28 s（attack 帧 0..5，双臂举起） |
| 有效砸击 | 0.12 s（attack 帧 6..7，拳真正落地后才检测） |
| 收招 | 0.30 s（attack 帧 7..10） |
| 收招后短间隔 | 0.15 s |
| 攻击锁定朝向 | 进入 ATTACK 时快照，整个砸击不转身；只镜像 Sprite，不镜像头顶读数 |
| 实际拳落判定区 | 朝向前方 26 px、离脚点 -8 px 的 26×20 px 小矩形 |
| 命中条件 | 拳落矩形与玩家 12×30 碰撞体重叠 + 垂直/墙体检查 |
| 玩家击退 | 160 px/s，持续 0.15 s，之后由共享地面摩擦自然减速；实测约 30 px |
| 玩家受击反应 | 0.15 s，仅短暂抑制方向/跳跃/Q 输入；无 HP、无长硬直 |
| 玩家保护 | 0.6 s；期间新砸击不能重复推走 |
| 复活后间隔 | 0.4 s，再加完整 0.28 s 预警 |

砸击帧重映射（不是简单按 11 帧等速播放）：

```text
帧 0..5   举臂预警   0.28 s   ← 玩家看到双臂抬起
帧 6..7   有效砸击   0.12 s   ← 只有这一段检测，拳落在地面
帧 7..10  收招       0.30 s
随后      短间隔     0.15 s
```

### 3.4 房间

| 参数 | 值 |
| --- | --- |
| 逻辑分辨率 | 640×360 |
| 地面顶 | y=288（y=288..360） |
| 小矮墙 | x=544..576，y=240..288（可跳过，也可阻断胸腔射线） |
| 玩家出生 | (80, 288) |
| 石怪出生 | (420, 288) |
| 初始敌人相性 | 辉相 + |

### 3.5 测试专用缩短（必须与生产 8 s 区分）

- 可读性 smoke 在测试 setup 中调用 `set_scatter_wait_time(0.6)`，并打印明确日志；
- 本轮 AI smoke 在击散/重组段调用 `set_scatter_wait_time(0.5)`，日志同样明示；
- 用 `debug_set_hp(1)` 让最后一击进入击散流程；
- 生产默认 8 s 没有被测试缩短值覆盖，加载检查验证 `scatter_wait_setting == 8.0`；
  AI smoke 也检查默认值未被改；
- GUI 等待图使用**真实默认 8.0 s**，在刚进入等待时截图，标签为 `8.0秒后重组`。

## 4. 可读性与排布（沿用上一轮）

### 4.1 头顶读数

- 字体：复用已有 `assets/fonts/tutorial_zh.ttf`（Fusion Pixel），以**原生 12 逻辑 px**绘制；
  不引入系统字体、不修改共享字体设置。
- 文本：`辉相 +` / `澜相 -`，去掉菱形；等待期 `8.0秒后重组`，重组期 `重组中`。
- 血条：始终在头顶，3 格填充数量；与文本共用一块深色底板 + 1 px 边框。
- 遮挡：头顶读数放在敌人的高 z 子节点 `HeadReadout`（相对 z=10）上绘制，
  玩家与敌人身体重叠时不会遮住血条/文字。
- 屏幕夹边：文字和血条计算时按屏幕 4 px 边距夹取中心，敌人靠左右边缘时不会出屏。
- 浮动的 `-1 / 击退` 小字已移除，避免在头顶堆文字；命中反馈改由受击染色、击退、
  灰尘和 HUD toast 承担。

### 4.2 HUD

- 所有 HUD 中文使用原生 12 px；仅“已暂停”标题使用 24 px。没有 7–10 px 的缩小文字。
- 顶栏高度 62 px，三行 12 px：标题 / 按键 / 相性规则。
- 底部左右面板从 y=300 开始、高 46 px，位于脚底 288 以下；只保留两行：
  - 敌方：`敌方 辉相 + HP ●●●` / `状态：活动 / 巡逻|接近|举臂预警|砸击|收招|间隔`，
    击散后仍显示 `8.0秒后重组` / `重组中`；
  - 我方：`我方 辉相 +` / `J 挥击：就绪/命中段/...`。
- 石怪砸击命中时，顶栏下方 toast 显示“石怪砸击：向左/右短退（无伤害，0.6s保护）”，
  同时玩家 Sprite 短暂染红；没有新增主角受击素材。
- 旧的“上次结算”和“碎石重组时不受攻击”等冗余行已删除；瞬时攻击结果放在顶栏下方
  toast（深底 + 12 px），不遮角色。
- 地面碰撞/出生点未改；底部信息使用 288 以下的 72 px 区域，不遮挡两个身体。

## 5. 素材核实与许可

### 5.1 实际尺寸/帧（Pillow 逐帧核实）

| 素材 | 实际尺寸 | 帧网格 | 帧数 | 可见 bbox |
| --- | --- | --- | --- | --- |
| `Golem_1_idle.png` | 720×64 | 90×64 | **8** | 38×38（首帧 x26..64, y26..64） |
| `Golem_1_walk.png` | 900×64 | 90×64 | **10** | 约 31–42×37–40 |
| `Golem_1_attack.png` | 990×64 | 90×64 | **11** | 约 36–62×33–45 |
| `Golem_1_hurt.png` | 360×64 | 90×64 | **4** | 约 37–38×38 |
| `Golem_1_die.png` | 1170×64 | 90×64 | **13**（索引 12 为空帧） | 38×38 → 4 px 碎石条 |
| `male_hero-combo_1.png` | 384×128 | 128×128 | **3** | 挥击弧约 58–61×29–38 |
| `male_hero-combo_1_end.png` | 512×128 | 128×128 | **4** | 约 35–45×31–37 |

敌人默认 `scale=1`、Nearest；Sprite 偏移 `(-45, -64)`，使 90×64 帧的脚底对齐节点原点。
主角可见身体约 32×37（挥击弧除外）；玩家基础 Sprite 偏移保持原来的 `(-59, -79)` 不变。

等待期明确使用 die 的索引 11（最后一帧非空内容）；索引 12 完全空白，代码从不显示它。
重组从 11 倒放到 0，因此不会刚击散就瞬现完整身体，也不会闪回空白帧。

attack 素材逐帧核实（Pillow）：11 帧，每帧 90×64。帧 0..5 为双臂逐步抬起，
**帧 6 双拳实际落到地面**（可见范围向右前方扩至 x≈83），帧 7..10 为收招。
因此有效判定从帧 6 开始，只覆盖帧 6..7；抬手帧 0..5 不产生命中。

### 5.2 素材来源与复制

12 张运行图已**逐字节复制**到实验目录，源图未移动、未修改：

```text
assets/experiments/polarity_golem/hero/
  male_hero-combo_1.png
  male_hero-combo_1_end.png
assets/experiments/polarity_golem/enemy/orange/
  golem_1_{idle,walk,attack,hurt,die}.png
assets/experiments/polarity_golem/enemy/blue/
  golem_1_{idle,walk,attack,hurt,die}.png
```

副本与源文件 SHA256 逐一比较：**12/12 完全一致**。
Hash 记录：`tests/logs/polarity_golem_readability_protection.json`。

### 5.3 许可状态（不要误读为已授权）

- **Golem2 / Golems_Free_Version 源包：未找到 LICENSE、README、作者或发布条款。许可未核实。**
- **`individual_sheets` 角色 combo 源图：现有 `ASSET_CREDITS.md` 已标注未提供许可/作者。许可未核实。**
- 字体复用项目已有的 `assets/fonts/tutorial_zh.ttf`（Fusion Pixel 12px Prop zh-Hans / TakWolf /
  SIL OFL-1.1；许可文本在 `assets/fonts/tutorial_font_LICENSE.txt`）。
- 地形和背景复用项目已有的 Szadi art. 资源；没有新下载素材。
- 因此：本实验仅作为课程/内部原型使用；**不要对外宣称作者、许可见证或可发布**。
  对外分发前必须由项目负责人补齐并确认石怪和 combo 图授权。

## 6. 变更清单

**本轮敌人干扰行为（2026-11-12）改动/新增：**

```text
scripts/experiments/polarity_golem_enemy.gd       (巡逻/警戒/砸击 AI、帧重映射、拳落判定)
scripts/experiments/polarity_golem_player.gd      (实验子类：短击退、0.15 s 反应、0.6 s 保护)
scripts/experiments/polarity_golem_experiment.gd  (注入玩家目标、受击 toast、AI 状态文案)
tests/test_polarity_golem_ai.gd
tests/test_polarity_golem_ai.tscn
tests/capture_polarity_golem_ai.gd
tests/capture_polarity_golem_ai.tscn
tests/logs/polarity_golem_ai_smoke.log
tests/logs/polarity_golem_ai_stdout.log
tests/logs/polarity_golem_ai_capture_stdout.log
tests/logs/polarity_golem_ai_protection.json
screenshots/polarity_golem_ai_windup.png
screenshots/polarity_golem_ai_hit.png
docs/ENEMY_POLARITY_PROTOTYPE.md
```

变更白名单之外未动：正式两关、共享 `scripts/player.gd`、`scenes/player.tscn`、
`project.godot`、字体、12 张实验图/源图、旧截图、旧日志。
`polarity_golem_hud.gd` 本轮也不需要改（原有 12 px 布局继续显示新增的 AI 状态文字）。

**上一轮可读性修订（2026-11-12）改动/新增：**

```text
scripts/experiments/polarity_golem_enemy.gd       (移除自绘碎石；die 11 等待；头顶读数)
scripts/experiments/polarity_golem_hud.gd         (12 px 原生文字、重排 HUD、辉相/澜相)
scripts/experiments/polarity_golem_experiment.gd  (状态文案；移除旧结果行调用)
tests/test_polarity_golem_readability.gd
tests/test_polarity_golem_readability.tscn
tests/capture_polarity_golem_readability.gd
tests/capture_polarity_golem_readability.tscn
tests/logs/polarity_golem_readability_smoke.log
tests/logs/polarity_golem_readability_stdout.log
tests/logs/polarity_golem_readability_protection.json
screenshots/polarity_golem_readability_active.png
screenshots/polarity_golem_readability_rubble.png
docs/ENEMY_POLARITY_PROTOTYPE.md
```

上一轮已交付的实验文件仍在，未删除：
`scenes/experiments/polarity_golem_experiment.tscn`、`polarity_golem_player.gd`、
12 张实验素材、旧测试/旧截图等。**`screenshots/polarity_golem_experiment.png` 未改动**；
它是上一轮小字版本的记录，不作为本轮可读性证据。

`.godot/` 下的导入缓存、新图片旁的 `.import` 文件和新脚本旁的 `.uid` 文件由 Godot 自动生成，
不属于用户源文件改动，也不计入保护基线；首次在全新环境打开工程时让编辑器完成一次导入即可。

## 7. 验证记录（累计；最近一轮 AI 见 7.4/7.5）

### 7.1 Headless readability smoke

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/test_polarity_golem_readability.tscn
```

实际结果：

```text
TEST_SUMMARY pass=31 fail=0
RESULT: PASS
```

上一轮只跑了这个相关最小 smoke，**没有重新运行上一轮 104 项大套，也没有跑正式两关**。
覆盖：

1. 解析/载入；`_draw_rubble` 方法不存在；头顶读数 z=10；HUD 字体尺寸审计
   `[12×10, 24×1]`，无 7–10 px；HUD 使用“辉相”且无菱形；生产等待仍为 8.0 s。
2. 真实 J 击杀 → `RUBBLE`；Sprite visible，纹理为 `golem_1_die.png`，索引 11，
   头顶为 `0.6秒后重组`（测试缩短等待）。
3. Esc 暂停 30 帧：帧号、纹理、visible、倒计时均冻结；Esc 恢复。
4. 观察到倒放 11..0，回到 ACTIVE，满血 3，idle 纹理，位置仍在击散点。
5. R 恢复：玩家/石怪出生点、ACTIVE 满血、头顶恢复 `辉相 +`。

日志：`tests/logs/polarity_golem_readability_smoke.log`、
`tests/logs/polarity_golem_readability_stdout.log`。

### 7.2 真实 GUI 截图

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/capture_polarity_golem_readability.tscn
```

- `screenshots/polarity_golem_readability_active.png`
  活动状态：头顶 `辉相 +` 原生 12 px + 深色底板、3 格血条；底部 HUD 无裁切。
- `screenshots/polarity_golem_readability_rubble.png`
  真实等待期：Sprite 可见、die 纹理索引 11、头顶 `8.0秒后重组`；没有自绘碎石。

两张图都是 640×360 的 Godot GUI 实际渲染。旧 `polarity_golem_experiment.png` 未改、未删。

### 7.3 基线与保护

- 既有 `project.godot`、`scenes/scripts/tests`、角色源图、Golem 源图共 **168/168 未改动**（上一轮）；
- 12/12 复制素材与源文件 SHA256 完全一致；
- 本轮另生成 `tests/logs/polarity_golem_ai_protection.json`：34 个保护对象
  （project/scenes/level_01/level_02/player.gd/player.tscn/字体/12 张实验图/旧截图/14 张源图）
  变更前后 SHA256 全部一致；
- 上一轮报告保留在 `tests/logs/polarity_golem_readability_protection.json` 与
  `tests/logs/polarity_golem_protection.json`。

### 7.4 本轮 AI / 砸击 headless smoke

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/test_polarity_golem_ai.tscn
```

实际结果：

```text
TEST_SUMMARY pass=84 fail=0
RESULT: PASS
```

覆盖（测试中的 0.5 s 重组等待已明示，生产仍 8.0 s）：

1. 真实载入；巡逻区 240..520、60/100 px/s、120 px 警戒、0.28/0.12/0.30/0.15 s、
   26×20 拳落区、玩家 0.15/0.6/160 参数逐项核对。
2. 远离玩家时 1 s 真走约 60 px；玩家在 120 px 内触发真实接近；
   站在面前 1.05 s 后遭到真实砸击，位移 29.8 px，仍在地面 y=288。
3. 每砸击只加 1 次击退；0.6 s 保护期内新接触被拒绝；保护结束后才接受；
   按住朝敌方向时仍能看到反向位移。
4. 真实 J 同相在举臂段扣 1 HP、敌人受击击退，取消本次砸击且其原有效窗口无延迟命中；
   异相 J 为 `PULL_ALREADY_CLOSE`、0 伤害，砸击仍进入“砸击”段并命中；
   命中同时打断玩家的在途挥击，不留下延迟 HP 伤害。
5. 绕到背后或跳起可躲开锁向砸击；临时墙使结果为 `BLOCKED`；
   真实矮墙可挡警戒，也可把玩家击退停在 x=538（未穿墙）。
6. Esc 冻结巡逻、砸击计时/帧、玩家保护与击退位置；击散保持 die 索引 11；
   缩短 0.5 s 后原地满血复活；复活 0.3 s 内不命中，首次命中在 0.80 s 后；
   R 恢复敌我出生、HP、巡逻、保护和计数。

日志：`tests/logs/polarity_golem_ai_smoke.log`、
`tests/logs/polarity_golem_ai_stdout.log`。

### 7.5 本轮真实 GUI 截图

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe \
  --path "D:\godot game\星核旅人\基础场景原型" \
  res://tests/capture_polarity_golem_ai.tscn
```

- `screenshots/polarity_golem_ai_windup.png`
  真实举臂预警：attack 帧 4，HUD 状态“活动 / 举臂预警”，玩家尚未被命中。
- `screenshots/polarity_golem_ai_hit.png`
  真实落拳后：attack 帧 7（双拳向下），玩家已被推到 x≈327.4，
  HUD toast“石怪砸击：向左短退（无伤害，0.6s保护）”。

两张图均为 640×360 Godot GUI 实际渲染；新前缀 `polarity_golem_ai_*`，旧图未覆盖。
捕获日志：`tests/logs/polarity_golem_ai_capture_stdout.log`。

## 8. 未验证 / 已知限制

- 没有做完整人工试玩；只做了本轮相关最小 smoke + 两张真实 GUI 图。
- 没有真实等满 8 s 的 GUI 端到端流程；等待图是上一轮刚进入 RUBBLE 时的 8.0 s 显示，
  流程正确性由缩短测试覆盖。
- 敌人现在有巡逻/接近/砸击，但玩家仍无 HP、无音效/星核/胜负/运输谜题；
  砸击只造成短退，不扣血。
- 石怪与角色 combo 源包许可未核实，不能作为可发布/可署名证据。
- 第二关右端通行缺陷未修；所有正式关和共享系统未改。
- 临时测试缩短、`debug_set_hp`、`debug_begin_attack` 只用于测试 setup，
  生产默认仍为完整 AI 和 8.0 s 重组等待；没有为了测试关闭生产 AI。
- 旧 104 项测试、旧捕获脚本和旧截图保留为上一轮记录，本轮没有重跑/覆盖；
  旧静态靶实验测试未作为本轮证据，协调者可在后续盘点时处理。
