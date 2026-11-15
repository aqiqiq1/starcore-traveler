# 云海遗迹 V7 静态背景（保留对照）

> 2026-11-03 状态：第一关当前可见背景已改为 DS03 动态组件
> `Background/CloudRuinsDS03`；`Background/CloudRuinsV7` 仅保留并 `visible = false`
> 作旧静态对照。DS03 运行资源/说明见同目录 `cloud_ruins_ds03/`。本文件只记录 V7
> 资产本身的无损导出与旧层保留。

## 来源与无损导出

- 源图（只读）：`D:\godot game\星核旅人\自制素材\云海遗迹背景概念示意\background_only_v7.png`
- 源图规格：1280×720 RGB；它是已批准 640×360 逻辑图按 NEAREST 2 倍放大的展示稿，不是另一套细节画。
- 运行副本：`assets/backgrounds/cloud_ruins_v7.png`，640×360 RGB。
- 导出前逐块核验源图每个 2×2 像素块完全相同，差异采样为 **0**；运行时图直接取每个 2×2 块的左上像素，没有重采样、重新缩绘、模糊、锐化、调色或 tint。
- 导出后把运行图按 NEAREST 2 倍重新展开，与 V7 源图逐像素比较完全一致。
- SHA256：
  - 源图 `2d65a27d432ce60d8562c71cf754049d49a106d08e63348d78cb08f4c8387aae`
  - 运行图 `0c81488d74eb87b0219ea3ead2aa31f074c1a371ab9a7aba0984b67a4a0f9092`
- 可复现脚本：`tools/export_background_v7.py`；机器可读记录：同目录 `source_manifest.json`。脚本会锁定上述源 SHA256；源图变化时拒绝导出，避免把未批准的新图悄悄带进关卡。

## 引擎接入

- `CloudRuinsV7` 仍是 `scenes/level_01.tscn` 的 `Background`（`CanvasLayer`，`layer = -10`）下的真实 `TextureRect`，但已 `visible = false`，只作旧静态对照；当前可见背景由 `Background/CloudRuinsDS03` 接替。
- V7 节点配置：640×360、`texture_filter = Nearest`、`mouse_filter = Ignore`、`modulate = Color(1,1,1,1)`、无脚本。
- V7 本身是**固定屏幕空间的整图静态背景**：不随相机滚动，不重建、不覆盖 Inspector 设置，也没有视差、分层动画或天气。
- 为不让旧色调层和旧占位云海叠在 DS03 上，以下节点只设 `visible = false`，节点、资源、参数和场景位置都保留：
  - `Background/Sky`、`Background/FarRuins`、`Background/NearRuins`、`Background/Mist`
  - `World/PitCloudBack`、`World/PitCloudFront`、`World/PitCloudGlow`
- 旧 `assets/map/background2.png`、`background4.png` 及 `scenes/main.tscn` 原型未改动。

## 可调范围与限制

- 可以直接调整 `CloudRuinsV7` 整个 `TextureRect` 的位置、尺寸或显隐，用来整体对齐画面。
- **不能单独移动 PNG 里的桥、断口、石柱、云团或远岛**；它们已经合成为一张整图。
- 当前没有视差、分层漂移、云动画、雨天或逐物件碰撞，不要把这些当作已完成能力。
- 源图不覆盖；若要改画面，应重新取得批准稿，再更新脚本中的源 SHA256 与 manifest，而不是手改运行 PNG。
