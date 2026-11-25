class_name StarCoreCarrier
extends CharacterBody2D

## One movable star core for the interaction test room.
##
## The room applies a one-tick acceleration each physics tick (same idea as the
## anchor field) and this body adds gravity, ground damping, speed clamps and
## move_and_slide. It collides with terrain (layer 1) but is explicitly isolated
## from the player: the player's mask does not include the core layer and the
## room also installs a collision exception, so the player cannot push it.
##
## When grounded, the room projects the centre-line force to horizontal, so the
## core does not get launched upward by a player standing above it. Airborne
## movement still uses the full vector.

@export var max_speed: float = 120.0
@export var max_up_speed: float = 180.0
@export var max_fall_speed: float = 500.0
@export var gravity: float = 1100.0
@export var ground_drag: float = 420.0

@onready var visual: StarCoreVisual = $Visual
@onready var polarity_mark: PolarityBadge = $PolarityMark

var _active: bool = false
var _positive: bool = true
var _external_force: Vector2 = Vector2.ZERO
var _external_force_pending: bool = false
var _last_force: Vector2 = Vector2.ZERO


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_snap_length = 4.0
	floor_stop_on_slope = true
	visual.show_state_badge = false
	deactivate()


func activate_at(world_position: Vector2, positive: bool) -> void:
	_active = true
	_positive = positive
	global_position = world_position
	velocity = Vector2.ZERO
	_external_force = Vector2.ZERO
	_external_force_pending = false
	collision_layer = 4
	collision_mask = 1
	visible = true
	set_physics_process(true)
	visual.visible = true
	visual.show_state_badge = false
	visual.state = (
		StarCoreVisual.CoreState.POSITIVE if positive
		else StarCoreVisual.CoreState.NEGATIVE
	)
	visual.refresh()
	if polarity_mark != null:
		polarity_mark.visible = true
		polarity_mark.set_positive(positive)


func deactivate() -> void:
	_active = false
	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_external_force = Vector2.ZERO
	_external_force_pending = false
	if visual != null:
		visual.visible = false
	if polarity_mark != null:
		polarity_mark.visible = false


func is_active() -> bool:
	return _active


func is_positive() -> bool:
	return _positive


func get_core_state() -> StarCoreVisual.CoreState:
	return StarCoreVisual.CoreState.POSITIVE if _positive else StarCoreVisual.CoreState.NEGATIVE


func get_visual() -> StarCoreVisual:
	return visual


func apply_external_force(acceleration: Vector2) -> void:
	if not _active:
		return
	_external_force = acceleration
	_external_force_pending = true


func clear_external_force() -> void:
	_external_force = Vector2.ZERO
	_external_force_pending = false


func get_last_force() -> Vector2:
	return _last_force


func get_max_speed() -> float:
	return max_speed


func get_ground_drag() -> float:
	return ground_drag


func ignore_body(body: CollisionObject2D) -> void:
	if body != null:
		add_collision_exception_with(body)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	var assisted: bool = _external_force_pending
	_external_force_pending = false
	_last_force = _external_force if assisted else Vector2.ZERO

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if assisted:
		velocity += _external_force * delta

	if is_on_floor() and not assisted:
		velocity.x = move_toward(velocity.x, 0.0, ground_drag * delta)

	velocity.x = clampf(velocity.x, -max_speed, max_speed)
	velocity.y = clampf(velocity.y, -max_up_speed, max_fall_speed)
	move_and_slide()
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
