class_name LoomSweep
extends Node2D

## Telegraphed horizontal light band ("横扫光带").
##
## The chapter holds the warning for 0.65 s before this node is created; the
## band then travels right-to-left across the 960 px hall at 210 px/s.  It is
## 22 px wide and 50 px tall above the floor, so a grounded player is hit and a
## jump clears it.  Damage is applied at most once.

const WIDTH: float = 22.0
const HEIGHT: float = 50.0
const SPEED: float = 210.0
const PURPLE: Color = Color("#a874ff")

var _player: L3Player = null
var _chapter: Node = null
var _direction: int = -1
var _hit_player: bool = false
var _time: float = 0.0
var _dead: bool = false


func _ready() -> void:
	z_index = 8
	queue_redraw()


func setup(
	player: L3Player, chapter: Node, start_x: float, direction: int
) -> void:
	_player = player
	_chapter = chapter
	_direction = 1 if direction >= 0 else -1
	global_position = Vector2(start_x, 320.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	global_position.x += float(_direction) * SPEED * delta
	queue_redraw()
	if not _hit_player:
		_check_contact()
	if global_position.x < -50.0 or global_position.x > 1010.0:
		queue_free()


func _check_contact() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_rect: Rect2 = Rect2(
		_player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0)
	)
	if not get_hit_rect().intersects(player_rect):
		return
	_hit_player = true
	if _chapter != null and is_instance_valid(_chapter) and _chapter.has_method("apply_enemy_hit"):
		_chapter.call("apply_enemy_hit", Vector2(global_position.x, 300.0))


func get_hit_rect() -> Rect2:
	return Rect2(
		Vector2(global_position.x - WIDTH * 0.5, 320.0 - HEIGHT),
		Vector2(WIDTH, HEIGHT)
	)


func has_hit_player() -> bool:
	return _hit_player


func get_direction() -> int:
	return _direction


func _draw() -> void:
	var left: float = -WIDTH * 0.5
	var top: float = -HEIGHT
	# Body: translucent purple with a near-white 1 px edge; no full-screen wash.
	draw_rect(Rect2(left, top, WIDTH, HEIGHT), Color(PURPLE, 0.34))
	draw_rect(Rect2(left, top, 1.0, HEIGHT), Color(1.0, 0.96, 0.86, 0.9))
	draw_rect(Rect2(-left - 1.0, top, 1.0, HEIGHT), Color(1.0, 0.96, 0.86, 0.9))
	draw_rect(Rect2(left, top, WIDTH, 1.0), Color(1.0, 0.96, 0.86, 0.9))
	# Three diagonal strands show the direction of travel.
	var phase: int = int(_time * 18.0) % 12
	for row in range(0, int(HEIGHT), 12):
		var y: float = top + float(row) + float(phase)
		if y >= 0.0:
			continue
		draw_rect(
			Rect2(left + 4.0, y, WIDTH - 8.0, 1.0),
			Color(0.88, 0.80, 1.0, 0.35)
		)
	# Three chevrons above the band, pointing the way it moves.
	var tip_x: float = -8.0 if _direction < 0 else 8.0
	for index: int in range(3):
		var y2: float = top - 5.0 - float(index) * 5.0
		var x2: float = tip_x + float(_direction) * float(index) * 2.0
		draw_rect(Rect2(x2 - 3.0, y2, 7.0, 1.0), Color(PURPLE, 0.9))
		draw_rect(Rect2(x2 - 2.0, y2 - 1.0, 1.0, 1.0), Color(PURPLE, 0.7))
		draw_rect(Rect2(x2 + 2.0, y2 - 1.0, 1.0, 1.0), Color(PURPLE, 0.7))
