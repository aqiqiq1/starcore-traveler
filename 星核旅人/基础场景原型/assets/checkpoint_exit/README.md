# 恢复点与通关门运行图

本目录只包含第一关实际使用的 4 张透明 PNG。源图只读目录：
`D:\godot game\星核旅人\自制素材\恢复点与通关门概念示意\`

## 文件与校验

四张运行图均由源文件逐字节复制，未裁切、缩放、镜像、重绘或与旧占位几何复合。本轮只把石色换成与 `assets/doric_columns/doric_column_tall.png` 同源的暖灰/灰褐色阶，alpha、轮廓、像素位置和非石色均未改。

| 运行文件 | 尺寸 | SHA256 | 脚底锚点 | alpha bbox（右下不含） |
| --- | --- | --- | --- | --- |
| `checkpoint_inactive.png` | 40×36 | `f6aedc7225fab5ebf6403dde666cb2b8f198199fc1c9bda2d59eef4d118646c6` | (20, 35) | (3, 10, 38, 35) |
| `checkpoint_active.png` | 40×36 | `cba0c92bf76b911d4b96ae48de141f71c3c80bb13379df14814e3ed3a30cb99d` | (20, 35) | (3, 5, 38, 35) |
| `exit_open.png` | 76×100 | `9ce2857344474de877894384cc1fca2cee7b642ba3d58d7db560b6abd0ea8c16` | (38, 99) | (4, 7, 71, 99) |
| `exit_completed.png` | 76×100 | `647325f7d0f6f9dabcac2be38b35035fc3a1e833de0f95523a1e3c19fc42e7db` | (38, 99) | (4, 3, 71, 99) |

石色角色映射（旧绿灰 → 柱色，按明度升序）：`out → EDGE(66,55,62)`、
`dark → DARK(89,74,81)`、`groove → recess(103,87,93)`、`shade → SHADE(113,96,100)`、
`stone → MID(143,128,126)`、`mid → lip(160,145,138)`、`light → lit(174,161,151)`、
`glint → TOP(181,169,158)`。八个色调均在 `doric_column_tall.png` 中实际出现。
逐像素可复现检查：`D:\minic\envs\2024212971\python.exe tests\verify_checkpoint_exit_stone_palette.py`。

`alpha bbox` 的 bottom 为不含值：恢复点最后一行不透明像素是 y=34，出口是 y=98。
因此脚底锚点 35/99 正好是最后一行不透明像素的下边缘，而不是透明画布底边
36/100。绘制时必须使用锚点偏移，否则会整体上浮 1 px。

## 绘制约定

- 1 源像素 = 1 逻辑像素；`Nearest` 过滤；白色 `modulate`。
- 四张图的导入参数关闭 `fix_alpha_border`，专项测试逐像素比较导入缓冲与原 PNG。
- `World/Checkpoint` 节点位置仍是脚底恢复点，贴图左上角绘制在 `(-20, -35)`。
- `World/Exit` 节点位置仍是门口脚底，贴图左上角绘制在 `(-38, -99)`。
- 两张出口图的中央门洞是透明的：`x=30..49, y=35..91` 为纯 alpha=0 区域，
  可以看到门后的背景；图片本身不带物理实体，不改变 36×76 的 `Area2D` 触发区。
- 图片只区分两态：恢复点触碰激活后换 `checkpoint_active.png`；出口完成一次后换
  `exit_completed.png`，R/重进恢复开放态。没有新增动画、粒子、磁盘存档、E 交互或锁门规则。

## 来源与边界

- 源图是本次项目用 Pillow 程序化绘制的概念图，属于 AI 辅助的项目自制素材；
  源说明见源目录 `README.md`。本次只复制上述 4 张 PNG，没有把合并预览图、
  展示字体、生成脚本搬进工程。
- 运行时由 `scripts/level_checkpoint.gd` 与 `scripts/level_exit.gd` 在 `_draw()`
  中按原尺寸绘制；`@tool` 使外观在编辑器中同样可见，触发框与文字辅助线只在编辑器显示。
- 旧占位绘制已移除；本次没有修改关卡地形、出生点、机关、HUD、玩家或关卡主脚本。
