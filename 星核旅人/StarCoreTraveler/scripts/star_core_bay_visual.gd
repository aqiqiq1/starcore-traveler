@tool
class_name StarCoreBayVisual
extends Node2D

## Pure visual display for the first-pass 32x32 star-core bay.
##
## This component owns no physics, collision, suction, pickup, storage,
## retrieval, or bay state machine. It layers four visual pieces around the
## same origin:
##
##   Base     (z=1, 32x32 white stone pedestal, rear)
##   LockMark (z=1, separate child after Base, code-drawn 4x3 mark)
##   Core     (z=2, existing 16x16 purple StarCoreVisual, middle)
##   Glass    (z=3, 32x32 pale-cyan dome, front)
##
## The core sits at (0,0) and its 16x16 rect ends exactly where the pedestal
## starts, so it never covers the base. The glass PNG is fully transparent over
## that same 16x16 rect, so the core always shows through.
##
## The lid is a CanvasItem shader mask over the original glass PNG. Closing
## reveals the lower sides first along the dome arc and meets at the top centre
## last; opening is the exact reverse. The glass keeps its 1:1 transform and
## colours, so this is not a scale.y squash or a uniform alpha fade.
##
## `occupied` is a display toggle only: false hides the core and the code-drawn
## lock mark. `start_open`/`start_close` only animate the glass mask; the
## gameplay LOCKED/OPENING/OPEN/CLOSING state lives in StarCoreBayInteractable.
##
## The core's own bottom-right state badge is disabled by default because it
## would poke into the pedestal. A 4x3 gold lock mark is drawn by a separate
## child node (StarCoreBayLockMark) on the pedestal's front-right instead; it is
## intentionally not baked into the PNG, so the empty bay has no lock.
##
## All z indices are non-negative: Base=1, LockMark=1, Core=2, Glass=3. A
## negative Base z can fall behind a preview/UI Control's own background, which
## makes the white pedestal disappear while the glass and core still show.

const SOURCE_SIZE: Vector2i = Vector2i(32, 32)
const BAY_RECT: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
## Existing 16x16 core, centered on this component's origin.
const CORE_RECT: Rect2 = Rect2(-8.0, -8.0, 16.0, 16.0)
## The pedestal starts at image y=24, which is local y=+8.
const PEDESTAL_TOP_Y: float = 8.0
## 4x3 lock mark on the pedestal front-right (image x=20..23, y=27..29).
const LOCK_MARKER_RECT: Rect2 = Rect2(4.0, 11.0, 4.0, 3.0)

const BASE_TEXTURE_PATH: String = "res://assets/star_core_bay/star_core_bay_base.png"
const GLASS_TEXTURE_PATH: String = "res://assets/star_core_bay/star_core_bay_glass.png"
const CORE_SCENE_PATH: String = "res://scenes/star_core_visual.tscn"

## The lid is a hard, symmetric pixel mask over the existing 32x32 glass PNG.
## Closing reveals the lower side walls first and the top centre last; opening
## is the exact reverse. No scale.y squash and no uniform alpha fade are used.
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
	// A one-pixel bright leading edge makes the two closing sides readable at
	// native 32x32 size. It is derived from the mask, not a second animation.
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
static var _warned_missing: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_layers()
	_refresh_visual()
	_apply_lid_visual()
	set_process(_lid_animating)


## Re-check the two bay PNGs and the core's texture. Useful after importing new
## art while the editor has had this scene open the whole time.
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


## Opens from the top centre outward: the top disappears first, then the two
## sides descend/split toward the base. The visual core and lock marker are
## controlled separately by the caller.
func start_open(duration: float = 0.25) -> void:
	_lid_target = 1.0
	_lid_speed = 1.0 / maxf(duration, 0.01)
	_lid_animating = true
	set_process(true)


## Closes from the two lower sides upward along the dome rim, meeting at the
## top centre last.
func start_close(duration: float = 0.25) -> void:
	_lid_target = 0.0
	_lid_speed = 1.0 / maxf(duration, 0.01)
	_lid_animating = true
	set_process(true)


## Snaps the lid without animating. Keeps the old static occupied API intact.
func set_lid_open_immediately(open: bool) -> void:
	_lid_animating = false
	set_process(false)
	_lid_progress = 1.0 if open else 0.0
	_apply_lid_visual()


func stop_lid_animation() -> void:
	_lid_animating = false
	set_process(false)


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
	# An open, empty bay is cold and dim; a stored core brings the stone and
	# its gold socket up to full brightness.  This is a display modulation
	# only, not a gameplay state or collision change.
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


func _ensure_layers() -> void:
	# Base (rear). All bay z indices are non-negative: Base=1, LockMark=1,
	# Core=2, Glass=3. A negative Base z could fall behind a preview/UI Control's
	# own background and make the white pedestal disappear.
	_base = get_node_or_null("Base") as Sprite2D
	if _base == null:
		_base = Sprite2D.new()
		_base.name = "Base"
		add_child(_base)
	_base.position = Vector2.ZERO
	_base.centered = true
	_base.scale = Vector2.ONE
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.z_index = 1
	if _base.texture == null:
		_base.texture = load_texture_safely(BASE_TEXTURE_PATH)
		if _base.texture == null:
			_warn_missing_once(BASE_TEXTURE_PATH)

	# Separate lock-mark child: same z as Base but a later sibling, so it draws
	# above the pedestal and below Core/Glass.
	_lock_mark = get_node_or_null("LockMark") as StarCoreBayLockMark
	if _lock_mark == null:
		_lock_mark = StarCoreBayLockMark.new()
		_lock_mark.name = "LockMark"
		add_child(_lock_mark)
	_lock_mark.position = Vector2.ZERO
	_lock_mark.z_index = 1
	_lock_mark.visible = occupied and show_lock_marker

	# Existing StarCoreVisual (middle). The badge is always off.
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
		_core.z_index = 2
		_core.show_state_badge = false

	# Glass (front).
	_glass = get_node_or_null("Glass") as Sprite2D
	if _glass == null:
		_glass = Sprite2D.new()
		_glass.name = "Glass"
		add_child(_glass)
	_glass.centered = true
	_glass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glass.z_index = 3
	if _glass.texture == null:
		_glass.texture = load_texture_safely(GLASS_TEXTURE_PATH)
		if _glass.texture == null:
			_warn_missing_once(GLASS_TEXTURE_PATH)
	_ensure_lid_material()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	if not _lid_animating:
		set_process(false)
		return
	_lid_progress = move_toward(_lid_progress, _lid_target, _lid_speed * delta)
	_apply_lid_visual()
	if is_equal_approx(_lid_progress, _lid_target):
		_lid_animating = false
		set_process(false)


## The glass keeps its original position/scale and colour. The shader discards
## pixels from the two lower sides upward; the top centre is the last pixel to
## close and the first to open. At progress 1 the glass is fully discarded and
## hidden; at 0 the original 32x32 closed silhouette is untouched.
func _apply_lid_visual() -> void:
	if _glass == null:
		return
	_glass.position = Vector2.ZERO
	_glass.scale = Vector2.ONE
	_glass.modulate = Color.WHITE
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
## The actual frames are still rendered by the engine shader.
func set_lid_progress_for_capture(progress: float) -> void:
	_lid_animating = false
	set_process(false)
	_lid_progress = clampf(progress, 0.0, 1.0)
	_apply_lid_visual()


## CPU mirror of the shader mask. Used for symmetry/ordering assertions; the
## visible frames additionally come from real engine captures.
static func is_lid_mask_pixel_visible(open_progress: float, x: int, y: int) -> bool:
	var reveal: float = 1.0 - clampf(open_progress, 0.0, 1.0)
	var threshold: float = lerpf(LID_MAX_DISTANCE + 0.01, -0.01, reveal)
	var distance: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(LID_TOP_CENTER)
	return distance >= threshold


func _warn_missing_once(path: String) -> void:
	if _warned_missing.has(path):
		return
	_warned_missing[path] = true
	push_warning(
		"StarCoreBayVisual: art not found or not imported: %s. "
		% path
		+ "The bay layer is left empty; no substitute PNG is generated."
	)
