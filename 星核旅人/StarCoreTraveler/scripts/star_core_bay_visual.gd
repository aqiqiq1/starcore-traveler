@tool
class_name StarCoreBayVisual
extends Node2D

## Pure visual display for the base-game star-core bay (L2 / L3).
##
## The presentation is the shared DLC2/DLC3 bay look (`CoreBayLook`): the same
## 32x32 pedestal and glass PNGs, the low cold-stone plinth, the gold socket
## ring/cradle, the floor conduit, a 0.55 s white flash and rising sparks, plus
## the same insert/remove cues (`assets/audio/sfx/core_insert.wav` and
## `sfx/core_remove.wav`).
##
## Gameplay stays in StarCoreBayInteractable: this node owns no physics,
## collision, suction, pickup, storage or bay state machine. It only exposes
## the existing display toggle (`occupied`), the lock marker and the lid mask.
##
## Layer order: Base z=-1, the node's own bay look z=0, LockMark z=0 (a later
## child), Core z=1, Glass z=2.  The base must sit below the code-drawn plinth
## and niche so the gold rim reads on top of the stone.

const LOOK = preload("res://dlc/shared/core_delivery/core_bay_look.gd")
const SOURCE_SIZE: Vector2i = Vector2i(32, 32)
const BAY_RECT: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
## Existing 16x16 core, centered on this component's origin.
const CORE_RECT: Rect2 = Rect2(-8.0, -8.0, 16.0, 16.0)
## The pedestal starts at image y=24, which is local y=+8.
const PEDESTAL_TOP_Y: float = 8.0
## 4x3 lock mark on the plinth front-right (local px), same mark as before.
const LOCK_MARKER_RECT: Rect2 = Rect2(4.0, 11.0, 4.0, 3.0)

const BASE_TEXTURE_PATH: String = "res://assets/star_core_bay/star_core_bay_base.png"
const GLASS_TEXTURE_PATH: String = "res://assets/star_core_bay/star_core_bay_glass.png"
const CORE_SCENE_PATH: String = "res://scenes/star_core_visual.tscn"
const INSERT_SFX: String = "res://assets/audio/sfx/core_insert.wav"
const REMOVE_SFX: String = "res://assets/audio/sfx/core_remove.wav"
const BAY_FLASH_TIME: float = 0.55
const LIT_SPEED: float = 5.0
const GLASS_ALPHA: float = 0.92

## The lid is a hard, symmetric pixel mask over the existing 32x32 glass PNG.
const LID_TOP_CENTER: Vector2 = Vector2(15.5, 2.0)
const LID_MAX_DISTANCE: float = 26.0
const LID_SHADER_CODE: String = """
shader_type canvas_item;

uniform float open_progress : hint_range(0.0, 1.0) = 0.0;
uniform float top_y = 2.0;
uniform float max_distance = 26.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 p = UV * vec2(32.0, 32.0);
	float d = distance(p, vec2(15.5, top_y));
	float reveal = 1.0 - clamp(open_progress, 0.0, 1.0);
	float threshold = mix(max_distance + 0.01, -0.01, reveal);
	if (d < threshold) {
		discard;
	}
	COLOR = base;
	if (open_progress > 0.001 && open_progress < 0.999 && base.a > 0.0) {
		float edge = abs(d - threshold);
		if (edge < 1.1) {
			COLOR.rgb = mix(COLOR.rgb, vec3(0.95, 1.0, 1.0), 0.50);
		}
	}
}
"""

@export var occupied: bool = true:
	set(value):
		if occupied == value:
			return
		occupied = value
		if is_inside_tree():
			_on_occupied_changed(value)
		_refresh_visual()

@export var show_lock_marker: bool = true:
	set(value):
		show_lock_marker = value
		_refresh_visual()

var _base: Sprite2D
var _core: StarCoreVisual
var _glass: Sprite2D
var _lock_mark: StarCoreBayLockMark
var _lid_progress: float = 0.0
var _lid_target: float = 0.0
var _lid_speed: float = 4.0
var _lid_animating: bool = false
var _lit: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _sfx: AudioStreamPlayer = null
var _interactive_ready: bool = false
var _sfx_enabled: bool = true
static var _warned_missing: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_layers()
	_lit = 1.0 if occupied else 0.0
	_refresh_visual()
	_apply_lid_visual()
	_ensure_sfx()
	# The interactable applies its initial LOCKED/OPEN pose in the same frame;
	# that is not a pickup, so it must stay silent.
	call_deferred("_mark_interactive_ready")
	set_process(_lid_animating)


func _mark_interactive_ready() -> void:
	_interactive_ready = true


func _exit_tree() -> void:
	# Release the short seat cue so a headless test that toggles the bay and
	# quits cannot leave an AudioStreamPlayback in the engine at exit.
	if _sfx != null:
		_sfx.stop()
		_sfx.stream = null


func _ensure_sfx() -> void:
	if _sfx != null:
		return
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SeatSfx"
	_sfx.bus = "Master"
	add_child(_sfx)


func _on_occupied_changed(value: bool) -> void:
	if _interactive_ready:
		if value:
			_flash = 1.0
		if _sfx_enabled:
			_play_seat_sfx(value)
	set_process(true)
	queue_redraw()


func get_seat_sfx_path(seated: bool = true) -> String:
	return INSERT_SFX if seated else REMOVE_SFX


## Test/audit hook: keep the cue path above as the contract while skipping the
## one-shot playback (a headless asset audit should not leave an AudioStream
## playback alive at exit).
func set_sfx_enabled(value: bool) -> void:
	_sfx_enabled = value
	if not value and _sfx != null:
		_sfx.stop()
		_sfx.stream = null


func _play_seat_sfx(seated: bool) -> void:
	if _sfx == null:
		return
	var path: String = get_seat_sfx_path(seated)
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_sfx.stream = stream
	_sfx.play()


## Re-check the two bay PNGs and the core's texture.
func refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_layers()
	if _base != null:
		_base.texture = load_texture_safely(BASE_TEXTURE_PATH)
	if _glass != null:
		_glass.texture = load_texture_safely(GLASS_TEXTURE_PATH)
	if _core != null:
		_core.refresh()
	_refresh_visual()


static func load_texture_safely(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func get_source_size() -> Vector2i:
	return SOURCE_SIZE


func get_bay_rect() -> Rect2:
	return BAY_RECT


func get_core_rect() -> Rect2:
	return CORE_RECT


func get_pedestal_top_y() -> float:
	return PEDESTAL_TOP_Y


func get_lock_marker_rect() -> Rect2:
	return LOCK_MARKER_RECT


func get_base_sprite() -> Sprite2D:
	return _base


func get_core_visual() -> StarCoreVisual:
	return _core


func get_glass_sprite() -> Sprite2D:
	return _glass


func get_lock_marker() -> StarCoreBayLockMark:
	return _lock_mark


func get_lit_blend() -> float:
	return _lit


func get_flash_left() -> float:
	return _flash


## Opens from the top centre outward: the top disappears first, then the two
## sides descend/split toward the base.
func start_open(duration: float = 0.25) -> void:
	_lid_target = 1.0
	_lid_speed = 1.0 / maxf(duration, 0.01)
	_lid_animating = true
	set_process(true)


## Closes from the two lower sides upward along the dome rim.
func start_close(duration: float = 0.25) -> void:
	_lid_target = 0.0
	_lid_speed = 1.0 / maxf(duration, 0.01)
	_lid_animating = true
	set_process(true)


func set_lid_open_immediately(open: bool) -> void:
	_lid_animating = false
	_lid_progress = 1.0 if open else 0.0
	_apply_lid_visual()
	set_process(_should_process())


func stop_lid_animation() -> void:
	_lid_animating = false
	set_process(_should_process())


func _should_process() -> bool:
	var target_lit: float = 1.0 if occupied else 0.0
	return _lid_animating or _flash > 0.0 or not is_equal_approx(_lit, target_lit)


func is_lid_open() -> bool:
	return _lid_progress >= 0.999


func is_lid_closed() -> bool:
	return _lid_progress <= 0.001 and not _lid_animating


func is_lid_animating() -> bool:
	return _lid_animating


func get_lid_progress() -> float:
	return _lid_progress


func has_art() -> bool:
	return (
		_base != null and _base.texture != null
		and _glass != null and _glass.texture != null
	)


func get_missing_texture_paths() -> PackedStringArray:
	var missing: PackedStringArray = []
	if _base == null or _base.texture == null:
		missing.append(BASE_TEXTURE_PATH)
	if _glass == null or _glass.texture == null:
		missing.append(GLASS_TEXTURE_PATH)
	return missing


func is_lock_marker_visible() -> bool:
	return _lock_mark != null and _lock_mark.visible


func set_occupied(value: bool) -> void:
	occupied = value


func _refresh_visual() -> void:
	if not is_inside_tree():
		return
	_ensure_layers()
	# Instant brightness toggle, preserved from the old bay contract: an open,
	# empty bay is cold and dim; a stored core brings the stone up to full.
	if _base != null:
		_base.modulate = (
			Color.WHITE if occupied else Color(0.64, 0.68, 0.69, 1.0)
		)
	if _core != null:
		_core.visible = occupied
		_core.show_state_badge = false
	if _lock_mark != null:
		_lock_mark.visible = occupied and show_lock_marker
	_apply_lid_visual()
	queue_redraw()


func _ensure_layers() -> void:
	_base = get_node_or_null("Base") as Sprite2D
	if _base == null:
		_base = Sprite2D.new()
		_base.name = "Base"
		add_child(_base)
	_base.position = Vector2.ZERO
	_base.centered = true
	_base.scale = Vector2.ONE
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.z_index = -1
	if _base.texture == null:
		_base.texture = load_texture_safely(BASE_TEXTURE_PATH)
		if _base.texture == null:
			_warn_missing_once(BASE_TEXTURE_PATH)

	# Separate lock-mark child: same z as the look, added later, so it draws
	# above the pedestal/look and below the core/glass.
	_lock_mark = get_node_or_null("LockMark") as StarCoreBayLockMark
	if _lock_mark == null:
		_lock_mark = StarCoreBayLockMark.new()
		_lock_mark.name = "LockMark"
		add_child(_lock_mark)
	_lock_mark.position = Vector2.ZERO
	_lock_mark.z_index = 0
	_lock_mark.visible = occupied and show_lock_marker

	_core = get_node_or_null("Core") as StarCoreVisual
	if _core == null:
		var core_scene: PackedScene = load(CORE_SCENE_PATH) as PackedScene
		if core_scene != null:
			_core = core_scene.instantiate() as StarCoreVisual
			if _core != null:
				_core.name = "Core"
				add_child(_core)
				_core.state = StarCoreVisual.CoreState.LOCKED
	if _core != null:
		_core.position = Vector2.ZERO
		_core.scale = Vector2.ONE
		_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_core.z_index = 1
		_core.show_state_badge = false

	_glass = get_node_or_null("Glass") as Sprite2D
	if _glass == null:
		_glass = Sprite2D.new()
		_glass.name = "Glass"
		add_child(_glass)
	_glass.centered = true
	_glass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glass.z_index = 2
	if _glass.texture == null:
		_glass.texture = load_texture_safely(GLASS_TEXTURE_PATH)
		if _glass.texture == null:
			_warn_missing_once(GLASS_TEXTURE_PATH)
	_ensure_lid_material()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_time += delta
	var target_lit: float = 1.0 if occupied else 0.0
	_lit = move_toward(_lit, target_lit, LIT_SPEED * delta)
	_flash = maxf(_flash - delta / BAY_FLASH_TIME, 0.0)
	if _lid_animating:
		_lid_progress = move_toward(_lid_progress, _lid_target, _lid_speed * delta)
		_apply_lid_visual()
		if is_equal_approx(_lid_progress, _lid_target):
			_lid_animating = false
	if (
		not _lid_animating
		and _flash <= 0.0
		and is_equal_approx(_lit, target_lit)
	):
		set_process(false)
	queue_redraw()


func _apply_lid_visual() -> void:
	if _glass == null:
		return
	_glass.position = Vector2.ZERO
	_glass.scale = Vector2.ONE
	_glass.modulate = Color(0.88, 0.97, 1.0, GLASS_ALPHA)
	_glass.visible = _lid_progress < 0.999
	_ensure_lid_material()
	var material: ShaderMaterial = _glass.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("open_progress", _lid_progress)


func _ensure_lid_material() -> void:
	if _glass == null:
		return
	var material: ShaderMaterial = _glass.material as ShaderMaterial
	if material == null or material.shader == null:
		var shader: Shader = Shader.new()
		shader.code = LID_SHADER_CODE
		material = ShaderMaterial.new()
		material.shader = shader
		_glass.material = material


## Capture/test helper: set a specific mask progress without changing gameplay.
func set_lid_progress_for_capture(progress: float) -> void:
	_lid_animating = false
	_lid_progress = clampf(progress, 0.0, 1.0)
	_apply_lid_visual()
	set_process(_should_process())


## CPU mirror of the shader mask, used by symmetry/ordering assertions.
static func is_lid_mask_pixel_visible(open_progress: float, x: int, y: int) -> bool:
	var reveal: float = 1.0 - clampf(open_progress, 0.0, 1.0)
	var threshold: float = lerpf(LID_MAX_DISTANCE + 0.01, -0.01, reveal)
	var distance: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(LID_TOP_CENTER)
	return distance >= threshold


func _draw() -> void:
	LOOK.draw(self, Vector2.ZERO, _lit, _flash, _time)


func _warn_missing_once(path: String) -> void:
	if _warned_missing.has(path):
		return
	_warned_missing[path] = true
	push_warning(
		"StarCoreBayVisual: art not found or not imported: %s. "
		% path
		+ "The bay layer is left empty; no substitute PNG is generated."
	)
