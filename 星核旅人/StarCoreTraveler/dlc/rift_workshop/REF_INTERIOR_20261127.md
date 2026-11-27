# DLC2 裂隙工坊 · 室内背景参考核看记录（2026-11-27）

任务：把 DLC2 从 DS03 云海改成整章室内工坊。参考只用于观察结构与明暗关系；**没有裁切、描摹、取色或复制任何第三方像素进运行资产**。

## 1. Castlevania: Symphony of the Night — Marble Gallery

- 来源页：<https://www.vgmuseum.com/mrp/stage-sotn.htm>（2026-11-27 实际打开）
- 实际画面：
  - <https://www.vgmuseum.com/mrp/cv-sotn/screens/stage-marble1-2.png>
  - <https://www.vgmuseum.com/mrp/cv-sotn/screens/stage-marble1-1.png>
- 研究副本：`references/sotn_marble_gallery_01.png`、`references/sotn_marble_gallery_02.png`（仅研究，不是运行素材）
- 实际观察：
  - 重复的竖向开间建立走廊节奏；深绿灰石墙、深棕木柜体、暗金只作 1–2 px 柱头/边框。
  - 墙面上部大面积留暗，细节集中在柱头、拱缘和钟柜顶；地面用更亮的灰石把人物从暗墙前分离。
  - 深色木构与石墙并置时，木构是“暗块”，不是满屏木纹；金饰少而细。
- 能借鉴：重复开间、深木+石墙的明度分层、金色只做 1 px、上方偏左的柱头受光、让玩法角色留在较亮的水平带。
- 不能照搬：钟柜、雕像、具体纹样、原颜色值、原像素。
- 未核实：参考站点截图版权状态；本记录只声明实际打开并观察。

## 2. Chrono Trigger — Zeal Palace（浮空城内景）

- 来源页：<https://pixelguides.org/chrono-trigger/the-kingdom-of-zeal-and-mt-woe/>（2026-11-27 实际打开）
- 实际画面：
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/zpal1.webp>
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/throne_in.webp>
  - <https://img.pixelguides.org/img/chrono-trigger/walkthrough/oc_zeal0_01.webp>
- 研究副本：`references/ct_zeal_palace_hall.webp`、`references/ct_zeal_throne.webp`、`references/ct_zeal_corridor.webp`
- 实际观察：
  - 大厅用暖棕/赭色地砖与深紫墙面、暗蓝灰石拱形成明确冷暖对照；地面砖缝横向连续，顶边 1 px 亮。
  - 王座厅/走廊靠大块暗场和少量金色细线建立“贵重感”，不靠密集噪点；青色灯带只出现在局部。
  - 大拱、粗柱和地面压边构成安静的大面，装饰集中在边界。
- 能借鉴：暖棕地砖+暗墙、粗石拱的压缩节奏、金色细线、局部暖光、保持大块安静面。
- 不能照搬：王座、魔法阵、具体门形、原角色/怪物、原游戏像素与布局。
- 未核实：参考页截图许可；只作观察。

## 3. 本工程直接基准（实际打开截图）

- `screenshots/art_audit_20261127/after/level_02.png`：L2 冷云海石桥；石面顶边 1 px 亮、底边暗缝，柱左亮右暗；紫/青构件是唯一高饱和色。
- `screenshots/art_audit_20261127/after/dlc_03_loom.png`：DLC3 冷石厅；灰紫石墙、三扇 126×204 拱窗、40 px 壁柱、紫幕、金线。它证明“冷石+大窗+紫幕”是 DLC3 的既有识别，DLC2 必须避开这套组合。
- `screenshots/rift_interior_20261127/before/start.png`、`mid.png`、`boss.png`：改造前 DLC2 三个机位。紫幕（#a874ff）、金桥/青桥、金/青双面镜在云海前可读；室内化后必须保持同样的第一眼对比。
- 既有规格：`dlc/PRESENTATION_SYSTEM.md` 第 6 节、`dlc/art_audit_20261127/REFERENCE_LOG_20261127.md`、`dlc/star_loom/tools/gen_city_assets_v2.py`。

## 4. 对 DLC2 室内化的直接结论

1. **结构**：用重复的石拱/石墩建立纵向节奏，木梁横贯顶部；树影/木纹只在梁、柱、铁箍上，不在整面墙铺满。
2. **颜色**：石墙用 L2 石族压暗并加暖环境光；木用深棕（30–108），铁用 24–84 的冷灰褐；金只保留檐口/踢脚 1 px 暗金线。**不引入 DLC3 的大面积冷紫幕或青色窗光**，把高饱和留给玩法。
3. **光**：主光上方偏左——所有水平构件顶边 1 px 暖亮、底边 1 px 暗；所有柱/梁左边 1 px 亮、右边 1 px 暗。炉火只做局部暖光，不改变结构受光方向。
4. **可读性**：桥段 y200–320 的背景压暗，避免在紫幕/金青桥后面放亮窗、亮金饰；Boss 镜厅的镜面用中性深灰玻璃，不用青/金大面积，让双面镜仍是画面最亮的高饱和体。
5. **安静**：48×24 石砖、1 px 缝、确定性 4 色轮换；链/箍/铆钉只在梁柱节点；不做随机污点场。
6. **参考边界**：SotN/CT 只借“深木+石+暗金+重复开间+暖地砖”的关系，不复制其图形、纹样、色板或像素；运行资产全部由 `dlc/rift_workshop/tools/gen_interior_assets.py` 程序化生成。

## 5. 本轮落地与证据

- 生成器：`dlc/rift_workshop/tools/gen_interior_assets.py`（Pillow，确定性）。
- 四层：`dlc/rift_workshop/assets/interior/interior_back_1880x360.png`、`interior_mid_1880x360.png`、`interior_fore_640x360.png`、`interior_floor_1880x40.png`；另有暖尘底图与 52×112 / 52×84 工坊支柱。
- 场景：`Background/CloudRuinsDS03` 已替换为 `Background/Back`、`Mid`、`Fore`；`Background` CanvasLayer 与 `RiftFog` 节点名保留；`RiftFog` 改为暖尘；新增世界坐标 `RiftFloor`（y=320，z=2）。地形/碰撞节点坐标未改，`Column*` 节点名与坐标未改，仅把装饰引用换成本章工坊支柱。
- 旧云海：`scenes/backgrounds/cloud_ruins_ds03.tscn`、`assets/backgrounds/cloud_ruins_ds03/`、旧 `assets/rift_fog_640x360.png` 全部保留。
- 截图（640×360，实际运行视口）：`screenshots/rift_interior_20261127/before/{start,mid,boss}.png` 与 `.../after/{start,mid,boss}.png`，逐张实际查看。改造前 `before/start.png` 的测试玩家在 x=96，改造后使用真实出生点 x=40；摄像机都在 0–640，背景对照不受影响（说明见该目录 README）。
- 开场镜厅帧：`screenshots/rift_interior_20261127/after/intro_mirror_hall.png` 取自实际开场 2.35 s 的 `03b_phase_wave.png`（完整开场证据仍在 `screenshots/rift_opening_20261127/`）；另核看 0.72 s 的 `01_mirror_hall_wide.png`。
- 拱洞内层（2026-11-27 追加）：入口拱、中段巨拱、镜厅三拱均改为“外层拱框 + 退进 7–10 px 的 32×16 暗砖内墙 + 1 px 内缘弱光 + 底部暖反射”；巨拱加双齿轮、管道/阀轮、木架与余烬光；镜厅三拱在镜面后加齿轮/管道/吊链/木架剪影，并在镜面玻璃里画低对比反射（齿轮、斜撑、木架、砖块、暖底光）。不再用纯黑填充。
- 近黑实测（max(R,G,B)<24，阈值 40%）：
  - 背景层拱洞：entry 0.00%、giant 0.00%、mirror1/2/3 1.84% / 0.45% / 1.84%。
  - 游戏帧：start 5.51%、mid 2.27%、boss 1.19% / 0.71%。
  - 开场：0.72 s（0.50 暗场）26.90% / 19.70%；2.35 s 4.34% / 2.14%。最差 26.90%，低于 40%。
  - 复现：`D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/verify_interior_arches.py`。
- 导入：`dlc/rift_workshop/tests/import_interior_20261127.log`，0 ERROR。
- 回归：`dlc/rift_workshop/tests/run_all_interior_20261127.log`，10 项 exit=0、problems=0；本体三关各 90 帧 0 错误。
- 说明：跑测试前，工作树中的 DLC2 旧测试套件被删除；已从 HEAD 恢复。`route_test`/`parity_test` 与 `run_all.ps1` 只增加了退出前释放标题 BGM 的测试清理（raw `--quit-after` 会留下 `title_theme.ogg` 的引擎 teardown ERROR），未改任何断言、玩法或 HUD。

## 6. 未核实

- 参考页面与截图的版权/许可状态（研究用途，不进入运行资产）。
- 连续运动中的遮挡与视差：本轮以三个 640×360 定帧+实际场景运行检查；未做完整人工试玩。
- 开场电影/完整战斗期间的背景可见范围未逐帧人工核看；本章测试的 90 帧与路线测试只覆盖加载/运行/玩法，不代表电影全程。
