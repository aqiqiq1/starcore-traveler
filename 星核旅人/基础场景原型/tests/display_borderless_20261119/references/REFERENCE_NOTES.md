# 参考记录：像素游戏显示/窗口设置

日期：2026-11-19。只用于本轮“窗口模式增加 1920×1080 无边框选项”的 UI 文案与状态呈现，不改变项目已批准的面板版式。

## 1. Celeste — Options（实际画面，已查看）

- 来源：https://interfaceingame.com/screenshots/celeste-options/
- 原图：https://interfaceingame.com/wp-content/uploads/celeste/celeste-options-1920x1080.jpg
- 本地证据：`references/celeste_options_1920x1080.jpg`（1920×1080，已用图片查看器打开）
- 身份：Celeste（Windows, 2018）的 Options 画面，Interface In Game 截图页。
- 实际观察：
  - 选项按行排列，左侧是设置名，右侧是值；`VIDEO` 分组下 `Fullscreen` 用 `< ON >` 形式表达布尔状态，没有分辨率列表。
  - 选中行用绿色数值 + 左右箭头，未选中行保持白色；层级靠分组小标题和留白，不靠大边框卡片。
  - 设置项文字短，说明不塞进每一行，避免在低分辨率像素字体下拥挤。
- 能借鉴：
  - 选中态必须明显；本轮继续用现有金色选中 + 左侧小方块。
  - “窗口/全屏”是模式，分辨率是另一个维度；本轮不把 1920 无边框做成第三个模式按钮，而是在分辨率项上标注。
  - 按钮文字要短，说明放到独立注释行。
- 不能照搬：
  - Celeste 没有分辨率列表，也没有“无边框窗口”选项，不能拿它证明无边框行为。
  - 不复制其字体、配色、箭头图形或菜单构图；这些不属于本项目已批准 UI。
- 未核实：没有拿到 Celeste 的设置保存/回退流程画面。

## 2. Stardew Valley — Window Mode 文案（页面文字，未取得原画面）

- 来源：https://stardewvalleywiki.com/Options
- 访问结果：直接抓取返回 403；`webfetch` 同样 403。只通过搜索索引读到页面文字，**没有打开原页面，也没有查看 Options 截图**。
- 索引文字记录：Graphics → Window Mode 下拉为 `Windowed` / `Fullscreen` / `Windowed Borderless`；Resolution 只在 Fullscreen 下可改。
- 用途：仅作为“商业像素游戏把 Windowed Borderless 作为窗口模式的一种、而不是 exclusive fullscreen”的旁证。**不作为视觉参考，也不宣称已核看原画面。**
- 未核实：Stardew 的实际 Options 布局、无边框窗口的标题栏/任务栏覆盖表现、Alt-Tab 行为。

## 3. 本轮结论边界

- 可落地的视觉决定：保留现有 640×360 设置面板和两列分辨率按钮；只把 1920 按钮文字改为 `1920×1080（无边框）`，并在下方加两行说明。选中/禁用态沿用现有 `PixelMenuButton`。
- 行为决定来自用户规格与本机实测，不来自参考图：1920×1080 以 `WINDOW_FLAG_BORDERLESS`、`Window.MODE_WINDOWED`、尺寸 1920×1080 运行；640/1280 仍带框；2560 仍禁用；全屏不变。
- 未复制任何第三方像素、字体、图标、配色或菜单布局。参考图仅留在本目录作为研究证据，不进入游戏资源。
