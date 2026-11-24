# LuizMelo Wizard Pack — 来源与许可记录

记录日期：2026-11-12。仅保留原 ZIP、实际使用的 `Idle.png` 与本说明；没有把包内 8 组动画复制进项目，也没有把作者页面截图当运行素材。

## 文件与校验

| 文件 | 大小 | SHA-256 |
| --- | --- | --- |
| `Wizard Pack.zip` | 69,998 bytes | `41167557a3401e7156b6557cfec932457d333059c6f6393bf958b6b4fe3a2291` |
| `Idle.png` | 1,386 × 190 px | `e1583fa16cca3ebac9c7d560dca0eb351ff8720d0ee592ec4876ef5f704b51f1` |

来源页面：<https://luizmelo.itch.io/wizard-pack>（作者 LuizMelo / itch.io）。

## 作者许可原文

来源页正文（2026-11-12 实际读取）：

> This package can be used freely and commercially - CC0(creative commons zero). Credits are not required but I would appreciate it.

因此按 CC0 使用；署名非强制，但项目在预览 README 与 manifest 中保留了来源与作者信息。没有购买、没有拆取作者页面预览图、没有把参考站点截图当素材。

## 实际规格（以文件实测为准）

- 页面动画清单仍写 `Idle - 4 frames`，但实际下载的 `Idle.png` 为 **1386 × 190**，按 **231 × 190 × 6 格** 连续排列；**不能按 190 宽切帧**。
- 作者在页面评论中确认单格尺寸为 231 × 190 像素。
- 六格实体包围盒完全一致：`x 82..138, y 55..140`（Python bbox 半开区间 `(82, 55, 139, 141)`），即 **57 × 86**。
- 本轮只取 `Idle.png` 的 6 帧，离线 NEAREST 50% 取样为 **29 × 43**，放入 **48 × 64** 画布，脚底锚点 **(24, 60)**，导出 **288 × 64** 的 `watcher_echo_idle_6f.png`。
- 取样相位为 `x=0, y=1`：保留手杖与面部/白须轮廓；此相位保留一只绿色眼睛。没有重画脸、没有改色、没有整身 alpha。
- 灵体处理仅限下摆最后 4 行的透明度过渡（约 26%–92%，含逐帧微调）与下缘 1 px 轮廓的极轻微逐帧明灭；主体保持不透明。

## 使用边界

本素材仅用于 `previews/art_reference_20261112/` 的隔离对照样张，**不是正式第一关的美术替换**，也不代表用户已认可。是否推广到正式关需用户看图后决定。
