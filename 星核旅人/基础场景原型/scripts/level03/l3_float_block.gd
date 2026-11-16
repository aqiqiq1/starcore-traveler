class_name L3FloatBlock
extends AnimatableBody2D

## One floating stone with per-block, non-refreshable collapse.
##
## After the group rises, a block stays permanently stable until the *player*
## actually stands on its top. That first real standing starts this block's own
## countdown -> visual shake (visual only; collision does not jitter) -> drop.
## The drop removes the collision and lets the visual stone fall, so no invisible
## bridge is left. Unstepped blocks never time out. Rebuilding through the fixed
## device resets every block.

signal became_stable
signal countdown_started
signal started_shaking
signal dropped

const VARIANTS: Dictionary = {
	0: {"size": Vector2(64.0, 24.0), "block": preload("res://assets/level03_prototype/float_block_64.png"), "glow": preload("res://assets/level03_prototype/float_glow_64_8f.png")},
	1: {"size": Vector2(80.0, 28.0), "block": preload("res://assets/level03_prototype/float_block_80.png"), "glow": preload("res://assets/level03_prototype/float_glow_80_8f.png")},
	2: {"size": Vector2(96.0, 32.0), "block": preload("res://assets/level03_prototype/float_block_96.png"), "glow": preload("res://assets/level03_prototype/float_glow_96_8f.png")},
}

enum Phase { REST, DELAY, RISING, STABLE, COUNTDOWN, SHAKE, DROP, DROPPED }

@export_enum("64x24", "80x28", "96x32") var variant: int = 2
@export var rest_top: float = 348.0
@export var target_top: float = 222.0
@export var rise_time: float = 1.10
@export var countdown_time: float = 1.10
@export var shake_time: float = 0.35
@export var drop_time: float = 0.40

var _phase: Phase = Phase.REST
var _phase_time: float = 0.0
var _delay: float = 0.0
var _from_y: float = 0.0
var _to_y: float = 0.0
var _glow_time: float = 0.0
var _size: Vector2 = Vector2(96.0, 32.0)
var _sprite: Sprite2D = null
var _glow: Sprite2D = null
var _shape_node: CollisionShape2D = null
var _shape: RectangleShape2D = null
var _player: Node2D = null
var _triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	sync_to_physics = true
	position.y = rest_top
	_build_visuals()
	_build_collision()


func set_player_target(player: Node2D) -> void:
	_player = player


func _build_visuals() -> void:
	var data: Dictionary = VARIANTS.get(variant, VARIANTS[2])
	_size = data["size"] as Vector2
	_sprite = Sprite2D.new()
	_sprite.name = "Stone"
	_sprite.centered = false
	_sprite.texture = data["block"] as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 0
	add_child(_sprite)

	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.centered = false
	_glow.texture = data["glow"] as Texture2D
	_glow.hframes = 8
	_glow.vframes = 1
	_glow.frame = 0
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.z_index = 1
	_glow.visible = false
	add_child(_glow)


func _build_collision() -> void:
	_shape_node = CollisionShape2D.new()
	_shape_node.name = "CollisionShape2D"
	_shape = RectangleShape2D.new()
	_shape.size = _size
	_shape_node.shape = _shape
	_shape_node.position = _size * 0.5
	add_child(_shape_node)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.DELAY:
			_phase_time += delta
			if _phase_time >= _delay:
				_begin_rise_now()
		Phase.RISING:
			_phase_time += delta
			var t: float = clampf(_phase_time / maxf(rise_time, 0.01), 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			position.y = lerpf(_from_y, _to_y, eased)
			_glow_time += delta
			_glow.frame = mini(int(_glow_time * 12.0), 3)
			if t >= 1.0:
				position.y = _to_y
				_phase = Phase.STABLE
				_phase_time = 0.0
				collision_layer = 1
				_glow.visible = false
				became_stable.emit()
		Phase.STABLE:
			_check_player_standing()
		Phase.COUNTDOWN:
			_phase_time += delta
			_glow_time += delta
			_glow.frame = 4 + (int(_glow_time * 12.0) % 4)
			queue_redraw()
			if _phase_time >= countdown_time:
				_begin_shake()
		Phase.SHAKE:
			_phase_time += delta
			queue_redraw()
			var shake_index: int = int(_phase_time * 24.0) % 4
			var offsets: Array[float] = [0.0, -1.0, 1.0, 0.0]
			if _sprite != null:
				_sprite.position.x = offsets[shake_index]
			_glow_time += delta
			_glow.frame = 4 + (int(_glow_time * 14.0) % 4)
			if _phase_time >= shake_time:
				_begin_drop()
		Phase.DROP:
			_phase_time += delta
			var t: float = clampf(_phase_time / maxf(drop_time, 0.01), 0.0, 1.0)
			position.y = lerpf(_from_y, _to_y, t * t)
			if t >= 1.0:
				_phase = Phase.DROPPED
				_phase_time = 0.0
				if _glow != null:
					_glow.visible = false
		_:
			pass


func _draw() -> void:
	# Status first, no repeated text: a pulsing 7x9 warning glyph over the stone
	# plus a bright top edge while the countdown/shake runs. The collision never
	# jitters; only the visual sprite does.
	if _phase != Phase.COUNTDOWN and _phase != Phase.SHAKE:
		return
	var pulse: bool = fmod(_phase_time if _phase == Phase.SHAKE else _phase_time * 4.0, 0.24) < 0.14
	var alpha: float = 0.95 if pulse else 0.55
	# Keep the glyph off the player's body: it sits just inside the far end of
	# the stone, not under the character standing on the middle.
	var cx: float = _size.x - 7.0
	var base_y: float = -8.0 if pulse else -7.0
	var warn: Color = Color(1.0, 0.74, 0.30, alpha)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, base_y), Vector2(cx + 4.0, base_y + 7.0), Vector2(cx - 4.0, base_y + 7.0)
	]), Color(0.06, 0.03, 0.02, alpha))
	draw_polyline(PackedVector2Array([
		Vector2(cx, base_y), Vector2(cx + 4.0, base_y + 7.0),
		Vector2(cx - 4.0, base_y + 7.0), Vector2(cx, base_y)
	]), warn, 1.0)
	draw_rect(Rect2(Vector2(cx - 0.5, base_y + 2.5), Vector2(1.0, 2.0)), warn)
	draw_rect(Rect2(Vector2(cx - 0.5, base_y + 5.3), Vector2(1.0, 1.0)), warn)
	draw_line(Vector2(0.0, 0.5), Vector2(_size.x, 0.5), Color(warn, 0.8), 1.0)


func _check_player_standing() -> void:
	if _player == null or _triggered:
		return
	if not is_instance_valid(_player):
		return
	if not _player.is_on_floor():
		return
	var feet_y: float = _player.global_position.y
	if absf(feet_y - position.y) > 2.5:
		return
	var px: float = _player.global_position.x
	if px < position.x + 1.0 or px > position.x + _size.x - 1.0:
		return
	_triggered = true
	_start_countdown()
	queue_redraw()


func _start_countdown() -> void:
	_phase = Phase.COUNTDOWN
	_phase_time = 0.0
	_glow_time = 0.0
	if _glow != null:
		_glow.visible = true
		_glow.frame = 4
	countdown_started.emit()


func _begin_shake() -> void:
	_phase = Phase.SHAKE
	_phase_time = 0.0
	started_shaking.emit()


func _begin_drop() -> void:
	queue_redraw()
	_phase = Phase.DROP
	_phase_time = 0.0
	_from_y = position.y
	_to_y = rest_top
	collision_layer = 0
	if _sprite != null:
		_sprite.position.x = 0.0
	dropped.emit()


func _begin_rise_now() -> void:
	_phase = Phase.RISING
	_phase_time = 0.0
	_glow_time = 0.0
	_from_y = rest_top
	_to_y = target_top
	position.y = rest_top
	collision_layer = 1
	if _glow != null:
		_glow.visible = true
		_glow.frame = 0


func reset_for_cycle(delay: float = 0.0) -> void:
	_phase = Phase.DELAY
	_phase_time = 0.0
	_glow_time = 0.0
	_triggered = false
	_delay = maxf(delay, 0.0)
	_delay = delay
	position.y = rest_top
	collision_layer = 0
	if _sprite != null:
		_sprite.position.x = 0.0
	if _glow != null:
		_glow.visible = false


func reset_to_rest() -> void:
	_phase = Phase.REST
	_phase_time = 0.0
	_glow_time = 0.0
	_triggered = false
	position.y = rest_top
	collision_layer = 0
	if _sprite != null:
		_sprite.position.x = 0.0
	if _glow != null:
		_glow.visible = false


func is_stable() -> bool:
	return _phase == Phase.STABLE


func is_standing_triggered() -> bool:
	return _triggered


func is_gone() -> bool:
	return _phase == Phase.DROPPED


func get_top_y() -> float:
	return position.y


func get_block_width() -> float:
	return _size.x


func get_phase_label() -> String:
	match _phase:
		Phase.REST: return "REST"
		Phase.DELAY: return "DELAY"
		Phase.RISING: return "RISING"
		Phase.STABLE: return "STABLE"
		Phase.COUNTDOWN: return "COUNTDOWN"
		Phase.SHAKE: return "SHAKE"
		Phase.DROP: return "DROP"
		Phase.DROPPED: return "DROPPED"
		_: return "UNKNOWN"
