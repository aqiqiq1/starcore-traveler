class_name RiftDepthOverlay
extends ColorRect

## DLC2 far workshop-hall composite, film-safe.
##
## The approved Back sprite stays untouched underneath.  This 1880x360 overlay
## is a child of the Background CanvasLayer at the same 0.90 scroll factor; its
## mask is only the entry/bridge arch throats, so the stone frame, recess gap,
## inner lip, mirror hall and furnace breast remain exactly as approved.  The
## chapter holds it at zero strength during the opening film and fades it in
## after control returns.
##
## The deep image itself moves at 0.65: the sample offset is
##   round(scroll * 0.65) - round(scroll * 0.90)
## and is converted to whole 1880-px image pixels.  Camera zoom is never used.

const DEEP_WIDTH: float = 1880.0
const SHADER: Shader = preload("res://dlc/rift_workshop/rift_depth_overlay.gdshader")

@export var deep_texture: Texture2D
@export var depth_mask: Texture2D
@export var parallax_factor: float = 0.65
@export var wall_factor: float = 0.90
@export var max_scroll: float = 1240.0
@export var view_width: float = 640.0
@export var fade_in_time: float = 0.30

var _material: ShaderMaterial = null
var _camera: Camera2D = null
var _scroll: float = 0.0
var _strength: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	if deep_texture != null:
		_material.set_shader_parameter("deep_texture", deep_texture)
	if depth_mask != null:
		_material.set_shader_parameter("depth_mask", depth_mask)
	material = _material
	_camera = get_viewport().get_camera_2d()
	_apply_strength(0.0)
	_apply_scroll(0.0)
	if Engine.is_editor_hint():
		set_process(false)


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	if _camera != null:
		var centre_x: float = _camera.get_screen_center_position().x
		_apply_scroll(clampf(centre_x - view_width * 0.5, 0.0, max_scroll))
	if not is_equal_approx(_strength, _target):
		var step: float = maxf(delta, 0.0) / maxf(fade_in_time, 0.001)
		_strength = move_toward(_strength, _target, step)
		_apply_strength(_strength)


func _apply_scroll(scroll: float) -> void:
	_scroll = clampf(scroll, 0.0, max_scroll)
	if _material == null:
		return
	var pixel_offset: float = roundf(_scroll * parallax_factor) \
		- roundf(_scroll * wall_factor)
	_material.set_shader_parameter(
		"deep_shift", Vector2(pixel_offset / DEEP_WIDTH, 0.0)
	)


func _apply_strength(value: float) -> void:
	_strength = clampf(value, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter("strength", _strength)


## Called by the chapter just before the opening film starts.
func set_hidden_for_film() -> void:
	_target = 0.0
	_apply_strength(0.0)


## Called by the chapter when the film finishes or is skipped.
func show_after_film() -> void:
	_target = 1.0


## Capture/test hook.
func set_strength_for_capture(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)
	_apply_strength(_target)


func set_scroll_for_test(scroll: float) -> void:
	_apply_scroll(scroll)


func get_scroll() -> float:
	return _scroll


func get_strength() -> float:
	return _strength


func get_target_strength() -> float:
	return _target


func get_deep_pixel_offset() -> float:
	return roundf(_scroll * parallax_factor) - roundf(_scroll * wall_factor)


func get_shift_uv() -> Vector2:
	if _material == null:
		return Vector2.ZERO
	return _material.get_shader_parameter("deep_shift")


func get_factor() -> float:
	return parallax_factor


func get_wall_factor() -> float:
	return wall_factor


func has_material() -> bool:
	return _material != null
