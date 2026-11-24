# 云海遗迹背景动态修复 DS03

状态：**纯背景连续预览 / 可审阅工程版**。当前动效：G1/G2 两座完整大桥绝对静止；G3/G4/G5 仅 ±0.5 逻辑 px 轻浮。本目录使用 DS03 美术拆层与 V2 外观真值，未接 Godot、菜单、摄像机、人物或游戏 UI。DS02、V2、V7、Godot 只读，未改动。

## 1. 先看什么

| 文件 | 用途 |
|---|---|
| `双击预览_DS03.html` | **推荐直接双击**。单文件、零服务器、零 fetch；24 张 PNG 全部内嵌为 base64。可单独复制到空目录打开。 |
| `preview.html` | 分文件版连续预览（同目录 `config.js` / `preview.js` / `art_assets` / `common`）。`file://` 直接打开和临时 localhost 都已实测。 |
| `reference.png` | 640×360 参考帧，t=0；从真实浏览器 1280×720 画布按最近邻降采样。 |
| `reference_2x.png` | 1280×720 实际浏览器画布帧。 |
| `checks/flow_0_8_12.png` | t=0/8/12 整帧对照。 |
| `checks/right_foot_cloud_times_4x.png`、`left_foot_cloud_times_4x.png` | 左右桥脚在 0/4/8/12/30/60 s 的同一主云海遮挡。 |
| `checks/right_foot_cloud_off_vs_on_4x.png` | 关云检查：右桥脚底图/建筑层没有残留白云块。 |
| `checks/right_foot_old_ds02_vs_ds03_4x.png` | DS02 旧右桥脚与 DS03 的对照。 |
| `checks/ruins_float_joint_up_down_2x.png` | 桥静止复核 A/B（沿用旧上/下浮时刻 7.125 / 2.375 s），两桥 `dyRendered=0`。 |
| `checks/bridge_static_times_4x.png` | 0/12/26.683/64.47 s 的左右桥脚实际帧，桥体不透明像素固定。 |
| `checks/ruins_alpha_gaps_10x.png` | 右岛/桥、G3/桥的实际最小空气间隙（G5/G2 4.5 px，G3/G1 4.5 px）。 |
| `checks/pier_joint_extreme_8x.png` | t=64.47 桥脚云遮挡：桥底固定 300，云顶 282/278，重叠 18/22 px。 |
| `checks/sea_seam_three_1x.png` | 主/近云海接缝前/中/后（红=主，黄=近）。 |
| `checks/sky_wrap_3panel.png` | 天空云出画/左侧换边。 |
| `checks/shadows_height_context_4x.png` | 浮石高位/低位投影的变淡、右下退和接触收回。 |
| `checks/rock_filter_8x.png` | `rock_remnants_static` 的 5 px 旧影/附属屑运行时过滤证据。 |

`checks/frames/` 保存本次真实浏览器抓取的 1280×720 原始帧（供逐项复核）；`checks/*.png` 是压缩后的对照拼图。

控件：暂停/继续、重置、时间滑杆、海面接缝前/后、接缝标记、天空云换边、桥静止检查 A/B、桥脚云遮挡、右岛/桥间隙、G3/桥间隙、关云检查、隐藏控件。URL 支持：

```text
?t=8&pause=1&ui=0&seams=1
?t=64.47&pause=1&ui=0
?mode=noclouds|seaonly|skyonly|groupsonly|baseonly|rockonly
?skip=seaMain,seaNear&selftest=1
```

`mode` / `skip` / `selftest` 是审核与自动检查入口，不是游戏功能。

## 2. 图层与运动

绘制顺序（实现与 `runtime_config.json` 的 `stack` 一致）：

```text
base_sky depth 0
DS02 7 张天空云 depth 10
G3/G4/G5 远建筑 depth 20
G1/G2 两桥整体 depth 30   ← 同在 sea_main 之前
sea_main + shadow_central/cluster depth 40
arch_stone depth 45
sea_near + shadow_low depth 50
rock_remnants_static depth 60
DS02 4 组游离浮石 depth 70
```

- **没有任何旧 overlay 回盖分支**：不使用 `base_static`、`island_overlay`、`arch_overlay`；右桥不是“下部单独 overlay”，两桥都是完整单体，在同一主云海之前绘制。
- 逻辑 640×360，Nearest，2× device 画布（1280×720），位置量化到 0.5 逻辑 px。**这仍不是 Godot 原生 640 实机**。
- 天空云全部 +x；云海相位 `phase=(speed*t)%P`，纹理列 `u` 画在 `x=u+phase`，左周期副本在 `phase-P`，云顶取 `top[(world_x-phase)%P]`。没有用 `-phase` 画出反向运动。
- 5 组建筑各是一张整图、一次 drawImage，不拆柱梁/基础：
  - **G1/G2 两座完整大桥绝对静止**：`float.enabled=false`，`groupPlacement` 在任何 `force` / `worst` 分支之前直接返回原 `offset`，不使用旋转/缩放/移位；柱、梁、桥板、墩、拱全部保持原位置。暂停/继续、重置、跳时、`force=up|down`、`worst=bridge|island` 都不会改变它们。
  - G3 0.35 px / 18 s、G4 0.30 px / 22 s、G5 0.45 px / 20 s，保留原错相；
  - 公式 `dy = amp*sin(2π(t+phase)/period)`；2× device 画布 + 0.5 逻辑 px 量化后，三组实际显示只取 `-0.5 / 0 / +0.5`，**最大绝对偏移 0.5 逻辑 px**（1 device px；峰峰值最多 1.0 逻辑 px）。并非三个组的实际峰值都下降：G4 旧 0.6 公式峰本来也量化到 0.5，实际峰值可能同为 0.5，但周期更长、公式幅度更小，整体更安静。
- `art_manifest.json` 的 `amp_max_px`（桥 1.5/1.0、远建筑 0.8/0.6/1.5）是**旧美术资产的允许上限**，不是本轮现行运动值。现行规则以 `runtime_config.json` 的 `groups[].float` 为准：G1/G2 关闭，G3/G4/G5 使用 0.35/0.30/0.45 与 18/22/20 s。`art_checks/` 里旧的桥上浮截图只是旧资产/旧版记录，不代表当前效果。
- G1/G2 的 PNG 保留到 y=299（end 300），y283–299 是浮动 reserve；不是把桥固定来遮缝。两桥现在固定在原 offset，桥底可见到 300；t=64.47 时 G1 脚云顶 282、重叠 18，G2 脚云顶 278、重叠 22，石面到云之间 base sky 像素 0。
- `rock_remnants_static` 在运行时过滤 local `(41,155)-(45,157)` 的 5 px 小斑（低浮石下方旧影/附属屑）。原 PNG 未改，其余石屑保留。

## 3. 复现

只用 `D:\minic\envs\2024212971\python.exe`：

```bat
cd /d "D:\godot game\星核旅人\自制素材\云海遗迹背景动态修复_DS03"
"D:\minic\envs\2024212971\python.exe" build_runtime.py
"D:\minic\envs\2024212971\python.exe" build_standalone.py
"D:\minic\envs\2024212971\python.exe" capture_checks.py
"D:\minic\envs\2024212971\python.exe" verify_hashes.py
```

或：

```bat
"D:\minic\envs\2024212971\python.exe" reproduce.py
```

只重建配置/单文件（不跑浏览器检查）：

```bat
"D:\minic\envs\2024212971\python.exe" reproduce.py --skip-browser
```

`build_runtime.py` 会从 DS02 `layers/` 字节复制 16 张公共动态资源到 `common/`，校验 108 项基线与 8 个美术层哈希，再写 `runtime_config.json` / `config.js`。`build_standalone.py` 按配置自动收集全部资源（本轮 24 张），**不硬编码 19**。`capture_checks.py` 用本机 Chrome headless 以真实 `file://` 打开单文件，另开临时 localhost 仅做分文件/单文件对齐，结束后关闭服务器和 headless 浏览器；交付不需要服务器。

## 4. 实际校验（浏览器真实 Canvas，不是只测 Python）

| 项 | 结果 |
|---|---|
| A. 云覆盖桥脚 | 左/右 ROI × t=0/4/8/12/30/60/58.922/59.722/60.522 共 18 组；逐 device 像素与当前 `sea_main` 纹理比较，**0 不一致**；与 `seaonly` 合成也 0 不一致。每次比较 2,036–8,284 个 device 像素。 |
| A. 旧静止云 | 运行时无旧 overlay；关闭动态云后的右桥脚 ROI 对 8 色云海调色板命中 **0**；G1–G5 建筑层云色调色板命中 **0**；截图见 `right_foot_cloud_off_vs_on_4x.png`。 |
| B. 桥绝对静止 | `groupsonly` 实际帧 19 张（0/2.375/7.125/12/26.683/34.74/50/60/64.47 s，暂停→继续→暂停、重置、跳 12 s、`force=up/down`、`worst=bridge/island`）：G1/G2 不透明像素逐像素差 **0**，源 RGB 差 **0**，`dyRendered` 全部 **0**；桥底固定 **300**，delta **0**。 |
| B. 小遗迹轻浮 | 10 个实际帧：G3/G4/G5 均出现 `-0.5/0/+0.5`，最大绝对偏移 **0.5 px**，每组至少 3 个不同位置；实测零交叉周期 **18/22/20 s**（不是只改标签）。G4 旧实际峰值本来也是 0.5，本轮不声称三者峰值都下降。 |
| B. 间隙/桥脚 | G5/G2 实际最小 **4.5 px**（源 alpha 静态 5.0），G3/G1 实际最小 **4.5 px**（静态 5.0），均无接触；桥脚联合 t=64.47：G1 云顶 282、桥底 300、重叠 18，G2 278/300、重叠 22；石面到云之间 base sky 像素 **0**。 |
| C. 实际向右 | 实际合成帧相关位移：天空 +99/+149 device px（0→8/12 s，目标 49.6/74.4 逻辑），主海 +67/+101（目标 33.6/50.4），近海 +115/+173（目标 57.6/86.4）。主/近各自跨完整周期 t=304.2857 / 177.5 的最大通道差 **0**。 |
| C. 接缝/换边/投影 | 两层接缝标记同框（主 247.5→254.2，近 424→435.8）；天空右云带在不可见区换边。投影高位 alpha 0.70/0.88、右下位移、尺寸增加，低位收回；见 `shadows_report.json`。 |
| D. 单文件 file:// | `protocol=file:`，24/24 内嵌，`failed=[]`，`errors=[]`，`externalRequests=[]`，无外部 script/link；暂停/继续、重置、播放、接缝、桥静止检查、关云、隐藏控件均实测。 |
| D. 对齐/可移植 | 分文件 HTTP t=0/8 与单文件**逐像素相等**；分文件 `file://` 也逐像素相等；复制到空目录打开 t=8 也逐像素相等。base64 逐张解码均为 PNG 且哈希等于源文件。 |
| 保护 | 108/108 基线、8/8 美术层、16/16 公共图字节复制；24/24 PNG 哈希与本轮 runtime 基线一致；runtime 配置的 base/static/sky/sea/shadows/debris/stack 逐项相等，groups 除 `float` 外相等；运行时代码引用 24 个资源，无旧层。 |
| 冻结范围 | 未改云/云海/游离浮石/投影/遮挡规则，未改 PNG、`art_manifest.json`、Godot 或其他页面；仅 runtime 生成器、配置、必要 JS 守卫、检查控件说明与验证脚本。 |

详细数字在：

- `checks/cloud_occlusion_report.json`
- `checks/direction_report.json`
- `checks/float_gap_report.json`
- `checks/motion_adjustment_report.json`（本轮动效调整的紧凑证据）
- `checks/shadows_report.json`
- `checks/integrity_report.json`
- `checks/browser_selftest.json`
- `checks/build_runtime_report.json`
- `checks/standalone_build_report.json`
- `checks/final_hashes_check.json`
- `checks/summary.json`

## 5. 已知边界

- 不是 Godot 原生 640 实机；这是浏览器 2× device / 0.5 逻辑像素量化预览。未接引擎、菜单、摄像机、玩法、人物或前景。
- `art_manifest.json` 的 `amp_max_px` 是旧资产允许上限；本轮现行运动只看 `runtime_config.json`。`art_checks/` 内的旧桥浮动/极值截图属于旧版记录，不是当前效果。
- G4 旧 0.6 公式峰在 0.5 量化下本来就会显示 0.5 px；本轮它同样最大 0.5 px，但周期从 12 s 放慢到 22 s、公式幅度降到 0.30，观感更安静，不声称实际峰值下降。
- 桥静止检查覆盖正常播放/暂停恢复/重置/跳时/`force`/`worst`；未做长时间人眼连续观看录像和实机性能测试。
- 间隙验证改为直接使用各组的源 alpha 与当帧 `dyRendered`，避免旧启发式把上层建筑自身的小片段误当成层间间隙；本轮 G5/G2、G3/G1 最紧均为 4.5 px。
- 云海纹理是 DS02 的 1278 px 真周期（含镜像重复），长看会看到对称重复；这是已知取舍，不是接缝跳变。
- 右桥脚在 t=0 的静态外观沿用 V2；此前 DS03 的修复是动态遮挡关系（两桥同在主云海之前），本轮只调运动，不重画右桥/云。
- G5 岛底 x474–482 的 1 px 浅色片段沿用 V2 柱头像素，未擅自改暗；属于美术已认可轮廓的边界。
- `rock_remnants_static` 只过滤 5 px 可疑小斑；其余静态石屑保留。该过滤在运行时代码中完成，不改 `art_assets`。
- 所有新图/检查图来自真实浏览器画布；美术层仍以 `art_manifest.json` 的 8 个哈希为准。
