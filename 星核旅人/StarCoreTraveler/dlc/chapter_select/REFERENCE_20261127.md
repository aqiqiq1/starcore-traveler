# 章节入口 / 章节页呈现参考核对（2026-11-27）

本记录只覆盖“标题菜单加一个章节入口 + 章节页”这一处呈现问题。先看了实际画面，再定规格；参考图不参与运行时，不得导出或当作游戏素材分发。

## 直接参考

### 1) 《Deltarune》Chapter Select

- 来源：<https://deltarune.wiki/w/File:Chapter_Select_screenshot.png>
- 画面身份：Deltarune 官方章节选择截图，640×480，Toby Fox / Deltarune。
- 实际观察（打开原图核对）：
  - 纵向等宽章节行，左侧“Chapter N”编号，中部章节名，右侧图标/状态；
  - 未开放章节整行压暗，右栏用“--”占位，与可用章节的亮色形成层级；
  - 每行有清晰的水平分隔；当前行用更亮的字色/下划线强调；
  - 底部单独一行放 Quit / 语言等工具项，不与章节行混排。
- 可借鉴：纵向 6 行、行间分隔、锁定行整体压暗并在右侧写前置条件、当前行用亮色/光标强调、底部返回单独放。
- 不能照搬：不复制它的像素字体、图标、配色和 640×480 构图；不使用“--”这种无信息占位，本项目要明确写“需先完成 X”。

### 2) 《Mega Man X》Stage Select

- 来源：<https://www.mobygames.com/game/1334/mega-man-x/screenshots/snes/62104>（CDN 原图 <https://cdn.mobygames.com/screenshots/2019013-mega-man-x-snes-the-stage-select-screen.png>）
- 画面身份：SNES《Mega Man X》Stage Select，256×224。
- 实际观察：8 个 Boss 头像围成一圈，中央是当前选中的关卡预览；是“网格 + 预览”结构，不是章节列表。
- 结论：与本项目“6 项纵向章节列表”不是同一形态，只用来确认“选中项要明显、未选中项要退后”的一般原则；不作为布局参考，也不照搬头像/边框/像素。

### 3) 项目自身已批准的 V1 标题菜单（主参考）

- 文件：`assets/menu/main_menu_ui_640.png`、`main_menu_focus_settings_640.png`、`main_menu_quit_640.png`、`settings_panel_640.png`。
- 实际观察：
  - 640×360，标题像素字 + 金色描边的主按钮；
  - 设置/退出是小号单行字，12 px，焦点状态是 2 px 竖光标 + 1 px 青色下划线；
  - 面板是 1 px 直角描边 + 深青底，没有圆角和渐变；
  - 菜单行之间约 20–24 px 的紧凑间距。
- 可借鉴：章节页沿用同一字体、金色标题、深青面板、1 px 描边、2 px 光标与青色下划线；行按钮复用 `PixelMenuButton` 的 STONE 面/描边。
- 不能照搬：不重画一套更大的“卡片”；不改变 V1 标题按钮的主次关系；新增的“章节”只是次级单行，不抢“开始游戏”。

## 落地规格（已实现）

- 标题菜单：`开始游戏` 与 `设置` 之间插入 20 px 高的单行“章节”，只复用同字号/同焦点语言；`设置`/`退出` 下移 11/3 px，三行 DLC 入口保持原 y=238/262/286，避免推翻已验收的 DLC 行。
- 章节页：640×360 的深青面板，6 行 × 30 px；左列序号 01–06，章节名 14 px，右列类别标签与状态；锁定行 `PixelMenuButton.disabled`（不可聚焦、鼠标穿透），右侧写“需先完成 X”；底部单列“↑↓ 选择 · Enter 进入 · Esc 返回”和鼠标“返回”。
- 没有加入插图、章节缩略图、完成度星级或第三方像素。

## 证据

- `dlc/chapter_select/reference/deltarune_chapter_select_640x480.png`（外部参考，`.gdignore`，不参与导入/导出）
- `dlc/chapter_select/reference/megamanx_stage_select_256x224.png`（外部参考，仅作形态排除）
- 实际游戏内 640×360 证据：`screenshots/chapter_select_20261127/`
  - `chapter_select_locked.png`
  - `chapter_select_unlocked.png`
  - `title_menu_chapter_row.png`

## 未核实项

- 参考均为静态截图；本轮需求不涉及过门遮挡、景深或连续动画，因此没有连续帧/视频证据需求。
- Deltarune 的完成星级/图标语义未采用，也未核对它的存档规则；本项目只存 6 个 bool。
- Mega Man X 截图来自 MobyGames CDN，未核对原始 SNES 实机色彩；仅用于确认其网格形态不适用。
