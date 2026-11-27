class_name LoomGateProxy
extends Node2D

## Phase proxy for the second loom gate.
##
## `PolarityGate` decides whether it is passable by asking its `player_path`
## node for `is_positive()` and `get_collision_size()`.  The second gate is not
## opened by the player's own phase: it is opened while the delivered star core
## is held by the floor bay.  This invisible proxy follows the real player (so
## the gate's deny pulse, anti-pinch latch and body rect still use the real
## body) and reports the gate's virtual phase:
##
##   powered == false -> positive (the gate's opposite phase, so it is solid)
##   powered == true  -> negative (matches the moon gate, so it is passable)
##
## It owns no collision, no drawing and no gameplay state beyond this value.

@export var target_path: NodePath = NodePath("../Player")

var _target: Node2D = null
var _positive_override: bool = true


func _ready() -> void:
	_resolve_target()
	if _target != null:
		global_position = _target.global_position


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target):
		_resolve_target()
	if _target != null:
		global_position = _target.global_position


func _resolve_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	if target_path.is_empty():
		return
	_target = get_node_or_null(target_path) as Node2D


## Bind the real player directly (used by the chapter after resolving nodes).
func bind_target(target: Node2D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position


## `PolarityGate` contract.
func is_positive() -> bool:
	return _positive_override


func set_positive_override(value: bool) -> void:
	_positive_override = value


## `PolarityGate` contract: report the real body size so its deny/anti-pinch
## rect matches the body it is standing in for.
func get_collision_size() -> Vector2:
	if _target != null and is_instance_valid(_target) and _target.has_method("get_collision_size"):
		return _target.call("get_collision_size") as Vector2
	return Vector2(12.0, 30.0)


func get_target() -> Node2D:
	return _target
