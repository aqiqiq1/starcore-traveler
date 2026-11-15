@tool
class_name StarCoreVisual
extends Node2D

## Pure visual display for the star core's three states.
##
## This node deliberately owns no physics, collision, attraction, pickup,
## interaction, or star-core-bay logic. Drop the scene into a room and choose
## LOCKED / POSITIVE / NEGATIVE in the inspector; the matching 12-frame sheet
## and the code-drawn state badge update immediately, including in the editor.
##
## The 12-frame sheets are loaded lazily (never preloaded), so opening this scene
## before the art pass has produced them cannot break script parsing. Each frame
## is shown through an AtlasTexture at native 16x16 with nearest filtering; the
## sprite scale never changes with thin rotation frames. If a 12-frame sheet is
## missing, the old 16x16 still PNG is used as a static fallback. A missing image
## shows a neutral dashed placeholder and logs one warning per path; this
## component never invents a recoloured substitute PNG.
##
## Animation defaults to 12 FPS and loops. It can be changed in the inspector.
## The tree pause freezes the current frame. Changing state or becoming visible
## again restarts at frame 0. refresh() only re-checks the art and deliberately
## does not restart playback, so callers that refresh every frame cannot stall
## the loop; use reset_animation() for an explicit reset.

enum CoreState {
	LOCKED,
	POSITIVE,
	NEGATIVE,
}

## Legacy 16x16 still paths. Kept public and unchanged for existing callers and
## for the static fallback; the animated display reads SHEET_PATHS first.
const TEXTURE_PATHS := [
	"res://assets/star_core/star_core_locked.png",
	"res://assets/star_core/star_core_positive.png",
	"res://assets/star_core/star_core_negative.png",
]

const SHEET_PATHS := [
	"res://assets/star_core/star_core_locked_12f.png",
	"res://assets/star_core/star_core_positive_12f.png",
	"res://assets/star_core/star_core_negative_12f.png",
]

## Source sprites are authored at 16x16 per frame and are always displayed 1:1
## with nearest-neighbour filtering. Magnification belongs to the preview only.
const SOURCE_SIZE: Vector2i = Vector2i(16, 16)
const SOURCE_SHEET_SIZE: Vector2i = Vector2i(192, 16)
const FRAME_COUNT: int = 12
const DEFAULT_FPS: float = 12.0
const GEM_RECT: Rect2 = Rect2(-8.0, -8.0, 16.0, 16.0)
## The badge sits diagonally outside the gem bounds so it can never obscure
## the gem's centre or facets. It is drawn by this script, never baked into
## the source PNG and never rotated or mirrored with the frames.
const BADGE_RECT: Rect2 = Rect2(9.0, 9.0, 7.0, 7.0)

const BADGE_BG: Color = Color(0.02, 0.04, 0.05, 0.96)
const BADGE_OUTLINE: Color = Color(0.80, 0.87, 0.85, 0.90)
const POSITIVE_COLOR: Color = Color("#f4cd63")
const NEGATIVE_COLOR: Color = Color("#5fe1e6")
const LOCKED_COLOR: Color = Color("#c8a7f2")
const PLACEHOLDER_COLOR: Color = Color(0.55, 0.68, 0.68, 0.95)

@export var state: CoreState = CoreState.LOCKED:
	set(value):
		if state == value:
			return
		state = value
		_refresh_visual(true)
		queue_redraw()

## 12 FPS matches the source sheet's intended loop speed. Inspector range is
## deliberately broader so scenes can tune it without editing the script.
@export_range(1.0, 60.0, 0.1, "suffix:fps") var animation_fps: float = DEFAULT_FPS:
	set(value):
		animation_fps = clampf(value, 1.0, 60.0)
		_update_process()

@export var animate: bool = true:
	set(value):
		animate = value
		_update_process()

@export var show_state_badge: bool = true:
	set(value):
		show_state_badge = value
		queue_redraw()

@export var show_missing_placeholder: bool = true:
	set(value):
		show_missing_placeholder = value
		queue_redraw()

var _sprite: Sprite2D
var _art_missing: bool = true
var _missing_path: String = ""
var _sheet_texture: Texture2D
var _frame_textures: Array[Texture2D] = []
var _frame_index: int = 0
var _frame_accumulator: float = 0.0
var _using_animated_sheet: bool = false
var _last_visible_in_tree: bool = false
static var _warned_missing: Dictionary = {}
static var _warned_size: Dictionary = {}


func _ready() -> void:
	_ensure_sprite()
	_last_visible_in_tree = is_visible_in_tree()
	_refresh_visual(true)
	_update_process()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var now_visible: bool = is_inside_tree() and is_visible_in_tree()
	if now_visible and not _last_visible_in_tree:
		# Re-activation (for example a core taken out of a bay, or a room reset
		# that re-shows the stored core) starts from frame 0.
		reset_animation()
	_last_visible_in_tree = now_visible


## Re-check the current state's sheet. This keeps the old refresh() contract: it
## is safe to call every frame and does not restart playback. Use
## reset_animation() when a reset/re-activation must explicitly restart at 0.
func refresh() -> void:
	_refresh_visual(false)


## Load an image only when it exists and resolves as a Texture2D. Kept static
## so tests can exercise the missing-file path without touching real assets.
static func load_texture_safely(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func get_state_texture_path(value: int = -1) -> String:
	var target: int = state if value < 0 else value
	if target < 0 or target >= TEXTURE_PATHS.size():
		return ""
	return TEXTURE_PATHS[target]


func get_state_sheet_path(value: int = -1) -> String:
	var target: int = state if value < 0 else value
	if target < 0 or target >= SHEET_PATHS.size():
		return ""
	return SHEET_PATHS[target]


## Current frame texture. This remains 16x16 exactly like the old static API;
## the full sheet is exposed separately through get_art_sheet().
func get_art_texture() -> Texture2D:
	if _sprite == null:
		return null
	return _sprite.texture


func get_art_sheet() -> Texture2D:
	return _sheet_texture


func is_using_animated_sheet() -> bool:
	return _using_animated_sheet and _frame_textures.size() == FRAME_COUNT


func has_art() -> bool:
	return not _art_missing


func is_art_missing() -> bool:
	return _art_missing


func get_missing_texture_path() -> String:
	return _missing_path


func get_badge_kind() -> StringName:
	match state:
		CoreState.POSITIVE:
			return &"plus"
		CoreState.NEGATIVE:
			return &"minus"
		_:
			return &"lock"


func get_gem_rect() -> Rect2:
	return GEM_RECT


func get_badge_rect() -> Rect2:
	return BADGE_RECT


func get_source_size() -> Vector2i:
	return SOURCE_SIZE


func get_source_sheet_size() -> Vector2i:
	return SOURCE_SHEET_SIZE


func get_animation_frame_count() -> int:
	return _frame_textures.size()


func get_animation_frame() -> int:
	return _frame_index


func get_animation_fps() -> float:
	return animation_fps


func get_frame_elapsed() -> float:
	return _frame_accumulator


func is_animating() -> bool:
	return (
		animate
		and not _art_missing
		and _frame_textures.size() > 1
		and is_inside_tree()
		and is_visible_in_tree()
		and (get_tree() == null or not get_tree().paused)
	)


## Advance by delta seconds using the same wrap math as _process. Exposed for
## deterministic tests and fixed-frame captures; normal runtime uses _process.
func advance_animation(delta: float) -> void:
	if delta <= 0.0 or _art_missing or _frame_textures.size() <= 1:
		return
	if get_tree() != null and get_tree().paused:
		return
	_frame_accumulator += delta * animation_fps
	var steps: int = int(floor(_frame_accumulator))
	if steps <= 0:
		return
	_frame_accumulator -= float(steps)
	_frame_index = posmod(_frame_index + steps, _frame_textures.size())
	_apply_frame()


## Restart the loop at the requested frame and clear the fractional timer.
func reset_animation(frame: int = 0) -> void:
	_frame_accumulator = 0.0
	if _frame_textures.is_empty():
		_frame_index = 0
		return
	_frame_index = posmod(frame, _frame_textures.size())
	_apply_frame()


## Fixed-frame helper for previews/captures; no gameplay state is changed.
func set_animation_frame(frame: int) -> void:
	reset_animation(frame)


func set_core_state(value: CoreState) -> void:
	state = value


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not animate:
		return
	if not is_visible_in_tree():
		return
	advance_animation(delta)


func _refresh_visual(reset_frame: bool = false) -> void:
	if not is_inside_tree():
		return
	_ensure_sprite()

	var sheet_path: String = get_state_sheet_path()
	var still_path: String = get_state_texture_path()
	var sheet: Texture2D = load_texture_safely(sheet_path)

	if sheet != null and Vector2i(sheet.get_size()) == SOURCE_SHEET_SIZE:
		var sheet_changed: bool = _sheet_texture != sheet
		if sheet_changed or _frame_textures.size() != FRAME_COUNT:
			_build_frame_textures(sheet)
			sheet_changed = true
		_sheet_texture = sheet
		_using_animated_sheet = true
		_art_missing = false
		_missing_path = ""
		if sheet_changed or reset_frame:
			_frame_index = 0
			_frame_accumulator = 0.0
		_apply_frame()
		_update_process()
		queue_redraw()
		return

	if sheet != null:
		_warn_sheet_size_once(sheet_path, Vector2i(sheet.get_size()))

	var still: Texture2D = load_texture_safely(still_path)
	_sheet_texture = null
	_using_animated_sheet = false

	if still != null:
		var still_changed: bool = _frame_textures.size() != 1 or _frame_textures[0] != still
		if still_changed:
			_frame_textures.clear()
			_frame_textures.append(still)
			_frame_index = 0
			_frame_accumulator = 0.0
		elif reset_frame:
			_frame_index = 0
			_frame_accumulator = 0.0
		_art_missing = false
		_missing_path = ""
		if Vector2i(still.get_size()) != SOURCE_SIZE:
			_warn_size_once(still_path, Vector2i(still.get_size()))
		_apply_frame()
		_update_process()
		queue_redraw()
		return

	_frame_textures.clear()
	_frame_index = 0
	_frame_accumulator = 0.0
	_art_missing = true
	_missing_path = still_path
	_warn_missing_once(still_path)
	_apply_frame()
	_update_process()
	queue_redraw()


func _build_frame_textures(sheet: Texture2D) -> void:
	_frame_textures.clear()
	for index: int in range(FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(index * SOURCE_SIZE.x),
			0.0,
			float(SOURCE_SIZE.x),
			float(SOURCE_SIZE.y)
		)
		atlas.filter_clip = true
		_frame_textures.append(atlas)


func _apply_frame() -> void:
	if _sprite == null:
		return
	if _frame_textures.is_empty():
		_sprite.texture = null
		_sprite.visible = false
		return
	_frame_index = clampi(_frame_index, 0, _frame_textures.size() - 1)
	_sprite.texture = _frame_textures[_frame_index]
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_sprite.centered = true
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0
	_sprite.flip_h = false
	_sprite.flip_v = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _update_process() -> void:
	if not is_inside_tree():
		set_process(false)
		return
	set_process(
		not Engine.is_editor_hint()
		and animate
		and not _art_missing
		and _frame_textures.size() > 1
	)


func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_sprite = get_node_or_null("Gem") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Gem"
		add_child(_sprite)
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = 1
	_sprite.vframes = 1


func _warn_missing_once(path: String) -> void:
	if _warned_missing.has(path):
		return
	_warned_missing[path] = true
	push_warning(
		"StarCoreVisual: art not found or not imported: %s. "
		% path
		+ "Showing a neutral dashed placeholder; no substitute PNG is generated."
	)


func _warn_size_once(path: String, size: Vector2i) -> void:
	if _warned_size.has(path):
		return
	_warned_size[path] = true
	push_warning(
		"StarCoreVisual: %s is %s, expected %s. It is shown 1:1 without rescaling."
		% [path, str(size), str(SOURCE_SIZE)]
	)


func _warn_sheet_size_once(path: String, size: Vector2i) -> void:
	var key: String = "sheet:" + path
	if _warned_size.has(key):
		return
	_warned_size[key] = true
	push_warning(
		"StarCoreVisual: %s is %s, expected %s for 12 frames. "
		% [path, str(size), str(SOURCE_SHEET_SIZE)]
		+ "Falling back to the static 16x16 PNG."
	)


func _draw() -> void:
	if _art_missing and show_missing_placeholder:
		_draw_missing_placeholder()
	if show_state_badge:
		_draw_badge()


func _draw_missing_placeholder() -> void:
	draw_rect(GEM_RECT, Color(0.02, 0.04, 0.05, 0.62))
	# Broken 1 px border: a neutral "art not ready" marker, not a fake gem.
	for offset: int in range(-8, 8, 4):
		draw_rect(Rect2(float(offset), -8.0, 2.0, 1.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(float(offset), 7.0, 2.0, 1.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(-8.0, float(offset), 1.0, 2.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(7.0, float(offset), 1.0, 2.0), PLACEHOLDER_COLOR)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(PLACEHOLDER_COLOR, 0.55))


func _draw_badge() -> void:
	var accent: Color = _accent_for_state()
	draw_rect(BADGE_RECT, BADGE_BG)
	draw_rect(BADGE_RECT, BADGE_OUTLINE, false, 1.0)

	match state:
		CoreState.LOCKED:
			# Tiny padlock: shackle, body, keyhole.
			draw_rect(Rect2(11.0, 10.0, 3.0, 1.0), accent)
			draw_rect(Rect2(11.0, 10.0, 1.0, 2.0), accent)
			draw_rect(Rect2(13.0, 10.0, 1.0, 2.0), accent)
			draw_rect(Rect2(10.0, 12.0, 5.0, 3.0), accent)
			draw_rect(Rect2(12.0, 13.0, 1.0, 1.0), BADGE_BG)
		CoreState.POSITIVE:
			draw_rect(Rect2(10.0, 12.0, 5.0, 1.0), accent)
			draw_rect(Rect2(12.0, 10.0, 1.0, 5.0), accent)
		CoreState.NEGATIVE:
			draw_rect(Rect2(10.0, 12.0, 5.0, 1.0), accent)


func _accent_for_state() -> Color:
	match state:
		CoreState.POSITIVE:
			return POSITIVE_COLOR
		CoreState.NEGATIVE:
			return NEGATIVE_COLOR
		_:
			return LOCKED_COLOR
