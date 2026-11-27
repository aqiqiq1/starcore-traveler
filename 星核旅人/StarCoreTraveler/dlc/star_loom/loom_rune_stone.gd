class_name LoomRuneStone
extends Node2D

## Movable rune stone for the loom approach.
##
## The visual and the field rules are the existing `RuneStoneField` prefab
## (32x32 stone, cyan/gold whole-state art, polar force sample).  The stone
## itself never applies force to the player; the chapter ups the field and uses
## the returned acceleration, negated, as the force on the stone:
##
##   same phase  -> stone is pushed away from the player
##   other phase -> stone is pulled toward the player
##
## The stone slides on the floor between min_x and max_x.  Once seated on the
## socket it is held there while the player is on its right, so simply walking
## on to the checkpoint does not push it back out.  Pulling it back is done from
## the left (the same side the player used to push it in); the field's own range
## and line-of-sight rules still decide when movement is possible, so a closed
## gate between the player and the stone blocks the field.  There is no solid
## body: the base rune stone has no ball collider either, and keeping it
## non-solid means the player can never be pinched by it or use it to jump over
## the 88 px gate.

@export var player_path: NodePath = NodePath("../Player")
@export var start_x: float = 270.0
@export var min_x: float = 250.0
@export var max_x: float = 330.0
@export var socket_x: float = 330.0
@export_range(1.0, 300.0, 1.0, "suffix:px/s") var move_speed: float = 72.0
@export_range(1.0, 4000.0, 10.0, "suffix:px/s^2") var move_accel: float = 420.0
## Stop short of the player so the stone never sits on the body sprite.
@export_range(4.0, 80.0, 1.0, "suffix:px") var stop_distance: float = 26.0

var _player: Node2D = null
var _field: RuneStoneField = null
var _velocity_x: float = 0.0


func _ready() -> void:
	_field = get_node_or_null("Field") as RuneStoneField
	_resolve_player()
	global_position.x = clampf(global_position.x, min_x, max_x)
	if _field != null:
		_field.reset_state()


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if player_path.is_empty():
		return
	_player = get_node_or_null(player_path) as Node2D


## Called by the chapter every physics tick.
func tick_stone(delta: float) -> void:
	if _field == null:
		return
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		if _player == null:
			return

	# Seated and the body has moved past it: the groove holds the stone.
	if is_on_socket() and _player.global_position.x > global_position.x + 8.0:
		_velocity_x = 0.0
		global_position.x = socket_x
		return

	var player_center: Vector2 = _player.global_position + Vector2(0.0, -15.0)
	var sample: Dictionary = _field.sample_field(
		player_center, bool(_player.call("is_positive")), _player.get_rid()
	)
	var status: String = String(sample.get("status", ""))
	var desired: float = 0.0
	if status == RuneStoneField.STATUS_ATTRACT or status == RuneStoneField.STATUS_REPEL:
		var dx: float = global_position.x - _player.global_position.x
		# A pull stops before the body so the stone does not sit on the sprite.
		# A push always moves away, so the same distance is not a dead zone
		# when the player reverses the phase to push the stone back.
		var pull_blocked: bool = (
			status == RuneStoneField.STATUS_ATTRACT
			and absf(dx) <= stop_distance
		)
		if not pull_blocked:
			var acceleration: Vector2 = sample.get("acceleration", Vector2.ZERO) as Vector2
			var strength: float = clampf(
				absf(acceleration.x) / maxf(_field.full_acceleration, 0.001), 0.0, 1.0
			)
			if absf(acceleration.x) > 0.001:
				desired = -signf(acceleration.x) * move_speed * strength

	_velocity_x = move_toward(_velocity_x, desired, move_accel * delta)
	var next_x: float = global_position.x + _velocity_x * delta
	var clamped: float = clampf(next_x, min_x, max_x)
	if not is_equal_approx(clamped, next_x):
		_velocity_x = 0.0
	global_position.x = clamped


func is_on_socket() -> bool:
	return absf(global_position.x - socket_x) <= 3.0


func get_velocity_x() -> float:
	return _velocity_x


func get_field() -> RuneStoneField:
	return _field


func get_player() -> Node2D:
	return _player


func get_start_x() -> float:
	return start_x


func reset_state() -> void:
	global_position = Vector2(start_x, global_position.y)
	_velocity_x = 0.0
	if _field != null:
		_field.reset_state()


## Test / setup placement.  Gameplay never calls this; every real move still
## goes through tick_stone and the field sample.
func debug_set_x(value: float) -> void:
	global_position.x = clampf(value, min_x, max_x)
	_velocity_x = 0.0
