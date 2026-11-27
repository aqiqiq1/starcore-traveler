class_name LoomDepthOverlay
extends ColorRect

## DLC3 far-loom-hall composite, film-safe.
##
## The approved city wall stays untouched underneath.  This 960x360 world
## overlay samples the far hall only where the apse/door mask is opaque, so
## the three cloud-sea windows, frames, bars, accents and sill remain exactly
## as approved.  The overlay starts at full strength for tests and direct
## gameplay captures; the chapter drops it to zero while the opening film runs,
## then fades it back over 0.30 s after control returns.  The film therefore
## keeps its original sky windows.
##
## Parallax is baked into the shader sample offset: the deep content moves at
## 0.65 while the wall moves at 1.0.  The offset is rounded to a whole deep
## texture pixel every frame, and camera zoom is never applied.

const DEEP_WIDTH: float = 1280.0
const SHADER: Shader = preload("res://dlc/star_loom/loom_depth_overlay.gdshader")

@export var deep_texture: Texture2D
@export var depth_mask: Texture2D
@export var parallax_factor: float = 0.65
@export var max_scroll: float = 320.0
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
	# Default off.  The chapter turns it on immediately when no film will play,
	# and fades it in when the film finishes; this avoids a one-frame flash of
	# the deep windows before the film's first frame.
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
	# Anchor the deep image to a screen-fixed offset of
	# -round(scroll * factor), then convert that to an offset in the wall's
	# local UV: sample = round(scroll * factor) - scroll.  The deep content
	# therefore moves at 0.65 of the camera, with a whole-pixel offset.
	var pixel_offset: float = roundf(_scroll * parallax_factor) - _scroll
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
	return roundf(_scroll * parallax_factor) - _scroll


func get_expected_pixel_offset() -> float:
	return roundf(_scroll * parallax_factor) - _scroll


func get_shift_uv() -> Vector2:
	if _material == null:
		return Vector2.ZERO
	return _material.get_shader_parameter("deep_shift")


func get_factor() -> float:
	return parallax_factor


func get_layer_position() -> Vector2:
	return position


func has_material() -> bool:
	return _material != null
