# 教程中文像素字体来源与使用说明

## 结论

- 字体：**Fusion Pixel 12px Prop zh-Hans**（Fusion Pixel Font / 缝合像素字体），作者 **TakWolf**。
- 许可：**SIL Open Font License 1.1（OFL-1.1）**。免费，无需注册、付款或额外接受协议。
- 项目文件：`assets/fonts/tutorial_zh.ttf`。由官方发布包内 `fusion-pixel-12px-proportional-zh_hans.ttf` **仅重命名**得到；字体二进制未修改、未子集化，内部 name 表保持原样。
- 版本：`2026.10.25`；访问/下载日期：`2026-10-31`。

## 来源

- 官方仓库：<https://github.com/TakWolf/fusion-pixel-font>
- 发布页：<https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25>
- 下载包：`fusion-pixel-font-12px-proportional-ttf-v2026.10.25.zip`
  <https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.10.25/fusion-pixel-font-12px-proportional-ttf-v2026.10.25.zip>
- 许可原文：<https://github.com/TakWolf/fusion-pixel-font/blob/master/LICENSE-OFL>
- 完整许可与上游声明：`assets/fonts/tutorial_font_LICENSE.txt`

## 校验值

| 项目 | 值 |
|---|---|
| 文件 | `assets/fonts/tutorial_zh.ttf` |
| 大小 | 7,295,572 bytes |
| SHA-256 | `58A0AC8784BFB0ED70B788A9CF815D00FCAD9DAA9E0517B8D1C244B4F912E3D6` |
| 内部字体名 | Fusion Pixel 12px Prop zh-Hans Regular |
| 内部版本 | 2026.10.25 |
| 许可（name ID 13/14） | OFL-1.1 / 官方 LICENSE-OFL 链接 |

## 字符覆盖（fontTools 实测）

- cmap 字符数：**38,130**；CJK 统一表意文字：**19,466 / 20,992（92.73%）**（与官方 12px 比例模式统计一致）。
- 教程/UI 常用汉字样本 194 字：**0 缺失**。
- 中文标点与全角符号（，。、；：？！“”‘’（）《》〈〉【】「」『』…—～·等）：**0 缺失**。
- 拉丁按键字形 `F Q E R A D Shift`（含大小写）：**0 缺失**。
- 正负/运算/方向符号 `+ - ± × ÷ → ← ↑ ↓`：**0 缺失**；数字 `0-9`：**0 缺失**。
- 已知未覆盖（本任务未要求）：`∞ ≈ ≠ ≤ ≥` 等部分数学符号；如最终文案使用，请先复查。
- 说明：以上为常用字样本验证；教程最终文案确定后，建议按实际字符串再跑一次覆盖检查。

## 原生字号与渲染

- 原生设计尺寸 **12px**；`unitsPerEm = 1200`，即 12px 下 100 units = 1px。
- 抽查字形轮廓坐标与字宽均为 100 units 的整数倍；12px 下对齐像素网格。汉字 advance 12px，`F` 7px，数字 6px。
- 行高：hhea ascent 1300 / descent -300，12px 下约 16px 行高。
- 640×360 逻辑分辨率下 12px 实测可读（已用 12px 无抗锯齿预览确认）。
- Godot 建议：`font_size` 使用 12 或整数倍（24/36）；字体导入关闭抗锯齿（Antialiasing = None）、Hinting = None、Subpixel Positioning = Disabled，避免像素字发虚。属于接入设置，本次未改任何场景或代码。

## 许可要点（OFL-1.1，已核实原文）

- 允许商业与非商业使用、研究、修改、嵌入，并可随游戏分发/销售。
- 不得单独出售字体本身；修改版必须继续以 OFL-1.1 分发，且不得使用 Reserved Font Name（本字体版权声明处未另行声明 RFN）。
- 随字体保留版权声明与许可证文本；OFL 不强制游戏内署名，但建议在 credits 标注 “Fusion Pixel Font by TakWolf, OFL-1.1”。
- 本字体**不是 CC0**，也**不是**微软雅黑或任何 Windows 系统字体的副本；未从系统字体目录复制任何文件。

## 准备与修改

- 无额外准备；仅将文件名改为 `tutorial_zh.ttf`，未改字体内部名称、未 subset。
- 若后续需要子集化：OFL 允许修改，但属于 Modified Version，需继续使用 OFL-1.1 并保留版权/许可；因未声明 RFN，命名限制不适用。当前交付不需要子集化。
