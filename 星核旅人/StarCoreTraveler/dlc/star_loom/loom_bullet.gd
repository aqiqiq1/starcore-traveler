class_name LoomBullet
extends Node2D

## Slow homing bolt fired by the loom core.
##
## The chapter shows a >=0.55 s warning at the muzzle before the bolt exists.
## The bolt then chases the player's body centre with a capped turn rate, so it
## can be outrun or circled, and disappears on contact or after 10 s.  It never
## uses a screen-wide effect: one 12x12 generated iron-cased bolt, a three-pixel
## trail and one dark outline.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/city/loom_bolt_city_12x12_2f.png"
)
const SPEED: float = 70.0
const TURN_RATE: float = 0.85
const LIFETIME: float = 10.0
const PURPLE: Color = Color("#a874ff")

var _sprite: Sprite2D = null
var _player: L3Player = null
var _chapter: Node = null
var _velocity: Vector2 = Vector2.LEFT * SPEED
var _life: float = LIFETIME
var _time: float = 0.0
var _dead: bool = false


func _ready() -> void:
	z_index = 7
	_sprite = Sprite2D.new()
	_sprite.name = "Bolt"
	_sprite.texture = SPRITE
	_sprite.hframes = 2
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	queue_redraw()


## `direction` is the initial travel direction (already aimed at the player with
## a small spread by the chapter).
func setup(player: L3Player, chapter: Node, direction: Vector2) -> void:
	_player = player
	_chapter = chapter
	_velocity = direction.normalized() * SPEED
	if _velocity == Vector2.ZERO:
		_velocity = Vector2.LEFT * SPEED


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _player != null and is_instance_valid(_player):
		var target: Vector2 = _player.global_position + Vector2(0.0, -15.0)
		var desired: Vector2 = (target - global_position)
		if desired.length_squared() > 1.0:
			var desired_angle: float = desired.angle()
			var diff: float = wrapf(desired_angle - _velocity.angle(), -PI, PI)
			var turn: float = clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
			_velocity = Vector2.from_angle(_velocity.angle() + turn) * SPEED
	global_position += _velocity * delta
	if _sprite != null:
		_sprite.frame = int(_time * 8.0) % 2
	queue_redraw()
	_check_contact()


func _check_contact() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var player_rect: Rect2 = Rect2(
		_player.global_position + Vector2(-6.0, -30.0), Vector2(12.0, 30.0)
	)
	if not get_hit_rect().intersects(player_rect):
		return
	_dead = true
	if _chapter != null and is_instance_valid(_chapter) and _chapter.has_method("apply_enemy_hit"):
		_chapter.call("apply_enemy_hit", global_position)
	queue_free()


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(4.5, 4.5), Vector2(9.0, 9.0))


func get_velocity() -> Vector2:
	return _velocity


func get_life_left() -> float:
	return _life


func _draw() -> void:
	var back: Vector2 = -_velocity.normalized()
	for index: int in range(3):
		var offset: Vector2 = back * (5.0 + float(index) * 3.0)
		var size: float = 2.0 - float(index) * 0.5
		draw_rect(
			Rect2(offset - Vector2(size * 0.5, size * 0.5), Vector2(size, size)),
			Color(PURPLE, 0.34 - float(index) * 0.09)
		)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.8))
