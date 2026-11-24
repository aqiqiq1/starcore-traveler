# 云海遗迹背景概念示意（待审核，非实机）

- `concept.png`：640×360 逻辑画面，NEAREST 2倍至1280×720。新背景与当前素材的比例对照，非新地图提案，未接入Godot。
- `background_only.png`：同构图去前景，供检查距离层次。
- 天空/云带、远浮岛、断桥与残缺柱列、云海由脚本直接绘制。没有引用外部背景包、Szadi建筑模块或付费服务，没有将前景柱放大充当背景。
- 实际查看参考：`基础场景原型/screenshots/doric_02_walkway.png`、`doric_03_far_bank.png`，前景图集与庭院石柱四图及manifest。
- 原图直接合成（不改色不缩放）：`基础场景原型/assets/map/ruin_platform_tiles.png`、`assets/characters/male_hero-idle.png`第0帧、`assets/talisman/talisman_gold.png`、`assets/rune_stone/rune_stone_gold.png`；`自制素材/庭院石柱/doric_column_{tall,broken,fallen}.png`（后两者在本窗口外/裁边，仍保留原世界坐标）。
- 地形复现`level_terrain_block.gd`的16px贴图规则。世界窗口x1000..1640；坑前地面y220，对岸y300；角色world1110/foot220，符石world1360/y150，高柱world1600/foot300。高柱原图52×108；角色原128×128帧/实际alpha37px高；符石原32×32。不是截图改背景，也没有更改角色、批准柱式或运行资产。
- 中文字：工程`assets/fonts/tutorial_zh.ttf`及其OFL许可证；角色沿用工程既有素材，第三方授权范围未重新核验，概念预览不构成发行授权确认。
- 复现：`D:\minic\envs\2024212971\python.exe 自制素材/云海遗迹背景概念示意/generate_concept.py`；仅Pillow，无下载，输出限本目录。
- 待审核：灰青建筑明度、断桥与残拱密度、云海分层。未验证引擎内移动时的可读性；未做视差、动画、碰撞或场景接入。
