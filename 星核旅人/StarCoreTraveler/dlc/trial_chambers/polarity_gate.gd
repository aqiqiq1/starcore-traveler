class_name PolarityGate
extends Node2D

## Trial-only polarity curtain.
##
## A vertical 8x88 light screen with two readable states:
##   gold  = 辉相 required, cyan = 澜相 required.
## The gate never reads input and never changes the player's phase.  It only
## compares the player's own is_positive() with required_positive:
##   - same phase  -> collision layer 0, the player may walk through;
##   - other phase -> collision layer 1, the gate is solid.
##
## Anti-pinch rule: while the player's body already overlaps the curtain the
## gate stays passable, even if the phase changes inside it.  The solid layer
## only returns after the body has fully left the 8 px band.  No teleport, no
## damage, no input injection.
##
## Presentation reference: Celeste Core Block hot/cold (whole-block colour
## change + central bright core, state read before detail).  Only that reading
## order is borrowed; the shape, palette, collision and behaviour are this
## project's own.  See 项目归档/玩法拓展_20261125/REF_POLARITY_GATE.md.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const DARK_EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const DARK_CAP: Color = Color(0.008, 0.022, 0.028, 0.92)
const OPEN_FIELD_ALPHA: float = 0.26
const CLOSED_FIELD_ALPHA: float = 0.66
## Three 1 px rising dashes inside the 8 px band.  Only the open state animates,
## so the curtain also reads as "alive / passable" by motion, not just by being
## dimmer.  Reference: Celeste Core Block / Dream Block frames showed that a
## pass-through read comes from motion clipped to the block's own interior, not
## from a larger exterior glow (see REFERENCE_PASS_CUE.md).
const OPEN_CUE_COUNT: int = 3
const OPEN_CUE_PERIOD: float = 2.2

@export var required_positive: bool = true:
	set(value):
		required_positive = value
		_open = _compute_open()
		_apply_collision()
		queue_redraw()
## Explicit player target.  Empty lets the gate resolve one from the parent at
## runtime (first child that exposes is_positive() and get_collision_size()).
@export var player_path: NodePath = NodePath()
@export var gate_width: float = 8.0
@export var gate_height: float = 88.0

var _player: Node2D = null
var _blocker: StaticBody2D = null
var _shape: CollisionShape2D = null
var _open: bool = false
## True only after the player has really entered the curtain while it was
## passable.  A blocked player pushing on the outside never sets this latch.
var _anti_pinch_latched: bool = false
var _time: float = 0.0


func _ready() -> void:
	_blocker = get_node_or_null("Blocker") as StaticBody2D
	_shape = get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
	_resolve_player()
	_open = _compute_open()
	_apply_collision()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_update_anti_pinch_latch()
	var open_now: bool = _compute_open()
	if open_now != _open:
		_open = open_now
		queue_redraw()
	_apply_collision()
	if open_now:
		# The rising dashes are the only continuously animated part.
		queue_redraw()


# --- public read API -------------------------------------------------------

## True while the curtain is passable for the player's current phase, or while
## the player's body is still inside it (anti-pinch).
func is_open() -> bool:
	return _compute_open()


func is_player_inside() -> bool:
	return _compute_inside()


func get_required_positive() -> bool:
	return required_positive


func is_blocking() -> bool:
	return not _compute_open()


## Collision layer of the solid blocker: 1 = solid, 0 = pass-through.
func get_collision_layer() -> int:
	if _blocker == null:
		return -1
	return _blocker.collision_layer


func get_gate_size() -> Vector2:
	return Vector2(gate_width, gate_height)


func get_gate_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-gate_width * 0.5, -gate_height),
		Vector2(gate_width, gate_height)
	)


func get_player_rect() -> Rect2:
	if _player == null or not is_instance_valid(_player):
		return Rect2()
	var size: Vector2 = Vector2(12.0, 30.0)
	if _player.has_method("get_collision_size"):
		size = _player.call("get_collision_size") as Vector2
	return Rect2(
		_player.global_position + Vector2(-size.x * 0.5, -size.y),
		size
	)


func get_state_name() -> String:
	return "open" if _compute_open() else "blocked"


# --- public write API (tests / level wiring) --------------------------------

func set_required_positive(value: bool) -> void:
	required_positive = value


func set_player_node(player: Node2D) -> void:
	_player = player
	_anti_pinch_latched = false
	_open = _compute_open()
	_apply_collision()
	queue_redraw()


# --- internals -------------------------------------------------------------

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		var target: Node = get_node_or_null(player_path)
		if target is Node2D:
			_player = target as Node2D
			return
	var parent: Node = get_parent()
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is Node2D and child.has_method("is_positive") \
				and child.has_method("get_collision_size"):
			_player = child as Node2D
			return


func _compute_open() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var player_positive: bool = bool(_player.call("is_positive"))
	if player_positive == required_positive:
		return true
	# Only a player who really entered while the curtain was passable keeps it
	# open.  A blocked player standing against the outside can never trigger
	# the anti-pinch path.
	return _anti_pinch_latched and _compute_inside()


func _update_anti_pinch_latch() -> void:
	if not _compute_inside():
		_anti_pinch_latched = false
		return
	if _player == null or not is_instance_valid(_player):
		return
	var same_phase: bool = bool(_player.call("is_positive")) == required_positive
	# `_open` is the previous frame's result: it is still true on the exact tick
	# the player changes phase inside the gate, so the latch has no one-frame
	# hole that could clamp the body.
	if same_phase or _open:
		_anti_pinch_latched = true


func _compute_inside() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	# Exact body/curtain overlap.  No outside margin: touching the closed gate
	# must not count as inside.
	return get_player_rect().intersects(get_gate_rect())


func _apply_collision() -> void:
	if _blocker == null:
		return
	var layer: int = 0 if _open else 1
	if _blocker.collision_layer != layer:
		_blocker.collision_layer = layer


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var half: float = gate_width * 0.5
	var color: Color = GOLD if required_positive else CYAN
	var open: bool = _open or _compute_open()
	var field_alpha: float = OPEN_FIELD_ALPHA if open else CLOSED_FIELD_ALPHA

	# 1 px dark border around the whole 8x88 screen.
	draw_rect(Rect2(-half, -gate_height, gate_width, gate_height), DARK_EDGE)
	var inner_x: float = -half + 1.0
	var inner_w: float = gate_width - 2.0
	var inner_h: float = gate_height - 2.0
	draw_rect(Rect2(inner_x, -gate_height + 1.0, inner_w, inner_h),
		Color(color, field_alpha))

	# Vertical light bands: darker at the sides, brighter toward the middle.
	for index: int in range(int(inner_w)):
		var column_x: float = inner_x + float(index)
		var distance: float = absf(column_x + 0.5)
		var band_alpha: float = field_alpha * (0.55 + 0.45 * (1.0 - distance / half))
		if open:
			band_alpha *= 0.55
		draw_rect(Rect2(column_x, -gate_height + 1.0, 1.0, inner_h),
			Color(color, clampf(band_alpha, 0.0, 1.0)))

	# Dark top and bottom caps keep the curtain from reading as a soft gradient.
	draw_rect(Rect2(inner_x, -gate_height + 1.0, inner_w, 7.0), DARK_CAP)
	draw_rect(Rect2(inner_x, -8.0, inner_w, 7.0), DARK_CAP)

	# Bright 1 px side rails: the silhouette reads in both states.
	var rail_alpha: float = 0.55 if open else 0.96
	draw_rect(Rect2(-half, -gate_height, 1.0, gate_height), Color(color, rail_alpha))
	draw_rect(Rect2(half - 1.0, -gate_height, 1.0, gate_height), Color(color, rail_alpha))

	# Closed field gets a few short horizontal spark ticks.  Open field keeps
	# the dim body but adds three slow rising dashes: motion is the passable
	# read, and it stays inside the 8 px band so it never looks like a new
	# obstacle outside the gate.
	if not open:
		for tick_y: float in [-66.0, -58.0, -30.0, -22.0, -14.0]:
			draw_rect(Rect2(-half + 1.0, tick_y, gate_width - 2.0, 1.0),
				Color(color.lightened(0.25), 0.72))
	else:
		var span: float = gate_height - 18.0
		for index: int in range(OPEN_CUE_COUNT):
			var phase: float = fmod(
				_time / OPEN_CUE_PERIOD + float(index) / float(OPEN_CUE_COUNT),
				1.0
			)
			var cue_y: float = -8.0 - phase * span
			var cue_alpha: float = 0.35 + 0.65 * sin(phase * PI)
			# A 4 px near-white dash + a 3 px arrow head: unmistakably
			# "flowing upwards" at 1x, still inside the 8 px curtain.
			draw_rect(Rect2(-2.0, round(cue_y), 4.0, 1.0),
				Color(1.0, 0.99, 0.94, cue_alpha))
			draw_rect(Rect2(-1.0, round(cue_y) - 2.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))
			draw_rect(Rect2(1.0, round(cue_y) - 2.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))
			draw_rect(Rect2(0.0, round(cue_y) - 3.0, 1.0, 1.0),
				Color(1.0, 1.0, 1.0, 0.8 * cue_alpha))

	# Central bright diamond core, shared by both phases.
	var core_y: float = -gate_height * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, core_y - 9.0),
			Vector2(7.0, core_y),
			Vector2(0.0, core_y + 9.0),
			Vector2(-7.0, core_y),
		]),
		Color(color, 0.18 if not open else 0.10)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, core_y - 5.0),
			Vector2(4.0, core_y),
			Vector2(0.0, core_y + 5.0),
			Vector2(-4.0, core_y),
		]),
		color.lerp(Color.WHITE, 0.42)
	)
	draw_rect(Rect2(-1.0, core_y - 1.0, 2.0, 2.0), color.lerp(Color.WHITE, 0.92))
