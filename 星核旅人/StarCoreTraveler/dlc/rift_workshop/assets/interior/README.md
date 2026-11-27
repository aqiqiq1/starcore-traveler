# interior · DLC2 裂隙工坊室内背景（2026-11-27）

运行时副本；主体由 `dlc/rift_workshop/tools/gen_interior_assets.py` 程序化生成，2026-11-28 景深增补由 `dlc/rift_workshop/tools/gen_depth_20261128.py` 生成；不读取任何第三方图片或色板。参考核看记录：`dlc/rift_workshop/REF_INTERIOR_20261127.md`、`dlc/DEPTH_REFERENCE_20261128.md`。

| 文件 | 尺寸 | 用途 |
| --- | --- | --- |
| `interior_back_1880x360.png` | 1880×360 | `Background/Back`；已批准石墙原图，逐像素未改 |
| `interior_deep_1880x360.png` | 1880×360 | `Background/DepthOverlay` 深图；更暗的工坊内厅：远拱、管道、吊链、矮行架、暗余烬床 |
| `interior_depth_mask_1880x360.png` | 1880×360 | 深喉遮罩；只在入口盲拱与巨拱内层为白，石框、凹槽、内沿、镜厅、炉胸全透明 |
| `rift_furnace_smoke_96x48.png` | 96×48 | 炉口暖烟遮罩；`Atmosphere` 以 0.14–0.21 alpha 绘制，不做全屏雾 |
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
- 拱洞内层（2026-11-27 追加）：入口拱/中段巨拱/镜厅三拱不再用纯黑填充；内层为 32×16 暗砖墙（比外墙暗一档）、1 px 内缘弱光、底部暖反射；巨拱加齿轮/管道/木架/余烬；镜厅在镜面后加机件剪影，并在玻璃里画低对比反射。实测近黑（max(R,G,B)<24）最高 26.90%，低于 40%，复现脚本 `../tools/verify_interior_arches.py`。
- 室内景深（2026-11-28 追加，生成器 `../tools/gen_depth_20261128.py`）：`Background/DepthOverlay` 是 Background CanvasLayer 内的 1880×360 遮罩合成，和 Back 共用 **0.90 的整数偏移**；深图内容按 **0.65** 移动，采样偏移 `round(scroll × 0.65) − round(scroll × 0.90)`，不跟 zoom。深厅中位明度/已批准拱内中位明度 = 0.676，落在 25–35% 压暗区间。原 `interior_back` 未改，只由遮罩在深喉处盖出远景。
- 开场电影：`rift_workshop.gd` 在影片开始时把 DepthOverlay 强度设为 0、把新 Atmosphere 的 modulate.a 设为 0；`_on_intro_cinematic_finished` 用 0.30 s 同时淡入深厅与炉烟。影片最后 4.42 s 的入口拉回保持原图；控制权交回后才出现景深。原 `RiftFog` 与影片覆盖层未改。
- 世界前方的炉烟/余烬在 z=10，只做炉口局部；玩家包围盒 ±8 px 与桥段危险区不重叠。原旧云海、旧雾图全部保留。
- 许可：项目自制程序化像素；如单独作为素材包分发，由项目组另行决定许可/署名。
