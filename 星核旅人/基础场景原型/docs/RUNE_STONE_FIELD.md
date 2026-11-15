# 仓记录入仓极性 → 符文石真实力场组件

本文只说明独立组件 `RuneStoneField`。仓数据、测试房布局、核心运输与“取核后保持最近极性直到下次存核改写”的策略由仓/链接层负责，不在本组件内实现。

## 1. 文件与所有权

- 脚本：`scripts/rune_stone_field.gd`
- 场景：`scenes/rune_stone_field.tscn`
- 测试：`tests/test_rune_stone_field.gd`、`tests/test_rune_stone_field.tscn`
- 日志：`tests/logs/rune_stone_field_test.log`
- 视觉子节点：复用 `scenes/rune_stone_visual.tscn`（`RuneStoneVisual`）

场景根为 `@tool` 的 `Node2D`，可直接拖入测试房或在编辑器中调整。组件没有实体球碰撞，也不会自行对玩家施加外力。

## 2. 必需接口

```gdscript
@tool
class_name RuneStoneField
extends Node2D

@export var initial_active: bool = true
@export var initial_positive: bool = true

signal polarity_committed(positive: bool)

func sample_field(
    player_center: Vector2,
    player_positive: bool,
    excluded_rid: RID = RID()
) -> Dictionary

func request_polarity(positive: bool) -> void
func is_activated() -> bool
func is_positive() -> bool
func cancel_pending_request() -> void
func reset_state() -> void
func set_debug_enabled(enabled: bool) -> void
```

`sample_field` 只返回以下四个键，不碰玩家/核的速度、外力和移动：

```gdscript
{
    "acceleration": Vector2,  # 世界坐标加速度，px/s^2
    "status": String,         # INACTIVE / ATTRACT / REPEL / OUT OF RANGE / BLOCKED / NEAR / STABLE
    "distance": float,        # 身体中心到石心的距离
    "blocked": bool,          # 中心连线是否被 layer 1 实体阻挡
}
```

调用方必须自行应用返回值，且全房间只能有一个合力入口：

```gdscript
var sample: Dictionary = stone.sample_field(
    player.global_position + BODY_CENTER_OFFSET,
    player.is_positive(),
    player.get_rid()
)
var acceleration: Vector2 = sample["acceleration"]
if not acceleration.is_zero_approx():
    player.apply_external_force(acceleration)
```

组件只影响玩家侧读数；星核不读取该组件，也不会被它推动。星核取核/存核的极性保持策略由仓与链接层实现。

## 3. Inspector 参数

| 属性 | 默认 | 说明 |
|---|---|---|
| `initial_active` | `true` | 初始是否已激活；`false` 显示同一石壳的暗裂纹、无提示、零力。`reset_state()` 恢复到此值。普通固定石保持 `true`，F7 记录测试房显式设为 `false` |
| `initial_positive` | `true` | 初始极性；`reset_state()` 恢复到此值；编辑器改动能立即预览 |
| `field_range` | `160.0` | 作用范围（px，身体中心到石心） |
| `inner_radius` | `16.0` | 内圈；此距离内平滑趋零 |
| `full_radius` | `52.0` | 达到满强度的距离 |
| `outer_fade` | `40.0` | 从 `range - outer_fade` 到 `range` 渐弱 |
| `full_acceleration` | `2400.0` | 满强度加速度，px/s^2 |
| `auto_hint_in_range` | `true` | 激活时 `sample_field` 进入范围自动显示视觉 +/-；未激活时永不显示 |

位置直接使用节点 `position`。所有参数都带 Inspector 约束与 setter 夹取，公式对异常半径也做了降级处理，不会产生 NaN。

## 4. 力公式与未激活

未激活检查优先于范围、遮挡和极性：

```text
if not is_activated():
    status = INACTIVE, acceleration = 0, blocked = false
```

因此玩家在范围内、范围外或任意极性下都不会得到力，采样也不会把石“唤醒”。`is_positive()` 此时只返回内部默认值，HUD/链接层必须先看 `is_activated()`，不能把默认值当成当前生效正/负极。

激活后的力公式与已批准的 F2 基准一致：

```text
distance = |field.global_position - player_center|
if distance >= field_range:
    OUT OF RANGE, acceleration = 0
if layer-1 ray from player_center to stone is blocked:
    BLOCKED, acceleration = 0
if distance <= 0.5:
    NEAR / STABLE, acceleration = 0

near_factor  = smoothstep(inner_radius, full_radius, distance)
outer_factor = 1 - smoothstep(field_range - outer_fade, field_range, distance)
strength     = near_factor * outer_factor

direction = normalize(stone - player_center)
same sign  -> direction = -direction   # 同号斥
opposite   -> direction unchanged     # 异号吸
acceleration = direction * full_acceleration * strength
```

- 零距/极近距不归一化零向量，返回有限零向量。
- 默认在约 122.6 px 处加速度约 2371 px/s²，仍高于重力 1100，可实际托举玩家。
- 只计算加速度，不改变速度、位置、核心或全局力。

## 5. 遮挡与 RID

中心连线使用 `PhysicsRayQueryParameters2D`，碰撞掩码固定为 **layer 1**：

- `collide_with_bodies = true`
- `collide_with_areas = false`
- 自动排除 `excluded_rid`（房/链接层应传玩家 `get_rid()`）
- 自动排除组件自身子树里的所有 `CollisionObject2D`，因此以后即使给石头加装饰碰撞，也不会把自身当成遮挡
- 射线从玩家中心到石心；在范围外或未激活时不查询；零距不查询

## 6. 首次激活与提交时序

`RuneStoneVisual` 默认 `energized = true`，保留旧纯视觉调用；未激活石显示概念 `sleep` 状态图（同一已批准壳与裂纹网络、暗芯、无金/青/紫光），不额外加石面刻印。亮态用概念 `gold`/`cyan` 整态图叠加，换极只改变该层 alpha，不改变 32×32 轮廓或裂纹位置。

`RuneStoneField.initial_active = false` 时：

1. `request_polarity(positive)` 启动“暗裂纹 → 目标颜色”的首次亮起，即使目标等于 `initial_positive` 也照常执行，不再走旧同极性 no-op。
2. 首次亮起期间 `is_activated()` 仍为 `false`；`sample_field` 始终返回 `INACTIVE` 和精确零力，`polarity_committed` 尚未发出。
3. 视觉 `transition_finished(positive)` 到达且对应最新请求后，字段才：
   - `_active = true`
   - 更新 `_positive`
   - 发出且只发出一次 `polarity_committed(positive)`
4. 激活后的异极 `request_polarity` 沿用旧时序：旧力保持到视觉结束，再提交新极性。
5. 已激活后的相同极性请求仍是 no-op：不重播转色、不重复发信号。
6. 新请求覆盖旧请求；旧目标的晚到完成会被忽略。
7. 新记录到达时可调用 `cancel_pending_request()`：取消视觉在途请求，恢复已提交外观（未激活则回暗裂纹），不改变已提交玩法极性、不发提交信号。旧回调不能激活石。
8. 暂停冻结视觉过渡和提交；暂停期间不会发出完成信号。
9. `reset_state()`：取消在途过渡，立即恢复 `initial_active` / `initial_positive`，不发旧完成，也不发合成提交信号。只用于 R/退出房间的初始恢复。

`show_polarity_hint`：激活时默认由 `sample_field` 在范围内显示、范围外隐藏；未激活时由视觉层直接抑制，即使外部把 flag 置 true 也不画 `+/-`。调用方手工控制使用：

```gdscript
stone.set_polarity_hint_visible(true)   # 接管（仍需已激活才显示）
stone.clear_polarity_hint_override()    # 恢复自动
```

视觉仍由 `RuneStoneVisual` 自己绘制；组件不烘焙提示、不旋转、不缩放石头。

## 7. F3 调试

房/链接层在 F3 时调用 `set_debug_enabled(true/false)`，组件绘制：

- 外圈 `field_range`
- 内圈 `inner_radius` 与满强度圈 `full_radius`（低透明度）
- 最近一次 `sample_field` 的中心连线（仅激活）
- 最近一次加速度方向箭头（仅激活且非零）
- 被遮挡时连线改为红色
- 未激活时只画范围与中性采样点，不画连线或假受力箭头

调试绘制只在启用时发生，不参与碰撞/力计算。

## 8. 集成边界

- **仓/链接层**：保存/读取极性、决定何时 `request_polarity`、取核后保持最近极性到下次存核、新记录取消旧在途请求、R/退出时调用 `reset_state`。
- **测试房唯一合力入口**：调用 `sample_field`，把 `acceleration` 交给 `player.apply_external_force`；不要把多个符石的力分别直接施加，应先自行合成或按设计选取。
- **组件**：自己的位置、范围、力、遮挡、激活/极性过渡提交、视觉提示与调试绘制。
- **不做**：星核运输、仓数据、门/关卡、全局 Q 反转、实体球碰撞、自动追踪玩家、对核心施力、存档/UI。

## 9. 验证

```powershell
& "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path `
  "D:\godot game\星核旅人\基础场景原型" res://tests/test_rune_stone_field.tscn
```

本轮结果：**229 通过、0 失败**，日志 `tests/logs/rune_stone_field_test.log`。独立测试覆盖：吸/斥符号、范围内外与零距、layer 1 遮挡、玩家 RID 排除、自身碰撞排除、过渡前后力符号、暂停冻结、重置取消、重入请求无旧信号、Inspector 参数、`@tool` 与无物理节点；以及 `initial_active = false` 的 INACTIVE/精确零力/不因采样激活、同默认色首次亮起、异色首次亮起、亮起中零力、结束时一次提交、覆盖/取消/暂停/重置后旧回调不激活、`reset_state` 回未激活。
