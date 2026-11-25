class_name LoomGear
extends Node2D

## Rolling brass gears from the two sides of the city hall.
##
## The chapter warns at both edges for 0.90 s, then spawns one gear at each side.
## They roll inward at 150 px/s; a jump clears their 36 px body.  Each gear
## applies at most one accepted hit and frees after crossing the hall.  z is
## absolute 5 (the player is also 5 but earlier in the tree), so the player
## silhouette stays on top of the gear.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/gear_36x36_4f.png"
)
const SPEED: float = 150.0
const GROUND_Y: float = 320.0

var _sprite: Sprite2D = null
var _player: L3Player = null
var _chapter: Node = null
var _direction: int = 1
var _time: float = 0.0
var _hit_player: bool = false
var _dead: bool = false


func _ready() -> void:
	z_as_relative = false
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.name = "Gear"
	_sprite.texture = SPRITE
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -18.0)
	add_child(_sprite)
	queue_redraw()


func setup(
	player: L3Player, chapter: Node, start_x: float, direction: int
) -> void:
	_player = player
	_chapter = chapter
	_direction = 1 if direction >= 0 else -1
	global_position = Vector2(start_x, GROUND_Y)
	_time = 0.0
	_hit_player = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	global_position.x += float(_direction) * SPEED * delta
	if _sprite != null:
		_sprite.frame = int(_time * 14.0) % 4
	queue_redraw()
	if not _hit_player:
		_check_contact()
	if global_position.x < -60.0 or global_position.x > 1020.0:
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
		_chapter.call("apply_enemy_hit", global_position)


func get_hit_rect() -> Rect2:
	return Rect2(
		Vector2(global_position.x - 17.0, GROUND_Y - 34.0), Vector2(34.0, 34.0)
	)


func has_hit_player() -> bool:
	return _hit_player


func get_direction() -> int:
	return _direction


func _draw() -> void:
	# Ground shadow and a three-pixel dust trail.
	draw_rect(Rect2(-15.0, -3.0, 30.0, 2.0), Color(0.06, 0.04, 0.05, 0.45))
	for index: int in range(3):
		var offset: float = -float(_direction) * (10.0 + float(index) * 5.0)
		draw_rect(
			Rect2(offset - 1.0, -4.0 - float(index), 2.0, 1.0),
			Color(0.48, 0.42, 0.34, 0.35 - float(index) * 0.08)
		)
