# 桥头石造地面 v1 · 正式 source

状态：**正式 source 素材与离线构建接口**。工程读取本目录并在 `assets/bridge_stone_v1/generated/` 生成最终 PNG；本目录不写 `generated/`，不改正式 `scenes/`、`scripts/`、`docs/`、`progress/`、credits、`project.godot`。旧 `previews/bridge_ground_sample_20261113/` 只读保留。

## 文件

- `atlas.png` 640×320：透明材质/结构模块；`atlas_manifest.json` 给出每个 rect、用途、连接/裁切方式。
- `build_block.py`：固定 CLI，离线生成任意给定尺寸的整像素地形。
- `examples/`：通过 CLI 生成的样张（高台、长地基、薄/厚梁、支承、断端、最小尺寸）。
- `contact_sheet.png`：正式素材与结构暗部总览；**不是实机截图**。
- `../columns/`（与 source 同级）：三张方形平底柱脚（同名复制自已确认的样板派生图）。
- `source_manifest.json`：文件 hash、来源、检查范围、已知局限。
- `generate_atlas.py` / `build_examples.py` / `generate_contact_sheet.py` / `generate_manifest.py` / `validate_outputs.py`。

Python 固定：`D:\minic\envs\2024212971\python.exe`

## 构建接口（工程直接用）

```powershell
D:\minic\envs\2024212971\python.exe build_block.py `
  --width 336 --height 144 --kind ground `
  --left solid --right broken `
  --output "D:\...\generated\high_336x144.png"
```

- `--kind ground`：宽 ≥32、高 ≥32。12 px 路面 + 2 px 檐下阴影 + 20 px 级承重层 + 10 px 底缘；336×144 / 512×64 / 640×40（现二关）/ 1024×64 均为原生组合。
- `--kind deck`：宽 ≥8、高 6–24。连续承重石梁；6 px 高不是 15 px 路面压缩，原生有顶面/梁身/暗梁底；24 px 高有更深的下部暗面。现二关的 16×6、8×6 梁和 56×14 高台踏步可直接生成。
- `--kind pier`：宽 ≥8、高 ≥24。竖向支承；8 px 宽用 8 px 鼓石模块，顶部帽石、底部基座；宽支承由构建器用同色系连续侧边，不横拉石沿。
- `--left/--right solid|broken`：断端只在最上行走带之下做 1–4 px（ground）/1–2 px（deck）/1 px（pier）退让；**最上行始终满宽**，无内部空洞、无假台阶。
- 输出 RGBA PNG，**恰为 W×H**，1 source px = 1 world unit；不缩放、不旋转、不镜像。
- 不给随机种子、不暴露大量美术参数；构建器内部用固定错缝序列与有限色阶。

## 结构暗部

- 路面：TOP/TOPHI 顶面 + LIGHT/LIGHT2 前脸，亮但不过白；檐下是 2 px 实色 DEEP+DARK 窄阴影，不是透明黑罩。
- 承重体：按深度使用离散石阶 `MID2 → MID → MIDD → BEAR → BEAR2`，层内夹少量 LIGHT/LIT 受光石块，避免“顶到底同亮灰墙”，也避免纯渐变。
- 底缘：BEAR2/BEAR 底缘 + DEEP 接地行；承重层与底缘之间有暗缝。
- 梁：上部受光面、1 px 阴影缝、下部较暗梁身、2–3 px 梁底；路线顶边仍易辨。
- 支承：左亮右暗，横向鼓石缝；背部/底座比行走面暗。
- 断端：断口内芯用 MID2/MID/MIDD/BEAR 角石 + DEEP 主裂 + 少量 LIGHT 反光面；不是一条深色贴条。atlas 的 24×40 断口内芯用于地面；梁/支承高度跨度大，由构建器用同色系角石+裂缝绘制，避免把断口拉伸。
- 没有全局 modulate、没有线性透明黑蒙版；所有暗部都是实色石面/灰缝/梁底/断口像素。

## 柱脚

`../columns/doric_column_{tall,broken,base}_basesquare.png`：
- 只改底部 9 行：高柱 **99–107**、断柱 **73–81**、柱座 **15–23**。
- 34 px 宽（x9..42）方形平底；2 行收分帽、前立面、底倒角、水平接地行；接地行 DEEP/DARK，不是黑线。
- 画布、`foot_anchor`、上部像素逐像素保持；`fallen` 未动。工程替换现有 `doric_column` 贴图即可，offset 不变。

## 检查 / 局限

- 已看 1× 高台/长地基、2× 高台明暗与断端、4×/8× 梁与支承、6× 柱脚底；`validate_outputs.py` 通过（顶行满宽、无内部空洞、最小/最大尺寸、atlas 无重叠、柱脚上部未变）。
- 断端是保守的“剪切/啃缺”边，不是大段崩落；要更重的废墟感需另开损伤设计。
- 高台左端 world 864、远岸右端 1952 在固定 L1 机位外；若镜头或关卡延伸后需要连续石面，请用同一 CLI 为相邻块生成同尺寸 PNG，不要把 336/496 样张拉伸。
- 协调者校正：此前把远岸左侧的深色形状误认为旧地形楔块；正式地形绘制不越过其碰撞矩形，该处所见遗构属于DS03背景，不应为消除它而隐藏或修改背景。本轮工程保留DS03原规则。
- 宽支承（>8 px）的连续侧边由构建器代码绘制，不在 atlas 里拉伸；8 px 支承完全由 atlas 模块组成。
- 未在 Godot 内摆放/运行；columns 的 `.import` 侧车由打开的项目编辑器自动生成，未改任何场景/脚本。Nearest、z 顺序、相机停位、断端边缘落脚未实机验证。DS03 背景与人物未动。
