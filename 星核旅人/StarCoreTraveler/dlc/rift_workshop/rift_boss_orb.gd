extends Node2D

## Small draw-only child for the form-3 tracking mirror light.
##
## The boss body and its face plates are child sprites; a parent _draw() sits
## behind those opaque children, which hid the orb when it crossed the mirror.
## This node is a sibling above the body/plates (z=0 relative) and below the
## player (player z=6), so the orb stays readable over the mirror and still
## passes behind the character.
##
## It owns no collision and no timing: the boss writes the real global position
## and the trail offsets every physics tick.

var _active: bool = false
var _pulse: float = 0.0
var _trail_offsets: Array[Vector2] = []
var _draw_count: int = 0


func _ready() -> void:
	z_index = 0
	visible = false
	set_process(false)


func set_state(global_position_value: Vector2, trail_offsets: Array[Vector2], active: bool) -> void:
	global_position = global_position_value
	_trail_offsets = trail_offsets.duplicate()
	_active = active
	visible = active
	if active:
		set_process(true)
		queue_redraw()
	else:
		set_process(false)


func set_trail(trail_offsets: Array[Vector2]) -> void:
	_trail_offsets = trail_offsets.duplicate()
	queue_redraw()


func get_draw_count() -> int:
	return _draw_count


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	_draw_count += 1
	for index: int in range(_trail_offsets.size()):
		var point: Vector2 = _trail_offsets[index]
		var fade: float = float(index + 1) / float(maxi(_trail_offsets.size(), 1))
		draw_rect(
			Rect2(point - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
			Color(1.0, 0.55, 0.86, 0.24 * fade)
		)
	var halo: float = 9.0 + 1.2 * absf(sin(_pulse * 9.0))
	draw_circle(Vector2.ZERO, halo, Color(1.0, 0.42, 0.82, 0.26))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.62, 0.90, 0.94))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.99, 0.93, 0.98))
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(1.0, 0.90, 0.52, 0.98))
	for index: int in range(4):
		var angle: float = _pulse * 3.2 + float(index) * TAU / 4.0
		var shard: Vector2 = Vector2(cos(angle), sin(angle)) * 9.0
		draw_rect(
			Rect2(shard - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
			Color(1.0, 0.55, 0.86, 0.90) if index % 2 == 0 else Color(1.0, 0.99, 0.93, 0.90)
		)
