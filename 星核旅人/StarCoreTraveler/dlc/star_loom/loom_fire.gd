class_name LoomFire
extends Node2D

## City floor fire jets ("地砖喷焰").
##
## The chapter warns at the vent positions for 0.95 s (LoomFx), then spawns this
## node.  Two of the three vents erupt for 0.62 s; each column damages at most
## once.  Flames are drawn with integer rects (dark outline, warm body, pale
## core) and sit behind the player (z=4) so the body never disappears; the
## warning layer is above everything at z=9.

const ACTIVE_TIME: float = 0.85
const FLAME_HEIGHT: float = 56.0
const FLAME_HALF_WIDTH: float = 11.0
const WARM_DARK: Color = Color(0.48, 0.22, 0.10, 1.0)
const WARM: Color = Color(0.94, 0.60, 0.28, 1.0)
const WARM_LIGHT: Color = Color(1.0, 0.84, 0.52, 1.0)
const WHITE_HOT: Color = Color(1.0, 0.96, 0.82, 1.0)

var _points: Array[Vector2] = []
var _player: L3Player = null
var _chapter: Node = null
var _time: float = 0.0
var _hit: Array[bool] = []


func _ready() -> void:
	z_as_relative = false
	z_index = 4
	queue_redraw()


func setup(player: L3Player, chapter: Node, points: Array[Vector2]) -> void:
	_player = player
	_chapter = chapter
	_points = points.duplicate()
	_hit.clear()
	for _point: Vector2 in _points:
		_hit.append(false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= ACTIVE_TIME:
		queue_free()
		return
	_check_contact()
	queue_redraw()


func _check_contact() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_rect: Rect2 = Rect2(
		_player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0)
	)
	for index: int in range(_points.size()):
		if index >= _hit.size() or _hit[index]:
			continue
		if not get_flame_rect(_points[index]).intersects(player_rect):
			continue
		_hit[index] = true
		if _chapter != null and is_instance_valid(_chapter) and _chapter.has_method("apply_enemy_hit"):
			_chapter.call("apply_enemy_hit", _points[index] + Vector2(0.0, -24.0))


func get_flame_rect(point: Vector2) -> Rect2:
	return Rect2(
		Vector2(point.x - FLAME_HALF_WIDTH, point.y - FLAME_HEIGHT),
		Vector2(FLAME_HALF_WIDTH * 2.0, FLAME_HEIGHT)
	)


func get_points() -> Array[Vector2]:
	return _points


func _draw() -> void:
	var fade: float = clampf((ACTIVE_TIME - _time) / 0.12, 0.0, 1.0)
	for point: Vector2 in _points:
		_draw_column(point, fade)


func _draw_column(point: Vector2, fade: float) -> void:
	var base_y: float = point.y
	# Grate glow.
	draw_rect(
		Rect2(point.x - 14.0, base_y - 4.0, 28.0, 3.0),
		Color(WARM_DARK, 0.7 * fade)
	)
	# Three tongues with a shared dark silhouette; the tallest sits in the
	# middle so the column reads as one hazard, not a particle cloud.
	var tongues: Array[float] = [0.72, 1.0, 0.78]
	var offsets: Array[float] = [-6.0, 0.0, 6.0]
	for index: int in range(3):
		var tongue_x: float = point.x + offsets[index]
		var wobble: float = sin(_time * 24.0 + float(index) * 1.8) * 1.5
		var height: float = FLAME_HEIGHT * tongues[index]
		var half: float = 5.0 - float(index % 2)
		for step in range(int(height)):
			var y: float = base_y - float(step)
			var taper: float = half * (1.0 - float(step) / height * 0.55)
			var left: float = tongue_x + wobble * (float(step) / height) - taper
			var right: float = tongue_x + wobble * (float(step) / height) + taper
			# Outer dark orange edge, warm body, pale core every few rows.
			draw_rect(Rect2(left, y, maxf(right - left, 1.0), 1.0), Color(WARM_DARK, fade))
			draw_rect(
				Rect2(left + 1.0, y, maxf(right - left - 2.0, 1.0), 1.0),
				Color(WARM, 0.92 * fade)
			)
			if step % 3 == 0:
				draw_rect(
					Rect2(tongue_x + wobble * (float(step) / height) - 1.0, y, 2.0, 1.0),
					Color(WARM_LIGHT if step < height * 0.55 else WHITE_HOT, fade)
				)
	# A few 1 px sparks escaping the top.
	for index: int in range(4):
		var rise: float = fmod(_time * 46.0 + float(index) * 13.0, FLAME_HEIGHT + 8.0)
		draw_rect(
			Rect2(point.x - 8.0 + float(index) * 5.0, base_y - 18.0 - rise, 1.0, 1.0),
			Color(WARM_LIGHT, 0.55 * fade)
		)
