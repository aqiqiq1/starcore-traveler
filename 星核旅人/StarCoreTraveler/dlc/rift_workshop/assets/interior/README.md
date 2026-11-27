# interior · DLC2 裂隙工坊室内背景（2026-11-27）

运行时副本，全部由 `dlc/rift_workshop/tools/gen_interior_assets.py` 程序化生成；不读取任何第三方图片或色板。参考核看记录：`dlc/rift_workshop/REF_INTERIOR_20261127.md`。

| 文件 | 尺寸 | 用途 |
| --- | --- | --- |
| `interior_back_1880x360.png` | 1880×360 | `Background/Back`；石墙、拱洞、炉膛、镜厅镜面，滚动系数 0.90 |
| `interior_mid_1880x360.png` | 1880×360 | `Background/Mid`；暗木梁、铁箍、垂链、工作台、墙灯，滚动系数 0.97 |
| `interior_fore_640x360.png` | 640×360 | `Background/Fore`；屏幕固定木框（顶梁 16 px、左右柱 10 px），中间透明 |
| `interior_floor_1880x40.png` | 1880×40 | `RiftFloor`（世界坐标 y=320，z=2）；暖石地面，x=560–1079 透明以露出桥下深井 |
| `interior_warm_haze_640x360.png` | 640×360 | `RiftFog` 暖尘雾底图；实际 mote 由 `rift_fog.gd` 绘制 |
| `interior_post_tall_52x112.png` | 52×112 | `scenes/workshop_post_tall.tscn`；替换本章 4 根高立柱，底边仍在 y=320 |
| `interior_post_broken_52x84.png` | 52×84 | `scenes/workshop_post_broken.tscn`；替换本章 3 根断柱，底边仍在 y=320 |

## 规格

- 石墙：48×24 砖、1 px 缝；L2 石族压暗一档，暖环境光只叠加在局部；每皮砖顶边 1 px 亮、底边 1 px 暗。
- 木/铁：木 `(28,20,17)`–`(108,77,53)`；铁 `(23,22,21)`–`(88,75,57)`；柱左 1 px 亮、右 1 px 暗；梁顶 1 px 暖亮、底 1 px 黑。
- 金只保留檐口/踢脚 1 px 暗金线；不在桥段 y200–320 放金色、青色或亮窗。镜厅玻璃为中性炭灰，让双面镜的金/青面盘保持最高饱和。
- 炉火：外焰 `(142,62,22)`、内焰 `(234,142,58)`、芯 `(255,196,108)`；仅做局部暖光，不改结构受光方向。
- 桥下深井：`interior_floor` 在 560–1079 透明，背景底层画暗铁梁/远机件；地面碰撞条与所有地形节点坐标未改。
- 旧云海：`scenes/backgrounds/cloud_ruins_ds03.tscn`、`assets/backgrounds/cloud_ruins_ds03/` 与旧 `assets/rift_fog_640x360.png` 均保留，未被覆盖。
- 许可：项目自制程序化像素；如单独作为素材包分发，由项目组另行决定许可/署名。
