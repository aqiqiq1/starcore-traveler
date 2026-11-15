# 逐帧胸口锚点表（唯一数据源：`scripts/player.gd`）

本原型验证了 6 个动作：**idle、walk、run、jump、fall、fall_loop**。`combo`、`design` 未使用。帧号在代码、测试、截图标签和本表中均为 **0-based**；HUD 右下角为了阅读方便使用 1-based 的 `FRAME n/total`。

`walk` 是默认移动状态（约 100 px/s，9 FPS，10 帧循环）；`run` 只由左 Shift 或 0.25 s 内同方向双击触发（约 160 px/s，14 FPS）。

## 1. 方法

1. 用 Python/Pillow 从 `individual_sheets/male_hero-*.png` 逐帧裁出 128×128 帧，放大并叠加 4/8/16 px 网格审看。
2. 在每帧的肩/围巾以下、腰带以上定位胸甲浅蓝白像素；将胸甲像素中心（帧内坐标）记录为锚点。没有用整身 bbox 中心、128 画布中心或 idle 的固定位置套所有帧。
3. 锚点以显式数组写入 `player.gd` 的 `IDLE_ANCHORS`、`WALK_ANCHORS`、`RUN_ANCHORS`、`JUMP_ANCHORS`、`FALL_ANCHORS`、`FALL_LOOP_ANCHORS`。数组长度与各自的 sheet 帧数相同：10/10/10/6/4/3，共 43 帧。
4. 用 `docs/anchor_audit.png` 做逐帧视觉审计；图中是源帧 + 实际 5×5 护符/11×11 光晕的叠加，**不是引擎截图**，并明确标注。
5. 用 headless 测试扫描每帧的中心像素：43/43 为不透明胸甲色，不是围巾洋红/皮肤色；同时检查所有 idle/walk 帧脚底基线为源帧 y=79，并确认 walk 锚点不是 run 锚点的复制。

## 2. 锚点数组（帧内 128×128 坐标，0-based）

### idle — 10 帧

| 帧 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| 锚点 | (64,63) | (64,63) | (64,63) | (64,64) | (64,64) | (64,64) | (64,64) | (64,64) | (64,64) | (64,63) |

### walk — 10 帧（默认移动）

| 帧 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| 锚点 | (64,62) | (64,62) | (63,60) | (64,60) | (64,61) | (62,61) | (64,60) | (64,60) | (64,59) | (64,60) |

### run — 10 帧

| 帧 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| 锚点 | (65,60) | (64,60) | (62,61) | (66,60) | (66,58) | (64,60) | (64,60) | (65,62) | (66,59) | (67,59) |

### jump — 6 帧

| 帧 | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| 锚点 | (63,63) | (63,59) | (62,58) | (63,59) | (63,59) | (62,59) |

### fall — 4 帧

| 帧 | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| 锚点 | (63,57) | (63,58) | (63,58) | (63,58) |

### fall_loop — 3 帧

| 帧 | 0 | 1 | 2 |
|---|---|---|---|
| 锚点 | (63,58) | (63,58) | (63,58) |

## 3. 叠放偏移

以 `anchor=(x,y)` 为胸甲像素中心，`centered=false` 的整数 top-left：

| 层 | 纹理 | 帧尺寸 | top-left | 相对锚点 | z_index（VisualRoot 内） |
|---|---|---|---|---|---|
| Glow | `glow_*_4f.png` | 11×11 | `(x-5, y-5)` | `(-5,-5)` | -1（角色后） |
| Talisman | `talisman_*.png` | 5×5 | `(x-2, y-2)` | `(-2,-2)` | 1（角色前） |
| SwitchRing | `switch_ring_*_4f.png` | 24×24 | `(x-12, y-12)` | `(-12,-12)` | 2（角色前，短时） |

- 角色帧画布以 `pivot=(59,79)` 对齐到 Player 根节点（脚底）。因此帧内坐标的节点位置 = `(anchor.x-59, anchor.y-79) + 层偏移`。
- `VisualRoot.scale.x` 随朝向取 `+1/-1`；护符、光晕、环和角色都在 VisualRoot 下，因此全部跟随左右转向并镜像位置。
- 头顶 +/− 标志在 Player 下、VisualRoot 外，不随镜像；HUD 是 CanvasLayer，不镜像。
- 光晕在角色后面；护符 5×5 叠在胸甲上；环是 24×24 的细线扩散，持续约 0.20 s。没有大面积染色/全屏 bloom。

## 4. 已验证与未验证

- **已验证**：idle、walk、run、jump、fall、fall_loop 的 43 个帧内锚点；43/43 中心像素为胸甲色，0 个落在围巾/皮肤；idle/walk 10 帧脚底基线一致；idle/walk/run 可见身体高度 33–38 px（不含围巾/透明边）；walk 与 run 锚点数组不同。
- **已验证（引擎内）**：旧 01–20 张 + 后补的 21/22 两张 walk 实际视口截图（21 右金、22 左青）。旧 01–20 是加入 walk 之前、用 `run` 定帧的截图，HUD 无 Shift 提示，仍有效于动画/护符几何，但不代表当前默认操作；`screenshots/README.md` 已明确标注。
- **未验证**：combo、攻击、其他角色/动作；高 DPI/4K 非整数缩放；实际发布授权。

## 5. 复现检查

```powershell
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path "D:\godot game\星核旅人\基础场景原型" res://tests/test_runner.tscn
```

测试日志应包含：

```text
[PASS] all anchors land on opaque chest armor, not scarf/skin  (43/43 passed)
[PASS] all idle source frames share the foot baseline y=79
[PASS] all walk source frames share the foot baseline y=79
[PASS] walk uses its own anchors, not the run anchor set
[PASS] idle/walk/run visible body height stays around 33-38 px
```
