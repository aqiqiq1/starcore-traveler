class_name IndoorAtmosphereBase
extends Node2D

## Shared rules for the two DLC indoor atmosphere overlays.
##
## The node sits in the world at z=10: in front of the world props and behind
## the HUD CanvasLayer (layer 10).  Subclasses only describe local puffs,
## embers or threads; this base owns the whole-pixel rounding, the player
## clearance and the hazard clearance.
##
## Player clearance follows the delivery spec:
##   * the drawn rect may never intersect the player's visual box expanded by
##     8 px;
##   * when the player is within 40 px, the whole layer fades out over 0.15 s.
## Hazard rects are supplied by the chapter and are never covered either.

const PLAYER_BOX_LOCAL: Rect2 = Rect2(-18.0, -36.0, 32.0, 37.0)
const PLAYER_CLEARANCE: float = 8.0
const PLAYER_FADE_DISTANCE: float = 40.0
const PLAYER_FADE_TIME: float = 0.15
const ALPHA_MIN: float = 0.12
const ALPHA_MAX: float = 0.22

@export var player_path: NodePath
## Foreground pieces set this true.  Atmosphere stays readable near the player
## but never draws over the clearance box; the explicit 40 px fade rule in the
## delivery notes applies to foreground.
@export var fade_near_player: bool = false

var _player: Node2D = null
var _player_clear: Rect2 = Rect2()
var _fade: float = 1.0
var _active_rects: Array[Rect2] = []
var _active_alphas: Array[float] = []
var _hazard_rects: Array[Rect2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Node2D
	set_process(true)


func _process(delta: float) -> void:
	_tick_player_clearance(delta)
	# Build the draw list from the same deterministic geometry every frame, so
	# the headless acceptance test sees exactly what the renderer will draw.
	_begin_draw()
	_rebuild_effects()
	queue_redraw()


## Subclasses fill the draw list here (after _begin_draw has cleared it).
func _rebuild_effects() -> void:
	pass


func _tick_player_clearance(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_fade = 1.0
		_player_clear = Rect2()
		return
	var feet: Vector2 = _player.global_position
	var box: Rect2 = Rect2(
		feet + PLAYER_BOX_LOCAL.position - Vector2(PLAYER_CLEARANCE, PLAYER_CLEARANCE),
		PLAYER_BOX_LOCAL.size + Vector2(PLAYER_CLEARANCE, PLAYER_CLEARANCE) * 2.0
	)
	_player_clear = box
	if not fade_near_player:
		_fade = 1.0
		return
	var bounds: Rect2 = get_effect_bounds()
	if bounds.size == Vector2.ZERO:
		_fade = 1.0
		return
	var distance: float = _distance_to_rect(bounds, box)
	var target: float = 0.0 if distance < PLAYER_FADE_DISTANCE else 1.0
	var step: float = maxf(delta, 0.0) / PLAYER_FADE_TIME
	_fade = move_toward(_fade, target, step)


func _distance_to_rect(a: Rect2, b: Rect2) -> float:
	if a.intersects(b):
		return 0.0
	var dx: float = 0.0
	var dy: float = 0.0
	if a.end.x < b.position.x:
		dx = b.position.x - a.end.x
	elif a.position.x > b.end.x:
		dx = a.position.x - b.end.x
	if a.end.y < b.position.y:
		dy = b.position.y - a.end.y
	elif a.position.y > b.end.y:
		dy = a.position.y - b.end.y
	return sqrt(dx * dx + dy * dy)


func _begin_draw() -> void:
	_active_rects.clear()
	_active_alphas.clear()


func _emit(rect: Rect2, alpha: float) -> bool:
	var value: float = clampf(alpha, ALPHA_MIN, ALPHA_MAX)
	if _fade <= 0.001:
		return false
	if _player_clear.size != Vector2.ZERO and rect.intersects(_player_clear):
		return false
	for hazard: Rect2 in _hazard_rects:
		if rect.intersects(hazard):
			return false
	_active_rects.append(rect)
	_active_alphas.append(value)
	return true


func _draw_alpha(base_alpha: float) -> float:
	return clampf(base_alpha * _fade, 0.0, ALPHA_MAX)


func set_hazard_rects(rects: Array[Rect2]) -> void:
	_hazard_rects = rects.duplicate()


func add_hazard_rect(rect: Rect2) -> void:
	_hazard_rects.append(rect)


func get_player_fade() -> float:
	return _fade


func get_player_clear_rect() -> Rect2:
	return _player_clear


func get_visible_rects() -> Array[Rect2]:
	return _active_rects.duplicate()


func get_visible_alphas() -> Array[float]:
	return _active_alphas.duplicate()


func get_hazard_rects() -> Array[Rect2]:
	return _hazard_rects.duplicate()


func get_alpha_bounds() -> Vector2:
	return Vector2(ALPHA_MIN, ALPHA_MAX)


## Optional; only used when fade_near_player is true (foreground).
func get_effect_bounds() -> Rect2:
	return Rect2()


func get_foreground_count() -> int:
	return 0
