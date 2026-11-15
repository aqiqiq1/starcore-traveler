# 资产来源与许可记录

本文件记录 `基础场景原型/assets/` 中实际使用的第三方/项目内资产。原型只复制运行所需文件；未导入 `individual_sheets.zip`、角色设计/combo 表、作者预览、联系表、GIF 或额外角色。

## 1. 角色

- 来源（原文件，只读）：`D:\godot game\星核旅人\individual_sheets\`
- 复制文件：
  - `male_hero-idle.png` — SHA256 `5e3b80a9dc6425f57121b0820e285b4580bdfa2ed944cfeedf2bd61d8a92aa8f`
  - `male_hero-walk.png` — SHA256 `2a2e47a6a5f681402a973d8012fc1b8ab5255f7fada2ea28df8aaa892421fd0e`
  - `male_hero-run.png` — SHA256 `35cdcc9ddd8b577d44c40cdcc8ff5e667cc32d78a713e5ba5470174644a07c9a`
  - `male_hero-jump.png` — SHA256 `cf79ad07cf1dc84b9b83c753e76c01150182425e452c48d92e636c7b12ee956e`
  - `male_hero-fall.png` — SHA256 `200ea67d437ed5824b2c5f66fe471e30d6f8007266383eba5dcc1b71742a8413`
  - `male_hero-fall_loop.png` — SHA256 `96b43a2e4ac73d55943207bb836273bb33845520c7d34cbc337159a290325277`
- 许可：**未提供/未知**。提供的素材包中没有角色作者声明或许可文本。已在 `assets/characters/LICENSE_UNKNOWN.txt` 说明。
- 使用范围：仅用于本项目内部课程原型。对外发布前必须由项目负责人补齐授权证据；不得把本工程当作角色已获发布许可的证明。
- 修改：PNG 文件未改动，只做了复制。运行时按 128×128 原帧显示，不缩放；碰撞体为 12×30，不含围巾和透明画布。`walk` 已加入默认移动状态（10 帧，9 FPS），`run` 仅由左 Shift/同方向双击触发。
- 未使用：`male_hero-design.png`、`male_hero-combo_*.png`、`individual_sheets.zip`。

## 2. 护符/光晕/扩散环（项目自制）

- 来源（原文件，只读）：`D:\godot game\星核旅人\自制素材\护符特效\`
- 复制文件：
  - `talisman_gold.png` — SHA256 `1567d719c61b35f99896fc972f36a79d01b8d994162217b70df48945ac4ea049`
  - `talisman_cyan.png` — SHA256 `6905e0448bdf085bdbe413cf71c34dbac6cc6c46f030667e43eb8c90ca4b6c3f`
  - `glow_gold_4f.png` — SHA256 `48c274d0d866ba5b1ce861000ce3df63124f811e51b1e1c5512dabd45f864acc`
  - `glow_cyan_4f.png` — SHA256 `ab534b32cb506d76c538d996de4ceacee34c27bc2baf32d29f162fa6eab1e0ba`
  - `switch_ring_gold_4f.png` — SHA256 `7a8fb1e9dc95f23e2d4fe34b40dc6921343094d47c5ed22dbe67b4cd0213dce5`
  - `switch_ring_cyan_4f.png` — SHA256 `7b40f2b5815ba33de3ae20ce96208f5b52bd81d86db31d99ec63d6cf14180ded`
- 许可/来源说明：这些像素素材来自本项目的 `generate_talisman_assets.py`（Python + Pillow 程序化绘制），没有使用第三方素材、远程图像服务或付费工具。原 `README.md` 与 `manifest.json` 一并复制用于规格和边界说明。
- 修改：PNG 未改动。工程内用 `Sprite2D` 的 `hframes=4` 切分 4 帧光晕/扩散环；位置由逐帧胸口锚点驱动。
- 备注：复制来的 `README.md` 中“未在 Godot 4 中导入/播放”一句是该素材生成阶段的记录；本原型已经在 Godot 4.7.2 中完成导入、切帧、逐帧叠加和实际截图验证。该 README 不会被当作法律许可文本。
- 未使用：`preview_chest_*.png`、`effects_contact_sheet.png`、`preview_polarity_switch.gif`、生成脚本。

## 3. Szadi art. / Pixel Platformer World（地图与背景）

- 作者：Szadi art.
- 原始页面：https://szadiart.itch.io/pixel-platformer-world
- 访问日期：2026-10-30（项目素材记录日期）
- 包内许可（已复制到 `assets/map/SZADI_LICENSE.txt`）原文：

```text
Artwork created by Szadi art.

License for Everyone.

Public domain and free to use, personal or commercial. Credit is not required but appreciated. You can edit, but not sell the asset pack.
```

- 使用文件：
  - `assets/map/ruin_platform_tiles.png` — 从 `main_lev_buildA.png` 裁切的 **派生图块条**：源坐标 `x=224..415, y=80..111`，即 12 列 × 2 行、每格 16×16（顶部装饰石/草丛行 + 深色填土行）。仅用于平台视觉，碰撞由 `main.gd` 的 5 个显式 `RectangleShape2D` 提供。**旧运行图 SHA256 `3a9fc342…ef8b5b2` 是 2026-11-12 暖灰替换前的历史哈希**；当前运行图见第 12 节，不要把它当成当前文件哈希。
  - `assets/map/background2.png` — 远景剪影，低透明度染色后用于背景分层。SHA256 `4351dc8631b1bcec12176e81a415fc26931d9aafd80f0b525948ba8662779809`
  - `assets/map/background4.png` — 近景剪影，低透明度染色后用于背景分层。SHA256 `b0d0667651c851e46c094382f829c32d00c0f7bee41a791933f0171e913d4f25`
  - `assets/map/SZADI_LICENSE.txt` — 包内许可原文。
- 修改：平台图块最初只做必需区域的裁切（未重绘）；2026-11-12 起运行图再按已批准方案做 8 色暖灰索引映射，尺寸/alpha/12×2 格不变，见第 12 节。背景只做缩放/染色/透明度调整。没有把作者的整幅示例地图或 `main_lev_buildA/B.png` 作为有碰撞地图。借力房沿用同一 `ruin_platform_tiles.png` 派生条，只重排起点/落点矩形，没有新增第三方素材。
- 未使用：`main_lev_buildA.png` 的其余颜色/图块、`main_lev_buildB.png`、`Anim/`、其他背景、`.zip`。
- 署名：作者表示不必署名但“appreciated”。原型内部记录为 “Tiles/backgrounds: Szadi art. — Pixel Platformer World”。

## 4. 借力房符文石（项目自制，复用裂隙符石）

- 来源：`scripts/anchor_room.gd` 在固定锚点 `(320, 200)` 实例化 `scenes/rune_stone_visual.tscn`，复用 `assets/rune_stone/rune_stone_sleep.png`、`rune_stone_gold.png`、`rune_stone_cyan.png` 三张 32×32 状态图；原 `_draw_anchor_stone()` 的 28×28 方块、苔藓和大加号已移除，没有外部图片、纹理或第三方素材。
- 性质：F2 固定 GOLD 正极展示；玩家进入 160 px 范围时组件在石壳外显示小型悬浮 `+`。符石仍无实体碰撞，不改变范围、力、遮挡、起落点或成功条件。
- 许可：三张状态图来自项目内 `自制素材/符石概念示意/generate_concept.py` 的已批准 `sprite()`，由 `自制素材/裂隙符石/generate_rune_stone_assets.py` 直接 96→32 NEAREST 转换；如单独作为素材包发布，需项目组另行决定许可与署名。

## 5. 字体、引擎与其他

- 字体：正式两关 HUD、教程石碑、第一关残响对白与菜单提示使用本地 `assets/fonts/tutorial_zh.ttf`（Fusion Pixel 12px Prop zh-Hans，作者 TakWolf，SIL Open Font License 1.1）；旧英文 debug 界面仍可显示 ASCII。来源、校验值和许可原文见 `docs/TUTORIAL_FONT_SOURCE.md` 与 `assets/fonts/tutorial_font_LICENSE.txt`。
- 引擎：Godot 4.7.2 stable（`D:\Godot\Godot_v4.7.2-stable_win64_console.exe` / GUI 同名无 `_console` 版本）。
- 声音/音乐：未使用。
- 生成工具：Python 3（`D:\minic\envs\2024212971\python.exe`）只用于离线切图/像素审计/截图拼图，不进入游戏运行时。
- 截图：`screenshots/` 下 22 张基础房 640×360 PNG 是运行中 Godot 根视口的实际捕获（01–20 为 pre-walk legacy，21–22 为 post-walk）；另有 4 张 `anchor_01`–`04` 借力房捕获（2定帧+2脚本物理运行静帧）。`CONTACT_SHEET.png` 是 01–22 实际捕获的 1.5× 最近邻拼图，`WALK_ADDENDUM.png` 是 21/22 的 2× 拼图；`docs/anchor_audit.png` 是源帧 + 护符叠加的审计图，**不是引擎截图**，图中已标注。

## 星核三态（Frakassets 派生）

- 原素材：Free Shiny Gem "Round" by Frakassets，https://frakassets.itch.io/free-shiny-gem-round 。许可：CC BY 4.0，https://creativecommons.org/licenses/by/4.0/ 。
- 工程文件：`assets/star_core/star_core_locked.png`、`star_core_positive.png`、`star_core_negative.png`，均为16×16透明PNG。
- 动态文件：同目录 `star_core_locked_12f.png`、`star_core_positive_12f.png`、`star_core_negative_12f.png`，每表192×16、12帧，单帧16×16，默认12FPS。紫色动态表复制源表，金青两表沿用调色方法逐帧修改；静帧文件保留为回退，动画不改变来源或CC BY 4.0署名义务。
- 修改：从 `gem_round_16x16_12f_0d.png` 截取第0帧；紫色锁定态保留源帧RGBA，正/负态分别调为金色/青色。详细来源、SHA256和生成参数见项目根目录 `自制素材/星核三态/manifest.json`。这些是第三方素材的派生资源，不是完全原创资源。
- 正负/锁定标识由 `scripts/star_core_visual.gd` 独立绘制，不修改宝石图；仅用于组件和独立预览，尚未实现星核运输或星核仓。

## 星核仓（项目自制、首版）

- `assets/star_core_bay/star_core_bay_base.png`、`star_core_bay_glass.png`、`star_core_bay_empty.png` 为本项目Pillow程序绘制的32×32静态PNG，没有使用外部图像服务或第三方仓体素材。生成脚本和记录位于项目根目录 `自制素材/星核仓/`。
- 底座、玻璃与既有紫色星核分层。锁定标识由 `scripts/star_core_bay_lock_mark.gd` 绘制；空仓PNG不包含第三方星核。满仓预览中的星核仍属于上述Frakassets CC BY 4.0派生素材，不因组合进仓体而改变其署名义务。
- 这是待用户确认的原型美术，未接入存取玩法。

## 裂隙符石与极性联动视觉（项目自制、概念 sprite 直接转换）

- 外观唯一来源是项目已批准的概念脚本 `自制素材/符石概念示意/generate_concept.py` 中的 `sprite('sleep'/'gold'/'cyan')`。`assets/rune_stone/rune_stone_sleep.png`、`rune_stone_gold.png`、`rune_stone_cyan.png` 由 `自制素材/裂隙符石/generate_rune_stone_assets.py` 原样调用该函数取得 96×96 图，再直接 96→32 NEAREST 转换；没有裁切整张 `concept.png`、没有重画轮廓/裂纹、没有随机点或新增光晕。SHA256、尺寸、转换方法和对照图见 `自制素材/裂隙符石/manifest.json` 与 README。
- `scripts/rune_stone_visual.gd` 用概念自带的 sleep 图作底层，用 gold/cyan 整态图作上层：静止亮态上层 alpha=1，休眠 alpha=0；换极时旧上层先暗出、再亮入新上层，结束才发 `transition_finished`。金/青内芯、内壁反射和壳缘高光来自概念图本身，不再用白遮罩近似。石壳不旋转，换极不改变裂纹；未激活不出现金/青/紫光。
- `scripts/polarity_link_visual.gd` 的记录灯、细符文线与光脉冲均为程序绘制，没有新增下载素材；组合预览继续使用既有仓体和Frakassets星核，后者仍须按前文CC BY 4.0署名。
- F7 实际记录房通过现有 `RuneStoneField`/`RuneStoneVisual` 直接显示同一套三态图，记录灯即时、脉冲、先暗后亮、激活/变极提交、取核和 R 清记录规则未改。
- F2 借力房由程序方块加号替换为同一 `RuneStoneVisual` 的固定 GOLD 状态，位置/力/碰撞/路由不变；外观仍待用户实机确认，不称最终美感验收。

## 6. 对外发布前必须处理

1. 补齐角色作者/许可证据，确认修改、随游戏发布、商业/课程使用与署名要求。
2. 如果分发素材包本身，注意 Szadi 许可明确禁止转售素材包；游戏内使用按作者 public-domain/free-use 声明处理，但正式发行前建议由负责人复核。
3. 护符/光晕/扩散环是项目程序化绘制；若要单独作为素材包发布，需项目组另行决定许可与署名。
4. 借力房符文石现复用项目自制的 32×32 裂隙符石；若单独作为素材包分发，仍需项目组决定其许可与署名。
5. 如果安装匹配的 Godot 4.7.2 export templates，可按项目设置导出 Windows；本轮本机模板目录为空，未导出 exe（详见 README）。

## 7. 教程提示石碑（项目自制、概念脚本直接导出）

- 形态唯一来源是 `自制素材/提示石碑概念示意/draw_concept.py` 的批准函数 `stone()`；运行资产在 `assets/tutorial_stele/`，由 `自制素材/提示石碑/generate_tutorial_stele_assets.py` 直接调用 `stone('grey'/'gold'/'cyan', 26)` 与 `groove_floor()` 导出，没有裁切整张概念图、没有重画轮廓/槽/座脚、没有缩放。
- `tutorial_stele_grey.png`、`tutorial_stele_gold.png`、`tutorial_stele_cyan.png` 为 26×52 原样 PNG；`tutorial_stele_frames.png` 为 64 帧 × 26×52 的预计算流光表；`tutorial_stele_groove_mask.png` 是槽 mask。生成参数、源/输出 SHA256 和逐帧槽外不变校验见 `assets/tutorial_stele/tutorial_stele_manifest.json`。
- 许可：项目自制，按概念脚本原样导出；若单独作为素材包发布，由项目组另行决定许可与署名。教程字体为第三方 OFL-1.1 字体，按上一节和 `docs/TUTORIAL_FONT_SOURCE.md` 的版权/许可要求随项目保留许可文本。
- 引擎截图：`screenshots/tutorial_stele_01..05*.png` 为运行中 Godot 640×360 根视口实际捕获，固定姿态/脚本 F 键静帧；说明见 `screenshots/MANIFEST_TUTORIAL_STELE.txt`，不冒充人工连续试玩。

## 8. 庭院多立克石柱（项目自制、V4 局部细化）

- 源目录（只读）：`D:\godot game\星核旅人\自制素材\庭院石柱\`；运行副本：`assets/doric_columns/doric_column_{tall,broken,base,fallen}.png`。
- 四张 PNG 与源文件逐字节相同，尺寸 52×108、52×82、52×24、56×28；SHA256、alpha bbox 和 `foot_anchor` 见 `assets/doric_columns/source_manifest.json`。`source_manifest.json` 是源 `manifest.json` 的逐字节副本（SHA256 `9213bec591131baa75bb2a36391adcdb4c3db134b2c3c4c4be7f2b3fdac0edc1`）；接入说明见同目录 `README.md`。
- 来源/修改：柱子像素为本项目在已批准V4重绘基础上的局部RGB细化，只修改原有不透明像素，alpha与尺寸不变；工程复制阶段未裁画、缩放、二次调色、tint或镜像。结构参考及第三方配景边界沿源 `README.md` 和 `source_v4.md`，不把结构参考当作许可证明。本次没有新增外部素材或图像服务。
- 使用：`scenes/decorations/` 下四个可复用静态 `Sprite2D` 场景，脚底中心为原点，Nearest、1 源像素 = 1 逻辑像素；第一关 `World/Decorations` 中有 10 个显式实例，`z_index = -1`，无碰撞、无 `Area2D`、无脚本，不参与符石遮挡或受力。截图为运行中 Godot 640×360 根视口实际捕获，说明见 `screenshots/MANIFEST_DORIC.txt`。
- 许可：项目自制素材；若单独作为素材包分发，由项目组另行决定许可与署名。

## 9. 云海遗迹 V7 静态背景（项目自制、保留对照、已隐藏）

- 源图（只读）：`D:\godot game\星核旅人\自制素材\云海遗迹背景概念示意\background_only_v7.png`；源说明见同目录 `source_v7.md`。源图 1280×720 RGB，是已批准 640×360 逻辑图的 NEAREST 2 倍展示稿。
- 运行副本：`assets/backgrounds/cloud_ruins_v7.png`，640×360 RGB。导出前核验源图每个 2×2 像素块完全相同（0 个差异采样），运行时图取每块左上像素；没有重采样、重绘、模糊、锐化、调色或 tint。运行图按 NEAREST 2 倍展开后与源图逐像素一致。
- SHA256：源图 `2d65a27d432ce60d8562c71cf754049d49a106d08e63348d78cb08f4c8387aae`；运行图 `0c81488d74eb87b0219ea3ead2aa31f074c1a371ab9a7aba0984b67a4a0f9092`。可复现脚本 `tools/export_background_v7.py`，记录见 `assets/backgrounds/source_manifest.json` 与同目录 `README.md`。
- 保留：`Background/CloudRuinsV7` 仍是 640×360、Nearest、`mouse_filter = Ignore`、白色 `modulate` 的真实 `TextureRect`，但已 `visible = false`，只作旧静态对照；当前第一关可见背景已由 DS03 组件接替。旧 `Background/Sky`、`FarRuins`、`NearRuins`、`Mist` 和 `World/PitCloudBack/Front/Glow` 仅设 `visible = false`，原节点、资源、参数保留。旧 `assets/map/background2.png`、`background4.png` 和 `scenes/main.tscn` 原型未改。
- V7 资产本身仍是整图静态背景，不能单独移动图中的桥、断口、石柱或云团；只作为回退/对照保留。更新后的参考专项日志 `tests/logs/ds03_v7_reference_test.log`（旧 `test_background_v7.log` 不被覆盖），截图说明见 `screenshots/MANIFEST_BACKGROUND_V7.txt`。
- 许可：项目自制素材；若单独作为素材包分发，由项目组另行决定许可与署名。

## 9A. DS03 云海遗迹动态背景（项目自制、已接入第一关）

- 源目录（只读）：`D:\godot game\星核旅人\自制素材\云海遗迹背景动态修复_DS03\`；美术拆层来自项目自制的 V2 后景细化稿，公共天空云/云海/浮石/投影来自项目 DS02 运行层，没有新增第三方下载素材。
- 运行副本：`assets/backgrounds/cloud_ruins_ds03/art_assets/` 8 张 + `common/` 16 张，共 24 张 PNG，与源目录逐字节相同；`runtime_config.json` 也是源配置的逐字节副本。哈希清单见 `source_manifest.json` 和该目录 `README.md`。
- 使用：第一关 `Background/CloudRuinsDS03` 是 640×360 屏幕固定原生动态背景，层次/坐标/速度/周期按 `runtime_config.json`；G1/G2 两座完整大桥绝对固定，G3/G4/G5 仅轻浮；两桥都在 `sea_main` 之前，无旧 `island_overlay`。旧 `CloudRuinsV7` 与旧天空/远景/雾/坑云节点保留但隐藏。
- 原生 640×360 量化：小遗迹实际只取 0/-1 两个相邻原生像素（公式 < -0.25 时 -1），峰峰值 1 逻辑 px；网页的 +0.5 状态没有原生对应。未修改全局分辨率、stretch、PixelSnap 或相机。
- 资产/量化/测试说明：`assets/backgrounds/cloud_ruins_ds03/README.md`；专项日志 `tests/logs/ds03_background_test.log`；纯背景参考 `screenshots/ds03_godot_background_only.png`（640×360，无人物/地形/HUD）及截图说明 `screenshots/MANIFEST_DS03_BACKGROUND.txt`、`screenshots/ds03_capture_manifest.json`。
- 许可：项目自制素材；若单独作为素材包分发，由项目组另行决定许可与署名。

## 10. 恢复点与通关门双态图（项目自制、已接入第一关）

- 源目录（只读）：`D:\godot game\星核旅人\自制素材\恢复点与通关门概念示意\`；源说明见同目录 `README.md`。源图是该目录用 Pillow 程序化绘制的概念稿，属于 AI 辅助的项目自制素材，不是第三方下载素材，也不是人类手绘声明。
- 运行副本：`assets/checkpoint_exit/checkpoint_inactive.png`、`checkpoint_active.png`（40×36）、`exit_open.png`、`exit_completed.png`（76×100），四张均与源文件逐字节相同。SHA256、alpha bbox 和脚底锚点见 `assets/checkpoint_exit/README.md`。
- 使用：恢复点脚底锚点 (20,35)，出口脚底锚点 (38,99)；按 1 源像素 = 1 逻辑像素、Nearest、白色 `modulate` 绘制，未缩放、调色、镜像或重绘。出口门洞中央为透明 alpha，图片没有物理实体，不改变原有 40×72 / 36×76 的 `Area2D` 触发区、节点位置或玩法。
- 本次只复制 4 张运行 PNG 和必要说明；未复制 `checkpoint_exit_preview.png`、展示字体、生成脚本 `generate_preview.py`，也未把它们放入工程。旧代码占位外观已移除。
- 专项测试与实机截图：`tests/test_checkpoint_exit_art.tscn`、`tests/capture_checkpoint_exit_art.tscn`；截图 `screenshots/checkpoint_exit_warm_01..04*.png`，说明见 `screenshots/MANIFEST_CHECKPOINT_EXIT_ART_WARM.txt`。第 04 张完成态是视觉状态检查，不是真实通关证据；真实完成与 R 复位由完整第一关测试覆盖。
- 2026-11-02 按用户反馈把石色由旧绿灰统一为 `assets/doric_columns/doric_column_tall.png` 实际使用的暖灰/灰褐色阶，只替换石色 RGB；逐像素材质核验见 `tests/verify_checkpoint_exit_stone_palette.py`。旧的 `checkpoint_exit_01..04*.png` 是调色前证据，保留不覆盖。
- 许可：项目自制素材；若单独作为素材包分发，由项目组另行决定许可与署名。

## 11. 第一关开始菜单 UI（项目自制、派生自已批准 V1 overlay）

- 源（只读）：`D:\godot game\星核旅人\自制素材\主界面概念预览_V1\main_menu_overlay_1280.png`，SHA256 `37deaa6aeaef3d6f14dff8de5b937b1ce7018d607d153afcae6887a31ba057f4`。原 `make_preview.py`、1280/640 预览和 README 未修改。
- 运行资源：`assets/menu/main_menu_ui_640.png`、`main_menu_focus_start_640.png`、`main_menu_focus_settings_640.png`、`settings_panel_640.png`、`settings_return_focus_640.png`。主菜单基础图是 V1 overlay 的精确 2× NEAREST 降采样；焦点/设置/返回图由同一字体与 V1 色值绘制。所有输出 640×360、透明、不含背景（设置图的全屏轻遮罩仅用于设置模态）。设置面板加高并重排显示选项时，三张主菜单入口图字节未变。后来新增 `main_menu_quit_640.png` 与 `main_menu_focus_quit_640.png` 两张附加退出图层，原三张主菜单图与设置图字节仍不变。
- 字体：`assets/fonts/tutorial_zh.ttf`（Fusion Pixel 12px Prop zh-Hans / TakWolf / OFL-1.1），按 12px 原生栅格 1×/2×/3× NEAREST；不使用系统字体 fallback。许可文本仍见 `assets/fonts/tutorial_font_LICENSE.txt` 和 `docs/TUTORIAL_FONT_SOURCE.md`。
- 生成器：`tools/build_main_menu_ui.py` 生成原 V1 降采样/焦点/设置图；`tools/build_main_menu_quit.py` 单独生成新增的退出字与焦点图，只写这两张附加 PNG 并校验原主菜单图哈希。输出 SHA256 与使用边界见 `assets/menu/README.md`。没有下载、外部图像服务或新增第三方美术；设置滑条/百分比/模式/分辨率/应用/焦点热区由运行时代码绘制，字体仍为上述 OFL 字体。
- 使用：`scenes/level_01.tscn` 的 `StartMenu` 显示真实 `Button`/`PixelVolumeSlider`/`PixelMenuButton` 热区；不烘焙背景、不改 DS03/Player/地形/机关/碰撞，也不代表用户已对排版或美感作最终验收。显示设置只改运行时根 `Window` 的尺寸/模式与 640×360 内容缩放，不改 `project.godot` 全局设置。
- 截图：`screenshots/menu_level01_initial.png`、`menu_level01_settings.png`、`menu_level01_camera_mid.png`、`menu_level01_camera_settled_before_entry.png`、`menu_level01_playable.png` 及对应 `_2x.png`，说明见 `screenshots/MANIFEST_MENU_LEVEL01.txt`；这些是两入口时期的历史截图，保留不覆盖。当前三入口首页另有 `screenshots/menu_with_quit.png` 与精确 2× `menu_with_quit_2x.png`，说明见 `screenshots/MANIFEST_MENU_QUIT.txt`；为运行中 Godot 捕获，非人工试玩。显示设置另有 `display_settings_*` 截图与 `screenshots/MANIFEST_DISPLAY_SETTINGS.txt`（1400×900 仅为黑边诊断窗口，不是可选分辨率）。验证脚本 `tests/verify_menu_capture.py`；测试/截图使用临时音频/显示配置并恢复 Master、Window mode/size/position/content-scale，未写用户真实配置。

## 12. 2026-11-12 全关美术统一运行图与第一关守望者残响（开发接入）

- **运行图替换与备份**：本轮把三张派生 PNG 接到原有运行路径，未改 scene 资源路径、Nearest/scale/过滤设置；Godot `--import` 会正常刷新 `.import` 元数据：
  - `assets/map/ruin_platform_tiles.png` ← `assets/art_pass_20261112/ruin_platform_tiles_warmgrey.png`。当前 SHA256 `0E4968FB754D1F76122B5319B95C893489523E43A44D36842416C9AF091D095D`。原 192×32、RGBA、12×2 个 16 px 格与 alpha 逐字节不变；只做已批准的 8 色暖灰索引映射。旧运行图 SHA256 `3A9FC342…EF8B5B2`。
  - `assets/level02_platform_v3/layer_platform_visual_640.png` ← `assets/art_pass_20261112/level02_platform_visual_highstep_trim_640.png`。当前 SHA256 `0849BA133E7A2B8A950EC0B87E959499022A6C538566E5F5121E197847BD181F`。640×360 RGBA；只把左 HighStep 可见下沿收到 y287，y≥288 alpha=0，碰撞底仍 288；主桥/右短台切片未动。旧运行图 SHA256 `EE8D38E3…CB04290`。
  - `assets/level02_platform_v3/layer_platform_decor_640.png` ← `assets/art_pass_20261112/level02_platform_decor_seams_640.png`。当前 SHA256 `5C2283F9BA29998B57D076A880D444F6B05992930B3A24613A6DF7D0DD53400D`。640×360 RGBA；只在五个真缝中心 260/284/324/348/372 增加中性石色短刻槽，并删掉左高台 y289 的两个旧苔藓像素；真实 8 px 缝、桥几何、碰撞与力场未动。旧运行图 SHA256 `58C58508…A82A9F`。
  - 替换前运行图已按相对路径存入上级 `项目归档/美术优化前运行资源_20261112.zip`，逐项 SHA-256/CRC 校验通过；未覆盖任何既有归档。当前哈希与替换说明见 `assets/art_pass_20261112/manifest.json` 的 `runtime_application`、`assets/level02_platform_v3/manifest.json` 的 `runtime_replacement`。**不要把旧 source/pre-replacement 哈希误称为当前运行 PNG 哈希。**
  - 只读批准源稿 `自制素材/第二关平台完整造型预览_V3/layer_platform_{visual,decor}_640.png` 和美术生成脚本未改；`assets/art_pass_20261112/` 原派生文件保留。
- **守望者残响运行素材（2026-11-13 起）**：`assets/guide_echo_20261113/guide_echo_idle_6f.png`，288×64 RGBA，横排 6 帧、单帧 48×64、脚底锚 (24,60)、4 fps、Nearest，SHA256 `2ACAA0E55E8F68DE8881295F82E04B7361187C8E08977C37CFB13C59C80BC233`，与同目录 `manifest.json` 一致。该文件是已批准预览表 `previews/art_reference_20261112/watcher_echo_idle_6f.png` 的**逐字节拷贝**。素材来源：LuizMelo Wizard Pack（CC0，作者页面允许免费与商业使用；包 SHA-256 `41167557A3401E7156B6557CFEC932457D333059C6F6393BF958B6B4FE3A2291`），头脸为原作者 Idle.png 原像素按固定 ROI/最近邻合成，身体为同作者衣袍色按固定列区/行带重采样；**没有手绘五官**，也未使用生成服务，未下载、未购买、未上传。派生脚本与逐帧数据见 `previews/art_reference_20261112/derive_watcher_echo.py`、`README.md`、`source_manifest.json`。Godot 中按 6 帧/48×64、4 fps、Nearest、整数坐标显示，不依赖自绘身体；无碰撞/力场/寻路/语音/立绘。**旧 4 帧图 `assets/guide_echo_20261112/guide_echo_idle_4f.png` 保留未覆盖，可用于回退。**
- **使用范围**：地面 atlas 同时服务正式两关与旧 `main/F2/F4/F7` 共用路径，未建第三关或新任务链；第二关两图层只影响本关五个 AtlasTexture 切片。第一关两处 NPC 只是同一残响的两个固定显现点，第二关石碑保留。
- **验证边界**：本轮做了 Godot 重新导入、四入口载入、聚焦测试与三张 GUI 定帧，未做人工连续试玩、未重跑旧大套、未重新核实 Szadi art. 等原始许可。详细日志/截图见 `docs/ART_GUIDE_PASS_20261112.md`。

## 13. 2026-11-13 统一石造地面、结构暗部与平底柱脚

- **创作性质**：项目内AI辅助、离线Pillow像素绘制与模块装配；不是第三方下载，不声称为人类手绘。用户先认可统一地面样板的基础材质，指出下方过亮，随后授权补结构暗部并接入正式两关。旧`previews/bridge_remains_20261113/`拼贴稿被否决，不属于本轮采用的材质源。
- **正式材质源**：`assets/bridge_stone_v1/source/atlas.png`（640×320，54个结构rect）、`atlas_manifest.json`、`build_block.py`及`source_manifest.json`；`examples/`、`contact_sheet.png`是素材检查图，不是实机证据。样板原稿保留在`previews/bridge_ground_sample_20261113/art/`，未覆盖。
- **构建与使用约定**：用同一atlas/色板生成ground、deck、pier等原生尺寸RGBA PNG，输出放`assets/bridge_stone_v1/generated/`；1源像素对应1逻辑像素，Nearest、scale1，不拉伸地形图片、不覆盖真实施力缝。暗部由檐下、分层承重体、梁底、接缝、断端内芯的实色像素组成，未改DS03图层或全局加黑罩。具体正式关引用及验证见`docs/LEVEL02_REBUILD_20261113.md`，本节不是独立的玩法验收记录。
- **平底柱脚**：`assets/bridge_stone_v1/columns/doric_column_{tall,broken,base}_basesquare.png`派生自第8节项目自制石柱，仅改底部9行（高柱99–107、断柱73–81、柱座15–23，行号从0起），上部像素、画布与脚点保持。原`assets/doric_columns/`源图保留未覆盖，fallen图未改。源及输出hash见新材质`source_manifest.json`。
- **许可**：上述新增/派生自制内容沿用项目自制资产处理；若单独分发素材包，由项目组决定许可与署名。本轮未购买、下载、使用收费图像服务或上传工程，不因此改变主角/Golem等其他素材待核许可的状态，也不把Szadi自定义许可改称CC0。


## 14. 2026-11-14 L2 正式接入：导相石构、v2 门效与 s40 残响

- **性质**：本轮四项正式接入（完整导相屋盖/返回台、L2 门内 v2 FX、两关共用 s40 残响、L2 入口 GuideEcho）来自用户已确认的隔离预览；美术为项目内 AI 辅助/离线 Pillow 绘制，不是第三方下载包。源 PNG 的预览副本保留在 previews/l2_revision_20261114/art/，正式 runtime 只引用 ssets/，不引用 previews/screenshots。
- **四张导相石构**（项目自制、由已认可 bridge_stone_v1 生成器派生并在预览内加克制刻纹）：
  - ssets/level02_conductive_stone/conductive_roof_256x32.png — SHA256 A0908DE7F920F36B65930E0462C1A0C494C946E24033292A92010B9CA0DB0E2C
  - conductive_sill_160x60.png — 24866145E2C8029FCF2771B931190FFBEB2A5773FBBE17B634D4B24841AC1EE0
  - conductive_lip_40x12.png — 2E56228A026A2CB4BB169E01348098CCA34E0F613CABBA332D45793D5CFB8664
  - 
eturn_platform_48x12.png — 2D54F91CD4CAE985C9C6F6C726AAAB6D62938E03ABAF54CC4525581CF08FF3D4
  - 四张均与预览批准文件逐字节一致；原 ssets/bridge_stone_v1/ 旧石材保留未改。许可沿用项目自制石材处理。
- **L2 门内 v2 FX**：ssets/checkpoint_exit/gate_portal_fx_v2_8f.png，608×100，8×76×100，8 fps，锚 (38,99)，SHA256 A8CB426D809E4827F756C8F7E3A289FEABD05D10C420313E71B6AC63B7F00CBE，与预览批准文件逐字节一致。仅由 LevelExit.gate_portal_fx_enabled 在 L2 opt-in；L1 默认关闭，原门框/完成图/碰撞未改。设计说明见 previews/l2_revision_20261114/art/gate_fx_v2_manifest.json、source_v2_manifest.json 与 
eview_v2.png（美术检查板，非引擎截图）。
- **两关共用 s40 残响**：ssets/guide_echo_20261113/guide_echo_idle_6f_s40.png，288×64，6×48×64，4 fps，SHA256 6CF0C33B22558D429C415D28CE394B70A6641C224A407F16A16489749574A746，与预览批准文件逐字节一致。它从原批准残响 guide_echo_idle_6f.png（SHA256 2ACAA0E55E8F68DE8881295F82E04B7361187C8E08977C37CFB13C59C80BC233）按已批准 s40 方法派生，alpha/结构/画布/脚底不变；原图保留。原残响来源为 LuizMelo Wizard Pack（CC0）的已记录派生，本 s40 不新增第三方素材或许可义务。
- **验证边界**：见 docs/L2_REVISION_INTEGRATION_20261114.md 与本轮 tests/logs；未做人工连续试玩，三张正式图是固定 setup/非通关。
