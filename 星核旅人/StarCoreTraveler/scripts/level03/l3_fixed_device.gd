class_name L3FixedDevice
extends Node2D

## Fixed stone device with its own colourless core. It is not a star-core bay:
## E only changes this device's internal core from the colourless inactive look
## to the purple stable look. The transport core is never read, moved or
## consumed here.

signal activated

const INACTIVE_TEXTURE: Texture2D = preload(
	"res://assets/level03_prototype/fixed_core_inactive.png"
)
const ACTIVE_TEXTURE: Texture2D = preload(
	"res://assets/level03_prototype/fixed_core_active.png"
)
const FOOT_ANCHOR: Vector2 = Vector2(24.0, 39.0)

@export var interaction_range: float = 46.0
@export var foot_y: float = 210.0

var _sprite: Sprite2D = null
var _active: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "FixedCore"
	_sprite.centered = false
	_sprite.offset = -FOOT_ANCHOR
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = INACTIVE_TEXTURE
	add_child(_sprite)
	position.y = foot_y
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += delta
	# Restrained integer-pixel breathing of the whole shell; the purple core
	# texture itself is unchanged.
	var pulse: int = 0 if fmod(_pulse_time, 1.6) < 1.1 else 1
	_sprite.position.y = -float(pulse)


func activate() -> void:
	if _active:
		return
	_active = true
	_sprite.texture = ACTIVE_TEXTURE
	_sprite.position = Vector2.ZERO
	activated.emit()


func reset_state() -> void:
	_active = false
	_pulse_time = 0.0
	if _sprite != null:
		_sprite.texture = INACTIVE_TEXTURE
		_sprite.position = Vector2.ZERO


func is_active() -> bool:
	return _active


func get_interaction_center() -> Vector2:
	return global_position + Vector2(0.0, -20.0)


func is_player_in_range(player_position: Vector2) -> bool:
	return global_position.distance_to(player_position + Vector2(0.0, -15.0)) <= interaction_range


func get_texture_path() -> String:
	return _sprite.texture.resource_path if _sprite != null and _sprite.texture != null else ""
