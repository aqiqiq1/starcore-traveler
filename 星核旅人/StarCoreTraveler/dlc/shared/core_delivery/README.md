# 星核运送共享组件

DLC2「裂隙工坊」与 DLC3「星核织机」共用的星核/星核仓实现，2026-11-27 起
从 `dlc/star_loom/` 提到这里，避免两份实现。

## 文件

- `core_carrier.tscn` / `core_carrier.gd`：可推拉的 16×16 金色 `StarCoreVisual`
  星核。力样本来自子节点 `RuneStoneField`；同相斥、异相吸。根节点是没有碰撞体的
  `Node2D`，所以不能夹人、顶飞或当踏板。
- `core_bay.tscn` / `core_bay.gd`：现有 `star_core_bay_base/glass` 基座/玻璃罩 +
  低石座、暗龛口、金色核心环、槽唇和朝右短导线。空仓暗，入仓基座/玻璃/金环/
  导线亮起。
- `gate_power_proxy.gd`：给 `PolarityGate` 用的无绘制相位代理。章节把“仓里有核”
  写成 `set_positive_override(false)`，把“仓空”写成 `true`；门自己的阻挡、
  拒绝脉冲、防夹和绘制代码不改。

## 章节接入

1. 实例化 `CoreBay`，把 `CoreCarrier` 放在同一地面高度（DLC3 y=304，bay y=320）。
2. 设置 `start_x` / `min_x` / `max_x` / `socket_x` / `move_speed`。
3. 每物理帧调用 `carrier.tick_stone(delta)`，再用 `carrier.is_on_socket()` 调
   `bay.set_occupied()` 和代理的相位。
4. 星核入仓后章节自己决定门/检查点/事件；共享组件不持有门或关卡状态。

## 每章可调

`core_carrier.tscn` 的 `field_range_override`、`inner_radius_override`、
`full_radius_override`、`outer_fade_override`、`full_acceleration_override`
默认 `-1`，保持 DLC3 原有 `RuneStoneField` 数值。DLC2 的走廊更窄，使用
`120 / 8 / 24 / 24`，让同相推力在贴近玩家时仍能先于人物走速把核送出去。

## 约束

- 组件不读输入、不解锁 Q、不修改玩家相性。
- 星核/仓无碰撞体。
- `CoreDeliveryCarrier` 只有在星核入仓且玩家在核右侧时夹住星核（既有规则），
  用来防止过门后从远侧把核拉出造成软锁。
