# 2026-11-28 字体清晰度 / 2× 窗口 参考记录

任务：全项目可见 Label / RichTextLabel 的像素字体清晰度，以及 640×360 在 2× 窗口下的缩放行为。本轮没有新制美术风格，只核对引擎设置与项目既有像素规范；下列资料用于**技术判断**，不是画面风格参考。

## 实际打开的来源

| 来源 | 身份 | 实际观察 | 能借鉴 | 不能照搬 / 未核实 |
| --- | --- | --- | --- | --- |
| <https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html>（Godot 4.7 官方文档，2026-11-28 打开） | 引擎多分辨率/拉伸官方说明 | 像素游戏推荐 `viewport` + `keep` + **Stretch Scale Mode = integer**；640×360 在 1366×768 用 fractional 会得到 2.133× 的不均匀像素，integer 会降到 2× 并加黑边；“Font and image oversampling” 说明字体默认会在视口缩放变化时重栅格化。 | `window/stretch/scale_mode="integer"`；保持 640×360 基准；字体固定原生 12/24 px。 | 文档没有承诺 2× 窗口的最终 blit 一定最近邻（只说明 viewport 低分辨率渲染后拉伸）；本机 133% 桌面缩放下的系统截图不能作为 blit 过滤器的唯一证据。 |
| <https://github.com/godotengine/godot/issues/66527>（Godot issue，2026-11-28 打开） | 引擎 viewport 拉伸过滤讨论 | 维护者说明 root viewport 的 `viewport` 拉伸使用 nearest-neighbor；SubViewport 才默认 bilinear，需要单独覆盖。 | 说明 2× 的 root viewport 理论上不会因线性过滤发虚；排查重点转向桌面 DPI/窗口非整数倍。 | 这是 2022 年的 issue，未在 4.7.2 源码逐行复核；只作为方向，不作为“已修”证据。 |
| <https://docs.godotengine.org/en/stable/classes/class_fontfile.html>（Godot 4.7 FontFile 类文档，2026-11-28 打开） | `FontFile` 属性说明 | `antialiasing`、`hinting`、`subpixel_positioning`、`generate_mipmaps`、`oversampling` 都是字体级设置；`oversampling=0` 表示自动。 | 统一在一个 helper 里固定 AA/hinting/subpixel/mipmaps/oversampling，避免每个页面各写一份。 | 自动 oversampling 在本项目固定 640×360 视口下实测 0 与 1.0 都输出 2 色硬边（见下）；不能把“0.0”单独当作本机 2× 发虚的唯一原因。 |

## 本地实测（不是外部参考）

- 640×360 视口内，暂停页标题“已暂停”区域只有 4 种颜色；说明页正文区域只有 4 种颜色 → 字体本身无抗锯齿/次像素。
- 2× 窗口（1280×720）+ `window2x_probe`：`FontFile.oversampling=0.0` 与 `1.0` 两行 12/24 px 文本在 640×360 视口截图里都只有 2 种颜色（文字色 + 背景），没有任何中间色 → 两种设置在本机都不产生重采样。
- 同一窗口的桌面截图会出现中间色，来源是 Windows 桌面 133% 缩放把窗口合成到 2560×1600 面板；这是系统合成，不是游戏内字体。
- 官方文档的 fractional/integer 对比图说明：非整数窗口倍率才是“像素宽窄不一/看起来发虚”的确定来源；因此补 `scale_mode="integer"`。

## 借鉴边界

- 只采用“640×360 基准 + viewport + integer + 原生字体尺寸 + 关闭 AA/hinting/subpixel”这条技术路线。
- 不复制任何外部游戏的字体、像素、配色或 UI 版式。
- 未取得可播放的 2× 窗口录屏；2× 结论基于 640×360 视口截图、引擎文档/issue 与桌面截图对比。若在 100% DPI 的 1280×720 窗口仍看到发虚，需要再用真实窗口录屏复核。
