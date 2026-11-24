# 星核旅人 · 星核三态素材（锁定原紫 / 正极金 / 负极青，静帧 + 12 帧）

本目录是“星核三态”资产的完整交付：从 Frakassets 的 16px、正面（0d）、12 帧彩色表生成三态静帧和三态 12 帧表。

- 既有 16×16 静帧文件保留原路径和原 RGBA；新增三张 192×16（12×16×16）透明帧表。
- 锁定 12 帧表直接复制源表，12 帧 RGBA 与源表逐像素一致；正/负表按既有 HSV 方法逐帧调色。
- alpha、每帧 16×16 画布和帧位置完全不变；不读取 `_normal` 法线图，不放大到 32px。
- 组件默认 12 FPS 循环；显示尺寸固定 16×16，薄边帧不改变本体/碰撞尺度。
- 已在本机 Godot 4.7.2 导入、挂载和运行验证；截图与测试见下文。
- 只读取源表，未修改原图；源表生成前后 SHA256 一致。

## 文件

工程内（组件依赖的确切文件名）：

| 文件 | 规格 | 不透明像素 | 用途 |
| --- | --- | --- | --- |
| `基础场景原型/assets/star_core/star_core_locked.png` | 16×16 RGBA | 208 | 旧静帧兼容；源第 0 帧逐像素原样 |
| `基础场景原型/assets/star_core/star_core_positive.png` | 16×16 RGBA | 208 | 旧静帧兼容；正极金色 |
| `基础场景原型/assets/star_core/star_core_negative.png` | 16×16 RGBA | 208 | 旧静帧兼容；负极青色 |
| `基础场景原型/assets/star_core/star_core_locked_12f.png` | 192×16 RGBA | 逐帧 `[208,196,176,144,100,68,48,68,100,144,176,196]` | 仓内锁定原紫 12 帧 |
| `基础场景原型/assets/star_core/star_core_positive_12f.png` | 192×16 RGBA | 同上 | 仓外正极金 12 帧 |
| `基础场景原型/assets/star_core/star_core_negative_12f.png` | 192×16 RGBA | 同上 | 仓外负极青 12 帧 |

本目录（审核、复现、机器可读信息）：

| 文件 | 说明 |
| --- | --- |
| `star_core_locked.png` / `star_core_positive.png` / `star_core_negative.png` | 工程三张静帧的逐字节备份 |
| `star_core_locked_12f.png` / `star_core_positive_12f.png` / `star_core_negative_12f.png` | 工程三张 12 帧表的逐字节备份 |
| `star_core_states_preview.png` | 三态静帧 14× NEAREST 对比预览；RGB 合成图，不是引擎截图 |
| `star_core_animation_sheet_preview.png` | 三态 × 12 帧的本地 NEAREST 素材检查图；不是引擎截图 |
| `manifest.json` | 源信息、逐帧 alpha / bbox / 不透明像素、调色参数、SHA256、自检结果 |
| `generate_star_core_states.py` | 生成脚本；重跑会覆盖工程六张 PNG、本目录备份、两张预览和 manifest，不会改动源图 |

## 选帧与动画

- 源表：`素材库/古遗迹候选/03_star_core_gem/extracted/free_gem_round_frakassets/gem_round_16x16_12f_0d.png`，192×16，12 帧 ×16×16。
- 只使用 **16px、0d 正面、彩色**表；未使用 20d、32px、`_normal.png`（法线图不是颜色图）。
- 12 帧不透明像素数：`[208, 196, 176, 144, 100, 68, 48, 68, 100, 144, 176, 196]`。
- 旧静帧取第 0 帧（208 个不透明像素，正面面积最大），RGBA 未改。
- 锁定 12 帧表是源表逐字节复制；正/负表逐帧套用与静帧相同的 HSV 调色，逐帧 alpha、bbox、不透明像素数与源表一致。
- 源表第 6 帧最薄（48 px，约 6×8 的可见剪影）；组件仍以 16×16 整格显示，不缩放、不裁切、不改变碰撞/本体。
- 第 0 帧四边各有 6 个不透明像素；这是源帧本身，摆放时不要额外裁掉 1px。

## 调色方法

源帧由 **5 级中性暗轮廓** + **11 级紫色宝石色**（色相约 291°）组成。调色只改 HSV 色相/饱和度/明度并轻微染色暗轮廓，alpha 完全不动，因此三态轮廓、非透明像素数、暗轮廓位置逐像素一致。

| 参数 | 正极金 | 负极青 |
| --- | --- | --- |
| 目标色相 | 43° | 186° |
| 饱和度重映射 | `s^0.62 × 1.15`，下限 0.22 | `s^0.62 × 1.12`，下限 0.20 |
| 明度 | 源值 ×0.98 | 源值 ×0.96 |
| 暗轮廓 | 45% 混入 `(72,41,17)` | 45% 混入 `(9,43,53)` |
| 参考护符亮色 | `#f4cd63` | `#5fe1e6` |

## 自测结果（本次实际运行）

Python 生成器从磁盘重新读取六张导出 PNG 后检查：

- [x] 源表生成前后 SHA256 一致，原图未被改写。
- [x] 三张静帧仍为 `16×16` RGBA；三张动画表为 `192×16` RGBA、12 帧。
- [x] 静帧 alpha 逐字节一致；动画表 12 帧 alpha 在三态之间逐字节一致。
- [x] 动画表逐帧 bbox 与不透明像素数三态一致；逐帧数量与源表旋转一致。
- [x] 锁定动画表 SHA256 与源表相同（`1a7f8bfc…e63f4c`），12 帧 RGBA 与源表一致。
- [x] 静帧第 0 帧与对应动画表第 0 帧逐像素一致。
- [x] 每帧 alpha 只有 `0/255`，无半透明边；12 帧都有可见像素。
- [x] 平均色相：锁定 **291.07°**、正极 **42.96°**、负极 **185.99°**。
- [x] 正/负各保留 **11/11** 个宝石明暗层，暗轮廓仍为 44 px。
- [x] 动画表未读取 `_normal`，未放大画布。

Godot 4.7.2 引擎验证：

- [x] `tests/test_star_core_animation.*`：81 通过 / 0 失败 / 0 跳过。
- [x] `tests/test_star_core_visual.*`：102 通过 / 0 失败 / 0 跳过。
- [x] `tests/test_star_core_bay_visual.*`：151 通过 / 0 失败 / 0 跳过（动画兼容）。
- [x] 12 帧循环、逐帧 16×16、1:1 NEAREST、无镜像/旋转；暂停冻结；状态切换立即回第 0 帧；`refresh()` 不重启循环。
- [x] 仓内 LOCKED 紫色仍播放；仓外正/负播放；被动隐藏再显示、重新激活回第 0 帧。
- [x] 引擎预览截图：`基础场景原型/screenshots/star_core_visual_preview.png`（三态 1×/4×，定帧 3）、`star_core_animation_keyframes.png`（三态 × 0/3/6/9 帧）。
- 两张图都是 **固定帧的引擎视口静帧**，不是连续播放录像，也不是人工试玩。

## SHA256

源表：

```text
1a7f8bfcb6f2c770b07002aad2d3419108971e731363297ee424fce975e63f4c  gem_round_16x16_12f_0d.png
4b95b9325ae53fb8d9277695ce5fef7209e77c17cfc5df7df5423fefcc3c1449  第 0 帧 RGBA（未编码像素）
```

导出 PNG（工程文件与本目录备份字节相同）：

```text
40a36f519bc495f217d88c96c04f0a4503da9be15de75198a4b3da2844ad557a  star_core_locked.png
9a72e93bc6de4effaa297191248fd5428d97500d5fb241d9e440be67d7082266  star_core_positive.png
b21b819251b1f067e0dc16000dd8ede83d1a71281208216f9c7d644f42ada216  star_core_negative.png
1a7f8bfcb6f2c770b07002aad2d3419108971e731363297ee424fce975e63f4c  star_core_locked_12f.png
282e668fa72ed504abcbe6aebb9bfadfdb398de4e1796109540d15c4e6d4fa23  star_core_positive_12f.png
e99fab67c35cdc9cc9a1bf9ec70d92340105341fb82b286237146a70b0c09b23  star_core_negative_12f.png
```

`manifest.json` 还记录每张表的逐帧 alpha SHA256、bbox、不透明像素数和全部明暗映射。

## Godot 4 接入备注

- 组件：`基础场景原型/scripts/star_core_visual.gd`、`scenes/star_core_visual.tscn`。
- 默认读取 `res://assets/star_core/*_12f.png`；旧静帧路径保留为缺表时的静态回退。
- 每帧通过 `AtlasTexture` 显示 16×16，`Sprite2D` 保持 `scale = 1`、Nearest、居中；不改变碰撞或本体。
- 默认 `animation_fps = 12`，可在 Inspector 调整（1～60 FPS）；`animate` 可关闭自动播放。
- `state` 切换、重新变为可见、`reset_animation()` 都会回第 0 帧；`refresh()` 只重查素材，不重启循环。
- 房间 R/重置若通过隐藏/重新显示核心恢复仓内状态，会自动回第 0 帧；若某个调用方保持同一可见实例，可显式调用 `reset_animation()`。
- 暂停时 `_process` 不推进帧，恢复后从原帧继续；`refresh()` 兼容旧外部调用，逐帧调用不会卡在第 0 帧。
- 正/负/锁符号由组件 `_draw` 叠加，位于 16×16 外右下角，不随帧旋转或镜像；仓内组件关闭角标，仅保留仓体自己的锁标记。
- 仓内锁定只是不参与力场；紫色星核仍播放动画。

## 许可与署名

源素材：**Free Shiny Gem "Round" by Frakassets**，CC BY 4.0。

- 来源页：https://frakassets.itch.io/free-shiny-gem-round
- 许可：https://creativecommons.org/licenses/by/4.0/
- 建议署名文本：`Free Shiny Gem "Round" by Frakassets, CC BY 4.0, https://frakassets.itch.io/free-shiny-gem-round`
- 本项目修改：从 16px / 0d / 12 帧表中取第 0 帧作静帧；复制完整 12 帧表作锁定态；正/负静帧与 12 帧表调色为金/青；暗轮廓轻微染色。作者未参与本项目，也未对本修改背书。
- 六张派生 PNG 沿用 CC BY 4.0；对外发布时保留上述署名、许可链接和修改说明。本目录不包含原始 zip 包，也未重新授权其他项目素材。
- 预览图是内部评审合成图，除星核外还叠加了项目自制护符图标；护符不随本包按 CC BY 4.0 重新授权，预览不作为可分发素材。
- `ASSET_CREDITS.md` / 根 README 等汇总文档由协调者更新，本任务未直接修改。

## 重新生成

环境固定为项目 Conda Python：

```powershell
D:\minic\envs\2024212971\python.exe "D:\godot game\星核旅人\自制素材\星核三态\generate_star_core_states.py"
```

脚本只读取源表和护符参考图；写入工程 `assets/star_core/` 的六个确切文件名、本目录六张备份、两张预览与 `manifest.json`。不会删除目录内其他文件，不会改源表，不会提交 Git。若调整 `POSITIVE` / `NEGATIVE` 参数，请重跑并同步本 README 的自测数值；机器可读结果以 `manifest.json` 为准。

## 未完成 / 边界

- 未制作 GIF 或连续录像；引擎关键帧是固定帧静帧，连续循环由自动测试和实际运行覆盖，不代表人工试玩手感。
- 未验证异机、非整数缩放、4K、复杂地形/粒子背景下的实际可读性。
- 动画是 16px 原表的旋转，不是手绘逐帧；最终辨识度仍需创作者在实际关卡中确认。
- 未修改正式关卡、交互逻辑、HUD 或 `ASSET_CREDITS.md`。
