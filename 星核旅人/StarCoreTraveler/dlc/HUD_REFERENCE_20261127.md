# HUD 参考核看记录（2026-11-27）

本记录对应 `dlc/PRESENTATION_SYSTEM.md` 的统一 HUD 工作。只记录实际打开过的画面、
能借鉴与不能照搬的部分；未看到的动效不冒充已核看。

## 实际打开的参考

1. **Hades — Combat HUD in Asphodel**（PlayCraft 收录的 Steam 宣传/实机帧）
   - 来源：<https://playcraft.space/gallery/hades/combat-hud-asphodel-boon/>
   - 证据：`screenshots/hud_refs/hades_playcraft_combat.webp`
   - 画面身份：Hades 战斗 HUD，Asphodel 场景。
   - 实际观察：玩家生命是**屏幕左下角**的暗红长条，深色外框、金色下沿线；
     右侧有 `59 / 155` 数字与 3/3 的 Death Defiance 菱形点；敌人血量是头顶细条。
     页面主色 `#221b23 / #13111a / #562c2d`。
   - 可借鉴：生命条固定屏幕边缘、不跟人物；深色框 + 暖高光保证亮场景可读。
   - 不照搬：Hades 的骨白/金色雕饰外框、数字分数、Death Defiance 菱形点；本作用
     红色分段条 + 10×10 红心，不显示数值。

2. **Hades — Lernaean Bone Hydra boss fight frame**
   - 来源：<https://www.youtube.com/watch?v=heu5DMZqpPU>（视频缩略帧）
   - 证据：`screenshots/hud_refs/hades_boss_maxresdefault.jpg`
   - 画面身份：Hades  Bone Hydra 战斗。
   - 实际观察：Boss 名称在**顶部中央**，字号很小，名称下方是一条很细的红条；
     没有大面板、没有左侧图标行；玩家生命仍在左下角。
   - 可借鉴：顶部中央、名称 + 细红条、屏幕边缘留白；Boss 条与玩家条分离。
   - 不照搬：Hades 的字体、描边和颜色比例；本作用 360×16 条 + 分段核心耐久 + 阶段格，核心只画一次。

3. **Hades — Use the Mirror to Grow Stronger**（Game UI Database 任务行）
   - 来源：<https://www.gameuidatabase.com/gameData.php?id=534>
   - 证据：`screenshots/hud_refs/hades_guidb_mission.jpg`
   - 画面身份：Hades 家园任务提示。
   - 实际观察：左上只有**一行**小号任务文字，前面一个小菱形图标；没有说明面板、
     没有第二行计数。
   - 可借鉴：左上单行、边缘锚定、无底板。
   - 不照搬：全大写英文字体、菱形图标；本作用章节名暖白 + 目标金色。

4. **Hades — Enemy Health & Damage**
   - 来源：<https://www.gameuidatabase.com/gameData.php?id=534>
   - 证据：`screenshots/hud_refs/hades_guidb_enemy_health.jpg`
   - 实际观察：普通敌人是头顶细红条，玩家仍为左下角长条；没有常驻图例。
   - 可借鉴：玩家条与敌役条分级；低价值小怪不进顶部 Boss 条。

5. **Dead Cells — Player Vitals**（Game UI Database）
   - 来源：<https://www.gameuidatabase.com/gameData.php?id=1780>
   - 证据：`screenshots/hud_refs/deadcells_vitals.jpg`
   - 画面身份：Dead Cells 实机 HUD。
   - 实际观察：生命值固定在**屏幕底边**、深色外框、与武器/道具栏同一视线带；
     不回随人物移动。
   - 可借鉴：底边固定、深框、与其它 HUD 同一 glance 带。
   - 不照搬：Dead Cells 的绿色生命/橙色回复、连续条、武器格；本作用红色分段。

## 结论（本作采用）

- 左上：单行章节名（暖白）+ 目标（金），事件替换目标；不设说明面板/第二行。
- 右上：20×20 日/月带深色底板图标，无“相/辉相/澜相”文字。
- 左下：10×10 红心 + 14×8 红色分段条（gap 2），固定 (14,324)。
- 顶部中央：360×16 统一 Boss 条，名称 12 + 分段红条（每段＝1 次真伤）+ 阶段格；
  只有独立对象保留菱形（双面镜两面盘、织机两节点），不再重复核心菱形；DLC3 三颗心
  放在条下方，不写文字。
- 模态页隐藏 HUD chrome，关闭恢复；HUD 出场 0.15 s 淡入。

## 边界 / 未核实

- 以上均为静态画面/视频缩略帧；**没有**逐帧核对 HUD 的淡入淡出、滑动或受击脉冲。
  本作的 0.15 s 淡入来自 `PRESENTATION_SYSTEM.md` 的批准规格，不冒充参考画面观察。
- 没有对参考图做吸色/逐像素测量；颜色采用项目既定色板 `#f4cd63 / #5fe1e6 /
  #d95757 / #ff7b7b`，不是从 Hades/Dead Cells 截图取色。
- 没有把 Hades/Dead Cells 的像素、字体、图标或版式复制进工程；只借鉴边缘锚定、
  单行任务、细 Boss 条的分层读法。
- 顶部 Boss 条实际放在 y=22，位于单行章节/目标下方，避免 5 字章节 + 长目标与
  360 px 条在 y=3 时叠字；这是本工程的布局决定，不是参考图原位置。
