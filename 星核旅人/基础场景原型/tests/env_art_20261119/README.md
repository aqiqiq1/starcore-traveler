# L2/L3 背景层次与 L2 地面边缘·验收证据（2026-11-19）

本轮只做两件事：给 L2/L3 的现有 DS03 背景层加**逐层明度/冷暖分级**，并给 L2 主地面和两处高台加**非碰撞边缘装饰**。未改碰撞、玩法、关卡布局、门/机关、L1 已批准画面，也未新增视差相机。

## 参考核看

依据 `../项目归档/收尾_20261119/REF_ART_20261119.md`，并本轮实际打开：

- `非运行资料/预览参考/previews/l3_wall_detail_20261116/refs/sotn_entrance_60s.jpg`（SotN 城堡入口）
- `.../refs/sotn_castle_keep.jpg`（SotN Keep）
- `.../refs/sotn_outerwall_stone_crop.png`（SotN 外墙石构裁片）
- `非运行资料/预览参考/previews/bridge_ground_sample_20261113/art/contact_sheet.png`（本工程 15px 路面/20px 层/9px 底缘样板）

实际观察：Keep 段远山/天空低对比，前景石台更暗更实，顶缘亮、底面暗，左缘有藤蔓/苔；外墙裁片显示大块石顶缘亮线、砌缝深、底部暗；本工程地面条已有 1px 顶亮和暗缝，但只有整条细亮线，没有缺角/苔/碎石。只借这些明度层次与结构读法，不照搬黑红/月亮/窗棂/具体像素。

未核实：以上 SotN 截帧为 320×240 静态图，不能据此断言连续动画、相机运动或遮挡时序；本轮只用于静态明度/边缘结构参考，未重新下载原视频。本文的 640×360 对比图来自本工程真实渲染，不是对参考图的剪辑。

## 改动文件

| 文件 | 改动 |
| --- | --- |
| `scripts/backgrounds/cloud_ruins_ds03.gd` | 新增 `depth_grade` 导出（默认 `"default"`）、L2/L3 两套逐层 modulate/alpha 预设、`set_depth_grade()`、2 行 1px 地平线雾带绘制 |
| `scenes/backgrounds/cloud_ruins_ds03.tscn` | 新增默认隐藏的 `HorizonHaze` 节点（位于 SeaMain 与 Arch 之间）；默认路径不绘制 |
| `scenes/level_02.tscn` | DS03 实例设 `depth_grade = "l2_depth"`；新增非碰撞 `EdgeDecor` 节点（`z_index=2`） |
| `scenes/level_03.tscn` | DS03 实例设 `depth_grade = "l3_depth"` |
| `scripts/l2_edge_decor.gd` | 新增：L2 主地面 25 处、低廊顶 3 处、联动高台 3 处的苔簇、缺角、碎石、2px 顶缘高光与 2px 底面暗边 |
| `tests/env_art_20261119/*` | 新增本目录的采集脚本、证据图、日志与 README |

未改 `assets/bridge_stone_v1/generated/l2_ground_1792x40.png`、任何碰撞、站位、20px 核通道、10px 真缝、平台几何，也未改旧测试/`assets/mechanic_demos/`/弹窗/音频/既有 `.md`。

### 背景分级说明

- L1（`depth_grade = "default"`）：完全不进入分级分支，不改任何 modulate，不绘制雾带。
- L2/L3：只对现有具名层 `Base`/`Sky`/`Groups/G1..G5`/`SeaMain`/`Arch`/`SeaNear`/`Rocks`/`Debris` 设 `modulate`。
  - 远拱、远组：降 alpha + 轻微冷色，向天空/海面靠拢；
  - 近海 `SeaNear`、礁石 `Rocks`：压暗并去红，暖灰前景因此更跳；
  - 天空/基底：红略降、蓝略升，绿通道基本不变（不整体压黑）。
- 雾带：`y=270..274` 五行 1px，alpha 0.04/0.09/0.15/0.14/0.06，画在 SeaMain 之后、Arch 之前；不是渐变图。

### 地面装饰说明

- 只贴三处可见边缘：主地面 `(0,320,1792,40)`、低廊顶 `(464,268,256,32)`、联动挑沿+高台 `(1040,240,40,12)`/`(1080,240,160,60)`。
- 所有绘制矩形都在 `y<=299`（高台边）或 `y>=320`（主地面）；**不进入 300..320 的 20px 核通道**，也不在主地面上方绘制。
- `z_index=2`：位于玩家（z=5）、星核（z=4）之下，不会被脚/核遮挡；同时高于 L2 运行时生成的导电晶体覆盖层（有效 z=1），否则高台顶缘装饰会被晶体盖住。
- 每处边缘为手选锚点，不是逐像素随机噪声；同一构建重复运行像素一致。

## 运行方式

工程根目录：`基础场景原型/`。Godot：`D:\Godot\Godot_v4.7.2-stable_win64_console.exe`。

采集（窗口模式，真实渲染器）：

```
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/env_art_20261119/capture_env_art.tscn -- --tag after
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/env_art_20261119/capture_env_art.tscn -- --tag before --baseline
```

`--baseline` 对同一构建关闭分级并隐藏 `EdgeDecor`，用于生成“改动前”像素；不是存档旧图。L1 的无分级路径由 `ds03_default` 哈希与 L1 全帧 0 差异共同证明未变。

证据合成与像素复核：

```
D:\minic\envs\2024212971\python.exe tests\env_art_20261119\make_evidence.py
```

采集脚本对每个机位输出两张 640×360：

- `<id>_full.png`：正常构图（仅隐藏 HUD/教学弹窗）；
- `<id>_clean.png`：隐藏玩家视觉、星核、守卫、浮块、符石、出口等动画物，背景时钟冻结在 t=4.0、暂停物理后取帧。**像素 diff 只用 clean 帧**；构图看 full 帧。

## 验收结果（实测）

### 1. 同机位前后对比（`compare/`）

- L2 起始：`l2_start_before_after.png`
- L2 联动仓/高台：`l2_linked_before_after.png`
- L3 门前：`l3_gate_before_after.png`
- 附加：`l2_lowcorridor_before_after.png`、`l3_start_before_after.png`、L1 两张。

### 2. 4× 裁片（`compare/`）

地面边缘：`l2_ground_start_4x_*`、`l2_ground_chip_4x_*`、`l2_ground_mid_4x_*`、`l2_roof_left_4x_*`、`l2_roof_right_4x_*`、`l2_wall_lip_4x_*`、`l2_wall_right_4x_*`。

背景：`l2_far_arch_4x_*`、`l2_sea_rock_4x_*`、`l2_horizon_haze_4x_*`、`l3_far_bridge_4x_*`。

脚/核遮挡核对：`l2_edge_clearance_6x.png`（星核停在 x=34 苔簇上方，玩家站在 x=236 缺角上方；装饰均被脚/核压在下面，未盖住脚底与核体）。

### 3. 像素 diff（`diff.log`）

- `l1_start`：0/230400，peak 0；`l1_high`：0/230400，peak 0。
- `l1_start_clean.png` before/after SHA256 相同：`055c850deaa72572b6127ff84aab48b0ce7fc036e26c0e7a12cb7ad4f07abcd0`。
- `ds03_default.png`（无分级默认场景）before/after SHA256 相同：`025c12e7905021b881b32ed0028ee3adfbfda943856167321066ad9cc02615c7`。
- L2 天空/远景/近海（排除两处高台边缘带）最大通道差 19；L3 背景最大通道差 21–23。
- L2 背景区域峰值 106 来自高台顶缘装饰（y=240/268 的一行苔/缺角），地面区域峰值 106 来自主地面边缘锚点；bbox 最大 y=325，未触及玩家/核通道。
- L3 `l3_gate` 差异只在背景（bbox `0,0,440,320`，peak 21）；门前石墙、地面、门板 0 差异。

### 4. 碰撞/通道审计（`capture_run_after.log`）

```
EdgeDecor ... drawn=379 corridor_overlaps=0
L2 collision ground=(1792.0, 40.0) roof=(256.0, 32.0) wall=(160.0, 60.0) lip=(40.0, 12.0) return=(48.0, 12.0)
```

`drawn=379` 是 1px 矩形段数（含顶缘分段高光），`corridor_overlaps=0` 为运行时对所有装饰矩形的 300..320 通道相交检查结果；碰撞尺寸与改前一致。

### 5. 启动/导入

- `import.log`：`--headless --editor --import --quit`，exit 0，无 ERROR/WARNING。
- `level_01_quit90.log` / `level_02_quit90.log` / `level_03_quit90.log`：三关各 `--headless --quit-after 90`，exit 0，无 ERROR/WARNING。

## 未验证 / 局限

- 未做真人完整试玩，未重跑旧的大测试套件；只做了本目录采集、L1 像素保护、三关 90 帧启动与导入。
- “改动前”图由同构建 `--baseline` 关闭功能生成，不是历史截屏存档；未改代码路径的不变性由 L1 0 差异和 DS03 默认哈希相同证明。
- clean 帧为消除动画/计时噪声隐藏了玩家、星核、守卫、浮块、符石、出口等；它们只用于像素对比，正常构图看 `_full.png`。
- 背景仍是同一套屏幕固定层，没有新增视差；只调现有层 modulate/alpha + 2 行雾带。L2 的天空/远景最大通道差约 19，属于克制的空气透视，不是大幅改色。
- L2 高台被运行时导电晶体层覆盖，边缘装饰用 `z_index=2` 才能显示；若未来要求晶体激活时完全无遮挡，这是需要复核的设计取舍。
- 地平线雾带只有 2 行、alpha 很低，1× 下接近不可见，主要用于 4× 检查时的海天分层；如觉得多余可删，不影响其它改动。
- L3 地面边缘不在本轮范围，仍是原有 `l3_terrain.gd` 的顶亮/底暗绘制。
- 新增装饰为代码绘制，没有新增 PNG/第三方素材；证据目录中的 PNG 被 Godot 自动生成了 `.import` 旁车文件，这是工程资源扫描的正常结果。
