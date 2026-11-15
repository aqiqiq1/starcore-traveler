# 庭院多立克石柱（V4 局部细化版，已接入第一关）

## 来源与批准

- 源目录（只读）：`D:\godot game\星核旅人\自制素材\庭院石柱\`
- 本目录四张 PNG 与源文件**逐字节相同**，没有重新裁画、缩放、调色、tint 或镜像。
- 造型为已批准的 V4；细化只改动原有不透明像素的局部 RGB，alpha、画布尺寸和外轮廓不变。
- `source_manifest.json` 是源目录 `manifest.json` 的逐字节副本，保留原始尺寸、alpha 包围盒、`foot_anchor`、SHA256 和细化方式记录。
- 源manifest中的“not engine-integrated”是源图生成阶段的状态描述；当前接入状态以本说明与第一关场景为准，不为更新状态改动源manifest副本及其校验值。
- 石柱为本项目在 V4 重绘上的项目内制作。结构参考和第三方配景边界见源目录 README；本次没有新增外部素材。

## 文件、尺寸与锚点

| 文件 | 画布 | alpha bbox（半开） | foot_anchor | SHA256 |
| --- | --- | --- | --- | --- |
| `doric_column_tall.png` | 52×108 | (8, 0, 44, 108) | (26, 108) | `3d919ef5167470b3e36929d6ccacf4bfd6714c4ea628cf062f3ba4e589c8e475` |
| `doric_column_broken.png` | 52×82 | (9, 0, 43, 82) | (26, 82) | `6603feea5494f5e9377153ed44edc44d3dd0880dd2f1a08ad33cbcfe81d1b420` |
| `doric_column_base.png` | 52×24 | (9, 0, 43, 24) | (26, 24) | `f25ade68e3f78d1ba448a9d3aef7de51e70980e5fe92e9735104d4fc733328f5` |
| `doric_column_fallen.png` | 56×28 | (1, 4, 56, 25) | (28, 25) | `185d0300a44dcd6ba4501254da4fbba0f66b487da908f5ada7d7b3f96a8b5b61` |

`foot_anchor.y` 采用 alpha bbox 的 bottom 半开边界，因此倒落段是 **25** 而不是 28；画布末 3 行透明。受光在左上，工程内不使用 `flip_h` 制造随机朝向。

## 引擎接入约定

- 四个可复用场景：`res://scenes/decorations/doric_column_{tall,broken,base,fallen}.tscn`。
- 根节点是 `Sprite2D`，`centered = true`，`scale = (1, 1)`，`texture_filter = 1`（Nearest），无脚本、无碰撞、无 `Area2D`、无受力逻辑。
- 根节点原点就是**脚底中心**接地点。由 `offset = canvas_size / 2 − foot_anchor` 得到：
  - 高柱 `(0, -54)`、断柱 `(0, -41)`、柱座 `(0, -12)`、倒落 `(0, -11)`。
- 在第一关 `World/Decorations` 下按实例位置摆放；实例 `z_index = -1`，位于玩家、石碑与机关后方。贴图仍按 1 源像素 = 1 逻辑像素显示。
- 位置全部存在于 `scenes/level_01.tscn`，运行时不重新生成、不随机重摆。可直接选择、拖动、复制或删除单个实例。
- 测试：`res://tests/test_doric_decorations.tscn` 会按 `source_manifest.json` 校验哈希、尺寸、alpha bbox、锚点和接地误差，并检查场景树里没有新增碰撞/触发/脚本。
