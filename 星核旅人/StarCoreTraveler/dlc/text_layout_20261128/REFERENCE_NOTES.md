# UI 文字排版参考记录（2026-11-28）

范围：机制手册分页/行距、三列（图标+名称/说明/键位）对齐、页码，以及 640×360 全页面文字叠压核对。
任务要求“呈现制作前先核看实际参考”，本文件记录实际打开过的画面，不代替自己的截图证据。

## 1. Celeste — Paused / Options（界面站截图）

- 来源：https://interfaceingame.com/screenshots/celeste-paused/（图：`https://interfaceingame.com/wp-content/uploads/celeste/celeste-paused.jpg`）
- 来源：https://interfaceingame.com/screenshots/celeste-options/（图：`.../celeste-options-1920x1080.jpg`，同页可下载）
- 本地证据：`C:\Users\aqiqiqi\AppData\Local\Temp\opencode\ui_ref_20261128\celeste_paused.jpg`、`celeste_options.jpg`
- 实际观察（1920×1080 截图折算到 360p）：
  - 暂停页：标题与选项分离明显；选项单行居中，条目行距约 71 px（1080p）≈ 23.7 px（360p）；选中项用颜色区分，不加边框压在文字上。
  - 选项页：左右两列，左列名称、右列值/开关；两列之间留出约 200 px（1080p）≈ 67 px（360p）的空档；分组用灰色小标题，不做满宽分隔线；行距同样约 23 px（360p）。
- 能借鉴：12 px 像素字配 22–24 px 行距；名称/说明/值三列之间留出大于一个字的空档；同组条目不用逐行横线切碎。
- 不能照搬：Celeste 是 320×180 放大到 1080p，字形与我们的中文字宽不同；它的选项页靠滚动，没有页码，本项目按已批准规格做 8 条/页 + 页码。

## 2. TUNIC — Instruction Booklet, Page 12 “Controls”

- 来源：https://tunic.wiki/books/instruction-booklet/page/page-12-controls
- 本地证据：`C:\Users\aqiqiqi\AppData\Local\Temp\opencode\ui_ref_20261128\tunic_page12.jpg`
- 实际观察：
  - 页码“12”单独放在页面右下角、内容框之外，尺寸远大于正文，不与任何说明文字同层。
  - 键位用独立的白色小键帽贴纸，和文字之间有明显留白；每个键帽-说明是一组，组与组之间不画分隔线。
  - 同一页的信息按左右两栏分组，中央留给手柄图；没有文字压图或压框。
- 能借鉴：页码独立占右下角安全区；键位单独成列，不塞进说明句里；键帽与说明之间保持一个字的空档。
- 不能照搬：TUNIC 是手绘说明书版式，单页信息量小；本项目 15 条机制必须分页，不能照它的自由排版。

## 3. 本项目既有证据（作为“现状”而非参考）

- `screenshots/manual_20261128/02_manual_mixed.png`：现状手册 15 行 × 18 px，页脚与最后一行重叠，说明列直接顶到键位列。
- 结论：本次按 22–24 px 行距、三列留白、8 条/页、右下页码重做。

## 未核实项

- 未取得 Celeste/TUNIC 的可播放视频；上述结论只针对静帧可确认的间距、列对齐、页码位置，不涉及翻页动画节奏。
