# 云海遗迹背景动态重制 DS02

状态：**可审阅试作 / 未接入 Godot、菜单、摄像机或玩法**。只读 V7、DS01 与工程文件；全部新输出在本目录。作者：DeepSeek V4.1 Flash 1017（2 号美工）。

## 1. 先看什么

- `reference.png`：640×360 逻辑像素、t=0 静帧；`reference_2x.png` 为 2× 最近邻。
- `preview.html`：连续 `requestAnimationFrame` 预览；支持暂停/继续、时间滑杆、接缝跳时和接缝标记。不是 GIF。
- `checks/flow_0_8_12.png`：0/8/12 秒整帧接触表。
- `checks/flow_direction_probe.png`：在**实际合成帧**上追踪云顶轮廓，标出 0/8/12 秒的特征位置；`flow_direction_report.json` 是同一测量的数字版。
- `checks/browser_2x_t0/t8/t12.jpg`：1280×720 浏览器画布抓帧；`checks/browser_direction_check.json` 是从这些像素测出的位移，不是 `speed*t`。
- `checks/seam_render_check.json`、`checks/seam_main_*_closeup.png`、`checks/seam_near_*_closeup.png`：主/近云海在可见接缝前后的实际渲染；`checks/seam_before/after_marker.png` 同时标出两层接缝。
- `checks/shadow_central_3heights.png`、`shadow_low_3heights.png`：低位/中位/高位与投影，带实际 `dy/a/grow`；`checks/shadow_context_8s.png` 是 8 秒同框的中央石+低石。
- `checks/time_trajectory.json`：0–24 s 的 phase、接缝 x、岩石高度、影位置/尺寸/强度。
- `checks/motion_audit.json`、`checks/seam_texture_check.json`、`checks/protected_hashes_check.json`：紧凑审计，不是成百条 PASS。

预览：

```bat
cd /d "D:\godot game\星核旅人\自制素材\云海遗迹背景动态重制_DS02"
"D:\minic\envs\2024212971\python.exe" -m http.server 8765 --bind 127.0.0.1
```

打开 `http://127.0.0.1:8765/preview.html`。可加 `?t=8&pause=1&seams=1&ui=0` 直接定位/隐藏控件。页面只显示纯背景，无人物、游戏 UI 或前景。

**离线单文件（无需服务器，推荐直接双击）**：`双击预览_DS02.html` 已把 CSS、配置、渲染脚本和运行时会用到的全部 19 张 PNG（含 `base_static.png`）内联为 `data:image/png;base64`。直接双击用浏览器打开即可，不需要 Python、localhost、网络或同目录文件；可单独复制该 HTML 到别处打开。暂停/继续、重置、时间滑杆、接缝前/后、接缝标记、天空云换边、隐藏控件以及 `?t=8&pause=1&seams=1&ui=0` 参数均与 `preview.html` 一致。重新生成：`"D:\minic\envs\2024212971\python.exe" build_standalone.py`（只读源文件，不改预览、配置或图层）。

## 2. 图层与叠放

| 顺序 | 文件 | 尺寸 | 初始 offset | 说明 |
|---|---|---|---|---|
| 0 | `layers/base_static.png` | 640×360 | 0,0 | 天空、桥/柱、左右岛与院落、静态残拱；已清掉旧云海/旧影小斑 |
| 1 | `layers/sky_bank_left.png` | 287×49 | −56,56 | V7 左大云带；左侧 56 px 是新增画外云尾 |
| 2 | `layers/sky_bank_right.png` | 320×45 | 376,43 | V7 右大云带；右侧 56 px 是新增画外云尾 |
| 3 | `layers/sky_mid_wisp.png` | 131×32 | 243,65 | V7 中层小云 |
| 4 | `layers/sky_low_wisp_r.png` | 113×30 | 466,101 | V7 右下小云 |
| 5 | `layers/sky_left_wisp.png` | 82×27 | 91,106 | V7 左小小云 |
| 6 | `layers/sky_low_wisp_l.png` | 64×26 | 198,95 | V7 左下小云 |
| 7 | `layers/sky_high_chip.png` | 52×23 | 321,49 | V7 高处小云片 |
| 8 | `layers/sea_main.png` | 1278×360 | 0,0 | 远/中云海完整纹理；周期 1278 px |
| 9 | `layers/shadow_central.png`、`shadow_cluster.png` | 40×12、30×9 | 随石 | 主云海上的浮石投影；source-atop 裁剪 |
| 10 | `layers/arch_overlay.png` | 640×360 | 0,0 | 中央残拱/小残拱，画在远中云海之前、近云之后 |
| 11 | `layers/island_overlay.png` | 640×360 | 0,0 | 右侧浮岛本体与云底，避免被运动云海误吞 |
| 12 | `layers/sea_near.png` | 1278×360 | 0,0 | 近层浅色云海完整纹理；周期 1278 px |
| 13 | `layers/shadow_low.png` | 28×9 | 随石 | 近层上的低处浮石接触影 |
| 14 | `layers/debris_central/cluster/tiny/low.png` | 39×39 / 31×22 / 9×11 / 31×33 | 303,207 / 264,243 / 379,235 / 231,289 | 固定浮石源，仅上下浮动 |

尺寸、offset、速度和周期以 `config.json` / `manifest.json` 为准。

## 3. 运动规则（已修正实际方向）

- **相位约定**：`phase = (speed*t) mod P`；纹理列 `u` 画在屏幕 `x = u + phase`。因此 **phase 增加 = 整块云体向右（+x）**。
- **云海**：`sea_main` 4.2 px/s，`sea_near` 7.2 px/s，均 +x。绘制主副本于 `x=phase`、左侧周期副本于 `x=phase-P`；两层纹理本身是 1278 px 真周期，因此接缝处连续、没有整体回跳。
- **上一版缺陷**：旧 `drawSea/compose` 用 `x0=-phase`，phase 增加时云海实际左移；旧 audit 只检查 `speed*t` 为正，不能证明屏幕方向。本轮同时改了 JS 绘制、Python 合成、影的承接采样 `(world_x - phase)`、接缝标记位置、跳时按钮和检查图。
- **实际渲染证据**（不是只记录 speed*t）：
  - 640 静态合成：主海 0→8→12 s 顶边轮廓右移 **+34 / +50 px**（目标 33.6 / 50.4，整数像素量化）；近海 **+58 / +86 px**（目标 57.6 / 86.4）；左大云带 **+50 / +74 px**（目标 49.6 / 74.4）。
  - 1280×720 浏览器画布：主海 **+67 / +101 device px = 33.5 / 50.5 逻辑 px**；近海 **+115 / +173 device px = 57.5 / 86.5**；天空云 **+99 / +149 device px = 49.5 / 74.5**。同一时刻浏览器与 Python 合成的最佳对齐位移为 **0 device px**。详见 `checks/browser_direction_check.json`。
- **天空云**：全部 +x 单向。两个主云带 6.2 px/s，五个小云 3.6 px/s；整块云一起平移。完全出右边界后才重置到左侧画外，重置发生在不可见区。
- **浮石**：只做上下悬浮，不左右绕圈、不旋转、不缩放。中央 ±4 px / 7.5 s，左下组 ±2 px / 6.2 s，小屑 ±1 px / 5.4 s，低处 ±3.5 px / 8.5 s，相位错开。
- **时间采样**：HTML 用 `requestAnimationFrame` 和真实 dt；嵌入页面被节流时有 250 ms 静默降级绘制。预览画布 1280×720 device；逻辑构图 640×360。位移量化到 0.5 逻辑像素（2× 时 =1 device px），最近邻，无插值。静态 PNG 用整数逻辑像素，所以与 `speed*t` 可差 ≤0.5 px。

## 4. 云海周期与接缝

- `sea_main` 和 `sea_near` 都是 **1278 px 真周期纹理**：640 px V7 云海母本 + 638 px 同值水平镜像；镜像时去掉两端重复列。
- 不是整列拉伸、夹边复制或每 12 秒拉回。纹理首尾列相同、无透明内列（`seam_texture_check.json`）。
- **可见接缝 = x=phase**（phase≤640 时）。页面“海面接缝前/后”跳到 `t=58.92 / 60.52 s`，此时主海接缝约 x=247/254、近海约 x=424/436，两层标记同框；红线=主海，黄线=近海。
- 渲染级检查：接缝两侧列 `phase-1` 与 `phase` 的最大通道差 **0**；时钟跨 `P/s` 的 ±0.02 s 原始平均差 **0**；±0.25 s 时轮廓位移 2 px（主，预期 2.1）和 4 px（近，预期 3.6），轮廓 MAE **0**。见 `seam_render_check.json`。
- 镜像是真实周期的一部分，长看会看到云的左右对称重复；这是已知取舍，不是接缝跳变。

## 5. 云海明暗与浮石投影

- 云海的远/中/近色全部来自 V7 云海像素；两层各自是完整云体，明暗、轮廓和内部色带随纹理一起移动，没有按色值拆开滑动。
- 光照统一**左上**，投影落在石的右下。投影不是岩石剪影的缩小复制：取岩石最大连通块，压扁后做水平优先的各向异性柔化，抹掉尖刺和分离碎块，形成**接触足迹**；再用左上密、右下淡的 ramp 和 **5 档离散 alpha**（约 3%/6%/9%/13%/19% 的峰值比例）保持像素柔边，不糊成渐变。
- 中央影 40×12、峰值 0.19；左下组 30×9、0.16；低处接触影 28×9、0.30。低位/中位/高位：主海影高位 alpha ×0.70 并加 2×1 px，低位更实；低石高位 ×0.88，低位最实。实际值印在 `shadow_*_3heights.png` 的标签上。
- 影的 x 只由岩石 x、`dx` 和高度偏移决定，**不随海面 phase 平移**；影的 y 取屏幕 x 处云面 `top[(x - phase) mod P]`，随完整云体运动。`source-atop` 裁到可见云海，不会剪出透明洞，也不会把影带到石外。
- 低石是接触影：石升高时影向右下退、变淡，石降低时影收回、变实；影只做约 0.2× 水平 / 0.3× 垂直的反向高度位移，不会跟着石整块上浮。中央/左下组约 0.4× / 0.5×（均在 `motion_audit.json` 记录）。小屑投影角尺寸 <2 px、对比低于一档色，主动省略。
- `checks/shadow_context_8s.png` 是 8 秒同框，不是三张零差异静帧；`shadow_*_3heights.png` 用低位/中位/高位三个真实时间点显示差异。

## 6. 与 V7 的差异 / 变化区域

- `reference.png` 对 V7 640 逻辑像素：**5,932 / 230,400 像素不同（2.57%）**，差异 bbox 为 y234–341，集中在云海/接缝/投影。见 `diff_vs_v7.png`、`checks/diff_vs_v7_stats.json`、`diff_vs_v7_report.md`。
- **静态建筑在 y<250 的差异为 0**；桥、柱、院落、左右岛、残拱的可见上部没有被云带走。35 个保护文件 35/35 哈希未变。
- 变化只解释为：① 云海改为可周期运动的完整云体（近层顶是平滑深度模型，不完全逐像素复制 V7 的每个近带边）；② 中央拱/右岛底作为前景静态 overlay；③ 新增投影；④ 清掉旧云海/旧影小斑。

## 7. 已验证 / 未验证

已做：
- 生成器完整重跑；`reference.png` 与 V7 的建筑上部逐像素一致（y<250）；35 个保护文件未变。
- 本会话在 127.0.0.1:8765 同一时间只开 1 个自己的审核 tab（先后重开过），实际看了 t=0/8/12 的 1280×720 画布、暂停/继续（暂停保持 5.50 s，继续后到 66.22 s）、接缝前/后按钮（主 247.5→254.0、近 424.0→436.0，双标记同框）。没有动协调者 tab `browser:...-10`，也没有关闭任何他人 tab；自己的 tab 均已关闭。
- 对浏览器 2× 抓帧和 Python 合成做了同刻对齐：最佳位移 0 device px，平均差约 0.34–0.44/255（JPEG 与 0.5 px 边缘量化）。
- 读取最终 `reference_2x.png`、方向探针、接缝 closeup、影三档图和 8 s 同框图。

未做 / 不要当成已完成：
- 没有做人类式长时间连续观看录像；没有接入引擎做实机/摄像机/性能测试。
- 接缝条里仍有 1 px 的像素阶梯（正常像素云边缘），不是透明边或竖直断面；镜像是周期性重复，长看可见。
- 近层顶是模型化云带，低处石周围不是逐像素原始 V7 云；投影是风格化接触足迹，不是物理渲染。
- 静态 PNG 是整数逻辑像素；浏览器是 0.5 逻辑像素量化，因此数值会差 ≤0.5 px。没有用“参数单调”代替方向验证。
- 没有改 Godot 工程、菜单、摄像机、玩法；没有 Git 提交/清理。

## 8. 复现

```bat
cd /d "D:\godot game\星核旅人\自制素材\云海遗迹背景动态重制_DS02"
"D:\minic\envs\2024212971\python.exe" generate_ds02.py
```

脚本只读 `background_only_v7.png`、DS01 的固定层/浮石、V6 的纯桥几何和基线哈希；不执行 V6/V7 顶层写文件逻辑，不下载外部素材，不修改原图/工程。

## 9. 自制 / AI 辅助说明

拆层、云海周期纹理、投影、检查图和预览脚本由本会话生成，执行模型为 DeepSeek V4.1 Flash 1017。没有调用其他模型、付费服务、外部图库或网络素材；V7 原图与 DS01 层是项目已有素材，本试作不主张对其重新授权。
