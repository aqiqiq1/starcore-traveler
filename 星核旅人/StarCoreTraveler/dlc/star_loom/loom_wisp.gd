class_name LoomWisp
extends Node2D

## "裂隙浮灵" summoned by the loom.
##
## A small drifting hazard, copied in behaviour only from the chapter-2 concept
## (it does not reference dlc/rift_workshop or its assets).  This is an original
## 16x16 generated sprite: a purple mass, one large white eye, three tendrils.
## It drifts toward the player at 44 px/s, bursts on contact for one hit, and
## dies to any J hit (the chapter resolves the swing).  Lifespan 12 s.

const SPRITE: Texture2D = preload(
	"res://dlc/star_loom/assets/sprites/loom_wisp_16x16_4f.png"
)
const SPEED: float = 44.0
const LIFETIME: float = 12.0
const PURPLE: Color = Color("#a874ff")

var _sprite: Sprite2D = null
var _player: L3Player = null
var _chapter: Node = null
var _time: float = 0.0
var _life: float = LIFETIME
var _alive: bool = true
var _burst: float = 0.0
var _dead: bool = false


func _ready() -> void:
	z_index = 6
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = SPRITE
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.centered = true
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	queue_redraw()


func setup(player: L3Player, chapter: Node) -> void:
	_player = player
	_chapter = chapter
	_time = 0.0
	_life = LIFETIME
	_alive = true
	_dead = false
	_burst = 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	if not _alive:
		_burst += delta
		if _burst >= 0.4:
			queue_free()
		queue_redraw()
		return
	_life -= delta
	if _life <= 0.0:
		kill()
		return
	if _player != null and is_instance_valid(_player):
		var target: Vector2 = _player.global_position + Vector2(0.0, -16.0)
		var direction: Vector2 = (target - global_position)
		if direction.length() > 1.0:
			global_position += direction.normalized() * SPEED * delta
	# A small sine bob keeps the silhouette alive without moving its hit box
	# far from what the player sees.
	if _sprite != null:
		_sprite.position = Vector2(0.0, sin(_time * 4.0) * 2.0)
		_sprite.frame = int(_time * 7.0) % 4
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
	if _chapter != null and is_instance_valid(_chapter) and _chapter.has_method("apply_enemy_hit"):
		_chapter.call("apply_enemy_hit", global_position)
	kill()


## Called by the chapter with the player's real swing snapshot.
func try_player_hit(player: Node2D, facing: int) -> bool:
	if not _alive or _dead:
		return false
	if player == null or not is_instance_valid(player):
		return false
	var direction: float = 1.0 if facing >= 0 else -1.0
	var origin_x: float = player.global_position.x + (2.0 if direction > 0.0 else -40.0)
	var attack_rect: Rect2 = Rect2(
		origin_x, player.global_position.y - 38.0, 38.0, 40.0
	)
	if not attack_rect.intersects(get_hit_rect()):
		return false
	kill()
	return true


func kill() -> void:
	if not _alive or _dead:
		return
	_alive = false
	_burst = 0.0
	if _sprite != null:
		_sprite.visible = false
	queue_redraw()


func is_alive() -> bool:
	return _alive and not _dead


func get_hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(14.0, 14.0), Vector2(28.0, 28.0))


func get_life_left() -> float:
	return _life


func _draw() -> void:
	if not _alive:
		var t: float = clampf(_burst / 0.4, 0.0, 1.0)
		if t >= 1.0:
			return
		var alpha: float = 1.0 - t
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, alpha))
		for index: int in range(8):
			var angle: float = float(index) * TAU / 8.0
			var radius: float = 4.0 + 20.0 * t
			draw_rect(
				Rect2(
					Vector2(cos(angle), sin(angle)) * radius - Vector2(1.0, 1.0),
					Vector2(2.0, 2.0)
				),
				Color(PURPLE, 0.85 * alpha)
			)
		return
	# Faint 1 px aura; purple is the "this is a rift creature" cue, not a phase.
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.4)
	for index: int in range(20):
		var angle: float = float(index) * TAU / 20.0
		draw_rect(
			Rect2(round(cos(angle) * 15.0), round(sin(angle) * 15.0), 1.0, 1.0),
			Color(PURPLE, 0.18 + 0.10 * pulse)
		)
