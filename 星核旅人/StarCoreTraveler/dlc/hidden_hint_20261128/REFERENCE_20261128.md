# 隐藏支线轻提示 · 呈现参考核对（2026-11-28）

本记录只覆盖两处文字提示：DLC3 检查点后的一行 HUD 事件、章节页列表底部的一行弱化页脚。不新增图标、面板、行高或第三方素材。

## 实际打开并核看的画面

### 1. 项目已批准的章节页（主构图依据）

- 文件：`screenshots/chapter_select_20261127/chapter_select_locked.png`（本轮打开）。
- 观察：640×360 深青面板；4 行 30 px 章节行结束后，列表与底部“↑↓ 选择 / 返回”之间有一整块空白；页脚放在第 5 个（隐藏支线）行位，不移动 4 行、不压底部提示。
- 可借鉴：页脚左对齐到行内文字（x=116），12 px，弱灰；只作为列表末尾的余白文字。
- 不照搬：不增加第 5 行按钮、不占位、不使用图标/星级/完成度徽章。

### 2. 《Deltarune》Chapter Select 原图（形态参考）

- 来源：<https://deltarune.wiki/w/File:Chapter_Select_screenshot.png>
- 本地原件：`dlc/chapter_select/reference/deltarune_chapter_select_640x480.png`（本轮打开）。
- 观察：章节行纵向等宽排列；底部 Quit / 语言单独一行，不与章节行混排；未开放行整体压暗。
- 补充文字（Deltarune Wiki “Chapter”页，`https://deltarune.wiki/w/Chapter` 本轮 403，未能打开原页；仅见搜索摘要）：章节页用完成星与 Shadow Crystal 标记隐藏内容。
- 可借鉴：隐藏内容可以在章节页给“存在但未发现”的弱提示；页脚保持在列表末尾，独立于操作行。
- 不照搬：不复制星/水晶图标、像素字、配色；本项目的页脚只写一句方向提示，不显示支线名称。

### 3. 项目现有 DLC3 检查点 HUD（行宽/位置依据）

- 文件：`screenshots/loom_mechanics_20261127/checkpoint.png`（本轮打开）。
- 观察：640×360 下 HUD 只有左上角一行 12 px 事件文字（章节名 + 事件），替换原目标行，没有第二行；检查点本体 40×36，镜面入口在其右侧。
- 可借鉴：新提示继续使用同一行、同一字号；不新增图标、不改 HUD 结构。
- 不照搬：不把提示做成常驻任务栏或世界内浮动文字。

### 4. 《Hades》Mirror of Night 页面（“镜子作为可发现物件”的语义参考）

- 来源：<https://hades.fandom.com/wiki/Mirror_of_Night>（本轮打开页面）。
- 观察：镜子是房间中的可交互物件，页面说明其功能与解锁，不使用常驻箭头/任务标记引导；玩家靠近后才进入交互。
- 可借鉴：先让世界物件自己存在，文字只给一次轻提示，不提前说明支线内容。
- 不照搬：不复制 Hades 的界面、图标、配色或对话文案。

## 落地边界

- 检查点事件：`检查点已记录 · 旁边那面镜子好像有反应`，只替换同一行 HUD，不新增行；有教学行时先教学、后提示，避免同一帧互相覆盖。
- 章节页页脚：`还有未发现的支线 · 留意主线里的镜子`，12 px、弱灰、位于最后一个可见行下方；发现 `discovered_rift` 后与 `kskbl` 后都不显示。
- 不剧透支线名称、不写“裂隙工坊”、不加图标或计数。

## 证据

- `screenshots/hidden_hint_20261128/01_dlc3_checkpoint_hint_640.png`
- `screenshots/hidden_hint_20261128/02_chapter_page_side_hint_640.png`
- `screenshots/hidden_hint_20261128/03_chapter_page_after_discovery_640.png`
- 功能证据：`dlc/star_loom/tests/hidden_hint_test.log`、`dlc/chapter_select/tests/chapter_select_test_hidden_hint.log`

## 未核实

- Deltarune Wiki 原页本轮 403，隐藏内容标记只依据搜索摘要与既有参考记录，未把星/水晶画面作为本项目的视觉依据。
- Hades 只打开 wiki 页面，未逐帧核对镜子交互动画；本轮不需要连续动画结论。
- 两处提示均为静态文字，没有音效、动画或过门遮挡需求。
