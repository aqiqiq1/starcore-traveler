# 玩家生命条颜色考证（2026-11-26）

用户要求：所有有敌役的关卡统一用血条，颜色先考证。

## 实际核看

- **Hades** 战斗 HUD（PlayCraft 收录的官方 Steam 截图/预告帧）：玩家生命是**暗红/酒红长条**，深色外框，金色/骨白装饰；低血量时整条脉冲变亮；敌人血条是更细的红条+数字。页面给出的画面主色包含 `#562c2d`（暗酒红）、`#221b23`、`#13111a`。来源：<https://playcraft.space/gallery/hades/combat-hud-asphodel-boon/>
- **Dead Cells** UX/UI 记录（Game Design Lab）：生命条永远在屏上，和药水/金币同一 glance budget；敌人血条独立、细条。来源：<https://teemo.dev/game-design/dead-cells/systems/ux-ui-and-accessibility/>
- **Dead Cells** 官方 Steam 实机图（已打开 `deadcells.jpg`）：画面是紫红遗迹+红色刀光，HUD 被裁掉；只能确认红色是高亮/危险色，不能从这张图取血条像素。来源：<https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/588650/ss_ac28000ade40cc2fe5c128f32ac98ba33c008a7a.1920x1080.jpg>
- **Hollow Knight** 用面具而不是条，和“所有敌役关用血条”的方向不同，未采用。

## 结论（本项目采用）

- **玩家生命值**：红色分段条，固定屏幕左下角，不跟人物。
  - 填充 `#d95757`（珊瑚红），最后一格 `#ff7b7b`（亮红）；
  - 空槽 `#211214`（近黑酒红）；外框 `#05090a`；1 px 金色下划线 `#f4cd63` 与 UI 金边呼应；
  - 顶部 1 px 暖白高光；受击时短脉冲。
- **生命数**（仅 DLC3）：红色心形，和生命值条分开；不混用条。
- **Boss/核心**：Boss 状态用分段红色核心耐久（每段＝1 次真伤）+ 阶段格；只有双面镜两面盘、织机两节点这类独立对象保留菱形图标，不再另画核心菱形。不把 Boss 条做成玩家血条，避免同类色混淆。

## 边界

- 没有取到 Hades/Dead Cells 血条的逐像素原图；颜色是按官方画面主色 + 深框/暖高光的读法定的，不是从截图吸色。
- 未做色盲/低对比度测试；条上同时有“满/空格数”和金色下划线，不只靠颜色。
