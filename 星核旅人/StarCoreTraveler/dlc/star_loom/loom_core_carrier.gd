class_name LoomCoreCarrier
extends Node2D

## The loom's approach now delivers a true star core, not a rune stone.
##
## The force rule is still the existing `RuneStoneField` sample: same phase
## pushes the core away, the other phase pulls it toward the player.  The
## chapter owns the single force entry point and turns the returned
## acceleration, negated, into the core's horizontal motion.  The core itself
## never applies force to the player.
##
## Presentation:
##   - the payload is `StarCoreVisual` in its POSITIVE (12-frame gold) state,
##     so it spins and reads as the project's star core, not a stone;
##   - the field child keeps owning the force sample, but its 32x32 rune-stone
##     visual is hidden at runtime: only the core is drawn;
##   - a small cyan field halo keeps the field's 澜相 readable while the core
##     itself stays gold;
##   - a floor shadow and a short 1 px trail make the core's hover and travel
##     legible without inventing a second art style.
##
## Gameplay is unchanged: the core slides on the floor between min_x and
## max_x.  Once seated in the bay it is held while the player is on its right,
## so walking on to the checkpoint cannot push it back out.  Pulling it back is
## done from the left with the opposite phase.  There is no solid body, so the
## player can never be pinched by it, launched by it, or use it as a platform
## over the 88 px gate.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const FLOOR_SHADOW: Color = Color(0.02, 0.03, 0.05, 0.42)
const TRAIL_LIFE: float = 0.30
const TRAIL_STEP: float = 5.0

@export var player_path: NodePath = NodePath("../Player")
@export var start_x: float = 270.0
@export var min_x: float = 250.0
@export var max_x: float = 330.0
@export var socket_x: float = 330.0
@export_range(1.0, 300.0, 1.0, "suffix:px/s") var move_speed: float = 72.0
@export_range(1.0, 4000.0, 10.0, "suffix:px/s^2") var move_accel: float = 420.0
## Stop short of the player so the core never sits on the body sprite.
@export_range(4.0, 80.0, 1.0, "suffix:px") var stop_distance: float = 26.0

var _player: Node2D = null
var _field: RuneStoneField = null
var _core_visual: StarCoreVisual = null
var _velocity_x: float = 0.0
var _time: float = 0.0
var _trail: Array[Dictionary] = []
var _last_trail_x: float = 0.0


func _ready() -> void:
	_field = get_node_or_null("Field") as RuneStoneField
	_core_visual = get_node_or_null("Core") as StarCoreVisual
	if _core_visual != null:
		_core_visual.state = StarCoreVisual.CoreState.POSITIVE
		_core_visual.show_state_badge = false
	_silence_rune_stone_visual()
	_resolve_player()
	global_position.x = clampf(global_position.x, min_x, max_x)
	_last_trail_x = global_position.x
	if _field != null:
		_field.reset_state()
	queue_redraw()


## The reused field prefab brings its own 32x32 rune-stone sprite.  The loom
## delivers a star core, so that sprite is hidden; the field's force sample and
## own state machine keep working unchanged.
func _silence_rune_stone_visual() -> void:
	if _field == null:
		return
	_field.auto_hint_in_range = false
	var rune_visual: RuneStoneVisual = _field.get_visual()
	if rune_visual != null:
		rune_visual.visible = false
		rune_visual.show_polarity_hint = false


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
	_time += delta
	_age_trail(delta)
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		if _player == null:
			queue_redraw()
			return

	# Seated and the body has moved past it: the bay holds the core.
	if is_on_socket() and _player.global_position.x > global_position.x + 8.0:
		_velocity_x = 0.0
		global_position.x = socket_x
		_update_trail()
		queue_redraw()
		return

	var player_center: Vector2 = _player.global_position + Vector2(0.0, -15.0)
	var sample: Dictionary = _field.sample_field(
		player_center, bool(_player.call("is_positive")), _player.get_rid()
	)
	var status: String = String(sample.get("status", ""))
	var desired: float = 0.0
	if status == RuneStoneField.STATUS_ATTRACT or status == RuneStoneField.STATUS_REPEL:
		var dx: float = global_position.x - _player.global_position.x
		# A pull stops before the body so the core does not sit on the sprite.
		# A push always moves away, so the same distance is not a dead zone
		# when the player reverses the phase to push the core back.
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
	_update_trail()
	queue_redraw()


func _age_trail(delta: float) -> void:
	for index: int in range(_trail.size() - 1, -1, -1):
		_trail[index]["age"] = float(_trail[index]["age"]) + delta
		if float(_trail[index]["age"]) >= TRAIL_LIFE:
			_trail.remove_at(index)


func _update_trail() -> void:
	if absf(global_position.x - _last_trail_x) < TRAIL_STEP:
		return
	_last_trail_x = global_position.x
	_trail.append({"pos": global_position, "age": 0.0})


func is_on_socket() -> bool:
	return absf(global_position.x - socket_x) <= 3.0


func get_velocity_x() -> float:
	return _velocity_x


func get_field() -> RuneStoneField:
	return _field


func get_core_visual() -> StarCoreVisual:
	return _core_visual


func get_player() -> Node2D:
	return _player


func get_start_x() -> float:
	return start_x


## Visual read for captures/tests: the payload really is the animated gold core.
func is_using_star_core_art() -> bool:
	return (
		_core_visual != null
		and _core_visual.is_using_animated_sheet()
		and _core_visual.has_art()
	)


## The field's own rune-stone sprite must never draw over the core.
func is_rune_stone_visual_hidden() -> bool:
	if _field == null:
		return false
	var rune_visual: RuneStoneVisual = _field.get_visual()
	return rune_visual == null or not rune_visual.visible


func reset_state() -> void:
	global_position = Vector2(start_x, global_position.y)
	_velocity_x = 0.0
	_trail.clear()
	_last_trail_x = start_x
	_time = 0.0
	if _field != null:
		_field.reset_state()
	_silence_rune_stone_visual()
	queue_redraw()


## Test / setup placement.  Gameplay never calls this; every real move still
## goes through tick_stone and the field sample.
func debug_set_x(value: float) -> void:
	global_position.x = clampf(value, min_x, max_x)
	_velocity_x = 0.0
	_last_trail_x = global_position.x
	queue_redraw()


func _draw() -> void:
	var field_positive: bool = _field != null and _field.is_positive()
	var accent: Color = GOLD if field_positive else CYAN
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.2)
	var seated: bool = is_on_socket()

	# Soft floor shadow: the core hovers over the floor so it never reads as a
	# solid stone rolling on the ground.  The 1 px gold tick is its reflection.
	draw_rect(Rect2(-8.0, 15.0, 16.0, 1.0), FLOOR_SHADOW)
	draw_rect(Rect2(-6.0, 16.0, 12.0, 1.0), Color(FLOOR_SHADOW, 0.26))
	draw_rect(Rect2(-3.0, 15.0, 6.0, 1.0), Color(GOLD, 0.16 + 0.08 * pulse))

	# Short trail: three fading 1 px gold points behind a moving core.
	for point: Dictionary in _trail:
		var age: float = float(point["age"])
		var fade: float = clampf(1.0 - age / TRAIL_LIFE, 0.0, 1.0)
		var local: Vector2 = to_local(point["pos"] as Vector2)
		draw_rect(Rect2(round(local.x) - 1.0, round(local.y) + 1.0, 2.0, 2.0),
			Color(GOLD, 0.22 * fade))
		draw_rect(Rect2(round(local.x), round(local.y), 1.0, 1.0),
			Color(1.0, 0.96, 0.82, 0.70 * fade))

	# Gold core halo: a thin 1 px ring plus a few rising sparks.  The core's
	# 12-frame sheet can reach a narrow edge-on frame, so the halo keeps the
	# "live core" read even in a still.
	var halo_alpha: float = 0.30 + 0.12 * pulse + (0.18 if seated else 0.0)
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0 + _time * 0.55
		draw_rect(
			Rect2(
				round(cos(angle) * 12.0),
				round(sin(angle) * 12.0),
				1.0, 1.0
			),
			Color(GOLD, halo_alpha)
		)
	for index: int in range(3):
		var rise: float = fmod(_time * 14.0 + float(index) * 6.0, 15.0)
		draw_rect(
			Rect2(
				-4.0 + float(index) * 4.0,
				-10.0 - rise,
				1.0, 1.0
			),
			Color(1.0, 0.97, 0.84, 0.42 + 0.30 * pulse)
		)

	# The field's phase stays readable as a dotted halo with a dark under-pixel
	# so the cyan reads against the blue window.  It is not a second body: no
	# collision, no range, no hint glyph.
	var dots: int = 28
	var field_alpha: float = 0.30 + 0.10 * pulse
	if seated:
		# The bay already owns a bright gold ring; keep the field sign present
		# but quiet so the lit chamber stays readable.
		field_alpha *= 0.45
	for index: int in range(dots):
		var angle: float = TAU * float(index) / float(dots) + _time * 0.18
		var radius: float = 22.0 + (1.0 if index % 2 == 0 else 0.0)
		var dot_x: float = round(cos(angle) * radius)
		var dot_y: float = round(sin(angle) * radius)
		draw_rect(Rect2(dot_x, dot_y + 1.0, 1.0, 1.0),
			Color(0.01, 0.02, 0.03, 0.50))
		draw_rect(Rect2(dot_x, dot_y, 1.0, 1.0),
			Color(accent, field_alpha))
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 - PI * 0.5
		var tick_x: float = round(cos(angle) * 25.0)
		var tick_y: float = round(sin(angle) * 25.0)
		draw_rect(Rect2(tick_x - 1.0, tick_y + 1.0, 2.0, 1.0),
			Color(0.01, 0.02, 0.03, 0.55))
		draw_rect(Rect2(tick_x - 1.0, tick_y, 2.0, 1.0),
			Color(accent, (0.62 + 0.20 * pulse) * (0.55 if seated else 1.0)))

	# Four tiny orbit sparks keep the 16x16 sheet legible as a live core even
	# when the spin reaches an edge-on frame.
	for index: int in range(4):
		var angle: float = _time * 1.9 + TAU * float(index) / 4.0
		draw_rect(
			Rect2(
				round(cos(angle) * 11.0),
				round(sin(angle) * 11.0),
				1.0, 1.0
			),
			Color(1.0, 0.98, 0.90, 0.55 + 0.25 * pulse)
		)

	if seated:
		# One extra gold ring when the core is held by the bay; the bay itself
		# owns the strong light.  This keeps the core visibly "live" inside.
		for index: int in range(16):
			var angle: float = TAU * float(index) / 16.0 - _time * 0.7
			draw_rect(
				Rect2(
					round(cos(angle) * 13.0),
					round(sin(angle) * 13.0),
					1.0, 1.0
				),
				Color(GOLD, 0.42 + 0.18 * pulse)
			)
