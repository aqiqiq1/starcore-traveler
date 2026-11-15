@tool
class_name RuneStoneVisual
extends Node2D

## Pure visual display for the fixed, 32x32 concept-derived rune stone.
##
## The scene owns no collision, force field, attraction, repulsion, proximity
## detection, map state, or star-core behaviour. It only shows three approved
## concept states, each generated directly from the concept's own
## ``sprite('sleep'/'gold'/'cyan')`` image at 96x96 and converted to 32x32 with
## a direct NEAREST resample:
##
##   Base   (z order 0)  the dormant ``sleep`` state: exact approved shell,
##                       crack network, dark core and inner wall.
##   Accent (z order 1)  the ``gold`` or ``cyan`` whole-state image. At settled
##                       light it is shown at full alpha; while dormant it is
##                       hidden at alpha 0. The two textures keep the concept's
##                       baked coloured core, inner-wall reflection and highlight
##                       instead of approximating them with a shell + white mask.
##
## Both polarities reuse the exact same 32x32 outline and crack geometry because
## all three images are direct NEAREST samples of the same 96x96 approved sprite
## silhouette. Switching only changes which pre-composed state image is shown,
## so the stone outline and crack network can never drift between states. The
## stone never rotates, scales or bobs in this component. The unenergized state
## shows the concept's sleep image and contains no gold or cyan light.
##
## A small + or - glyph can be drawn outside the stone with show_polarity_hint.
## It is never baked into the PNG and never rotates. The hint is suppressed
## while unenergized, because an inactive stone must not imply a polarity. The
## component does not decide when the player is near; a room/visual caller can
## show the hint when appropriate. The hint has no connection to gameplay
## polarity or force.
##
## set_polarity(positive, immediate):
##   immediate = true   jump straight to the new colour (also used in editor)
##   immediate = false  brief dim, then relight in the new colour
## While unenergized, set_polarity only records a target and keeps the sleep
## image. Use energize_to(positive, immediate) for the first light-up; it starts
## from the dark sleep image and finishes in the requested colour.
## transition_finished(positive) is emitted once when an animated transition
## reaches its end. Immediate changes emit nothing because no transition ran.
## Tree pause freezes an animated transition and does not emit the signal.
##
## The component is @tool so the state images, energized state and hint are
## visible while editing. It stays static in the editor; there is no preview
## animation or autonomous process. Nearest filtering is forced on the root and
## both sprites.

signal transition_finished(positive: bool)

const SLEEP_TEXTURE_PATH: String = "res://assets/rune_stone/rune_stone_sleep.png"
const GOLD_TEXTURE_PATH: String = "res://assets/rune_stone/rune_stone_gold.png"
const CYAN_TEXTURE_PATH: String = "res://assets/rune_stone/rune_stone_cyan.png"

const SOURCE_SIZE: Vector2i = Vector2i(32, 32)
const STONE_RECT: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
## The 5x5 glyph sits above and slightly right of the stone. The shadow extends
## one pixel further; the whole hint remains outside the stone body.
const HINT_POSITION: Vector2i = Vector2i(11, -24)
const HINT_GLYPH_SIZE: int = 5
const HINT_RECT: Rect2 = Rect2(11.0, -24.0, 6.0, 6.0)

const POSITIVE_COLOR: Color = Color("#f4cd63")
const NEGATIVE_COLOR: Color = Color("#5fe1e6")
const TRANSITION_DARK: Color = Color(0.035, 0.048, 0.052, 1.0)
## Logical API colour for the concept's sleep image. The PNG itself carries the
## dark core; this value only keeps the existing public colour contract.
const INACTIVE_COLOR: Color = Color(0.032, 0.043, 0.047, 1.0)
const HINT_OUTLINE: Color = Color(0.02, 0.035, 0.04, 0.94)
const PLACEHOLDER_COLOR: Color = Color(0.55, 0.68, 0.68, 0.95)

## Fraction of the transition spent extinguishing the old accent. The remainder
## brings the new accent up, so the stone is briefly dormant instead of
## crossfading two bright colours through a muddy hue.
const DIM_FRACTION: float = 0.36

@export var polarity_positive: bool = true:
	set(value):
		if polarity_positive == value:
			return
		polarity_positive = value
		if _suppress_property_apply:
			return
		# Direct property changes (inspector or code) are immediate and cancel
		# any transition still running. Use set_polarity(..., false) when the
		# dim-then-relight transition is wanted.
		if is_inside_tree():
			_cancel_transition()
		_apply_polarity_now(value)

## False = dormant stone: the unchanged sleep image is shown and the +/- hint is
## suppressed. Default true keeps every existing visual-only caller unchanged.
@export var energized: bool = true:
	set(value):
		if energized == value:
			return
		energized = value
		if _suppress_property_apply:
			return
		if is_inside_tree():
			_cancel_transition()
		if energized:
			_apply_polarity_now(polarity_positive)
		else:
			_apply_inactive_now()

@export var show_polarity_hint: bool = false:
	set(value):
		show_polarity_hint = value
		queue_redraw()

@export_range(0.05, 2.0, 0.01, "suffix:s") var transition_duration: float = 0.22:
	set(value):
		transition_duration = clampf(value, 0.05, 2.0)

@export var show_missing_placeholder: bool = true:
	set(value):
		show_missing_placeholder = value
		queue_redraw()

var _base: Sprite2D
var _accent: Sprite2D
var _sleep_texture: Texture2D
var _gold_texture: Texture2D
var _cyan_texture: Texture2D
var _displayed_positive: bool = true
var _current_color: Color = POSITIVE_COLOR
var _current_accent_alpha: float = 1.0
var _transitioning: bool = false
var _transition_elapsed: float = 0.0
var _transition_progress: float = 0.0
var _transition_from_color: Color = POSITIVE_COLOR
var _transition_from_texture: Texture2D
var _transition_from_alpha: float = 1.0
var _suppress_property_apply: bool = false
var _art_missing: bool = true
var _missing_path: String = ""
static var _warned_missing: Dictionary = {}
static var _warned_size: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_sprites()
	_load_art()
	if energized:
		_apply_polarity_now(polarity_positive)
	else:
		_apply_inactive_now()
	_update_process()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _transitioning:
		advance_transition(delta)


## Public visual API. When immediate is false, the stone stays put and the
## accent dims out and then relights in the new colour. While unenergized this
## only records the target; the sleep image stays until energize_to().
func set_polarity(positive: bool, immediate: bool = false) -> void:
	if Engine.is_editor_hint():
		immediate = true

	if not energized:
		_set_target_silently(positive)
		_displayed_positive = positive
		_cancel_transition()
		_apply_inactive_now()
		return

	if immediate:
		_set_target_silently(positive)
		_cancel_transition()
		_apply_polarity_now(positive)
		return

	if not is_inside_tree() or _accent == null:
		_set_target_silently(positive)
		_displayed_positive = positive
		_current_color = get_polarity_color(positive)
		_current_accent_alpha = 1.0
		_update_process()
		queue_redraw()
		return

	if _transitioning:
		if positive == polarity_positive:
			return
	elif positive == polarity_positive and _displayed_positive == positive:
		return

	_start_transition(positive)


## Switch the dormant/lit presentation. Turning it off cancels any animated
## transition and immediately shows the sleep image. Turning it on with
## immediate=false is equivalent to a first light-up in the current target
## colour; use energize_to() when a specific target is being delivered.
func set_energized(value: bool, immediate: bool = true) -> void:
	if Engine.is_editor_hint():
		immediate = true
	if value == energized:
		if not value:
			_apply_inactive_now()
		return
	if immediate:
		_set_energized_silently(value)
		_cancel_transition()
		if value:
			_apply_polarity_now(polarity_positive)
		else:
			_apply_inactive_now()
		return
	if not value:
		set_energized(false, true)
		return
	energize_to(polarity_positive, false)


## Start the first light-up from the dark sleep image toward a specific
## polarity. The signal is emitted once at the end; the caller commits gameplay
## state only then. Repeating the same target mid-transition does not restart.
func energize_to(positive: bool, immediate: bool = false) -> void:
	if Engine.is_editor_hint():
		immediate = true

	if immediate or not is_inside_tree() or _accent == null:
		_set_energized_silently(true)
		_set_target_silently(positive)
		_cancel_transition()
		_apply_polarity_now(positive)
		return

	var was_energized: bool = energized
	_set_energized_silently(true)
	if not was_energized:
		# The displayed polarity may already equal the target while the stone is
		# dark, but the accent itself still has to rise from alpha 0.
		_start_transition(positive)
		return
	if _transitioning:
		if positive == polarity_positive:
			return
	elif positive == polarity_positive and _displayed_positive == positive:
		return
	_start_transition(positive)


## Abandon an animated transition without emitting and restore the currently
## displayed (committed) look: sleep when dormant, old accent when lit.
func cancel_transition() -> void:
	_cancel_transition()
	_set_target_silently(_displayed_positive)
	if energized:
		_apply_polarity_now(_displayed_positive)
	else:
		_apply_inactive_now()


## Advance an animated transition. Exposed for deterministic tests/captures.
## Tree pause freezes it even if a caller invokes this directly.
func advance_transition(delta: float) -> void:
	if not _transitioning or delta <= 0.0:
		return
	if get_tree() != null and get_tree().paused:
		return

	_transition_elapsed += delta
	var duration: float = maxf(transition_duration, 0.001)
	_transition_progress = clampf(_transition_elapsed / duration, 0.0, 1.0)
	if _transition_progress >= 1.0:
		_complete_transition()
	else:
		_update_transition_visual(_transition_progress)


func is_transitioning() -> bool:
	return _transitioning


func get_transition_progress() -> float:
	return _transition_progress


func get_transition_elapsed() -> float:
	return _transition_elapsed


func get_displayed_color() -> Color:
	return _current_color


## Actual alpha of the gold/cyan state overlay. 0 = dormant sleep image,
## 1 = fully settled state image. Exposed for visual tests and previews.
func get_accent_strength() -> float:
	return _current_accent_alpha


func get_applied_positive() -> bool:
	return _displayed_positive


func is_energized() -> bool:
	return energized


func get_hint_kind() -> StringName:
	if not energized:
		return &"none"
	return &"plus" if polarity_positive else &"minus"


## True only when the caller asked for the hint AND the stone is energized.
## Keeps the draw rule inspectable without rendering a viewport.
func should_draw_polarity_hint() -> bool:
	return show_polarity_hint and energized


func get_hint_rect() -> Rect2:
	return HINT_RECT


func get_source_size() -> Vector2i:
	return SOURCE_SIZE


func get_stone_rect() -> Rect2:
	return STONE_RECT


func get_base_sprite() -> Sprite2D:
	return _base


func get_accent_sprite() -> Sprite2D:
	return _accent


## Compatibility aliases for callers that still use the old layer names.
## "Shell" is now the dormant sleep image; "Cracks" is the whole-state accent.
func get_shell_sprite() -> Sprite2D:
	return _base


func get_crack_sprite() -> Sprite2D:
	return _accent


func get_sleep_texture() -> Texture2D:
	return _sleep_texture


func get_state_texture(positive: bool) -> Texture2D:
	return _gold_texture if positive else _cyan_texture


func has_art() -> bool:
	return not _art_missing


func is_art_missing() -> bool:
	return _art_missing


func get_missing_texture_path() -> String:
	return _missing_path


static func get_polarity_color(positive: bool) -> Color:
	return POSITIVE_COLOR if positive else NEGATIVE_COLOR


static func load_texture_safely(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	return null


## Re-check all three state PNGs after an art refresh. It does not restart or
## cancel an active transition.
func refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_sprites()
	_load_art()
	if _art_missing:
		queue_redraw()
		return
	if not energized:
		_apply_inactive_now()
	elif _transitioning:
		_update_transition_visual(_transition_progress)
	else:
		_apply_polarity_now(_displayed_positive)
	queue_redraw()


func _start_transition(positive: bool) -> void:
	_set_target_silently(positive)
	_transition_from_color = _current_color
	_transition_from_alpha = _current_accent_alpha
	_transition_from_texture = _accent.texture if _accent != null else null
	_transitioning = true
	_transition_elapsed = 0.0
	_transition_progress = 0.0
	_update_transition_visual(0.0)
	queue_redraw()
	_update_process()


func _complete_transition() -> void:
	var final_positive: bool = polarity_positive
	_transitioning = false
	_transition_elapsed = transition_duration
	_transition_progress = 1.0
	_displayed_positive = final_positive
	_current_color = get_polarity_color(final_positive)
	_set_accent(get_state_texture(final_positive), 1.0)
	_update_process()
	queue_redraw()
	transition_finished.emit(final_positive)


func _cancel_transition() -> void:
	_transitioning = false
	_transition_elapsed = 0.0
	_transition_progress = 0.0
	_update_process()


func _apply_polarity_now(positive: bool) -> void:
	_displayed_positive = positive
	if not energized:
		_apply_inactive_now()
		return
	_current_color = get_polarity_color(positive)
	_set_accent(get_state_texture(positive), 1.0)
	queue_redraw()


func _apply_inactive_now() -> void:
	_current_color = INACTIVE_COLOR
	_set_accent(null, 0.0)
	queue_redraw()


func _update_transition_visual(progress: float) -> void:
	var target_color: Color = get_polarity_color(polarity_positive)
	var color: Color
	if progress < DIM_FRACTION:
		var u: float = smoothstep(0.0, 1.0, progress / DIM_FRACTION)
		color = _transition_from_color.lerp(TRANSITION_DARK, u)
		_set_accent(_transition_from_texture, lerpf(_transition_from_alpha, 0.0, u))
	else:
		var u: float = smoothstep(
			0.0,
			1.0,
			(progress - DIM_FRACTION) / (1.0 - DIM_FRACTION)
		)
		color = TRANSITION_DARK.lerp(target_color, u)
		_set_accent(get_state_texture(polarity_positive), u)
	_current_color = color


func _set_accent(texture: Texture2D, alpha: float) -> void:
	_current_accent_alpha = clampf(alpha, 0.0, 1.0)
	if _accent == null:
		return
	if texture != null and _accent.texture != texture:
		_accent.texture = texture
	_accent.modulate = Color(1.0, 1.0, 1.0, _current_accent_alpha)


func _set_target_silently(positive: bool) -> void:
	_suppress_property_apply = true
	polarity_positive = positive
	_suppress_property_apply = false


func _set_energized_silently(value: bool) -> void:
	_suppress_property_apply = true
	energized = value
	_suppress_property_apply = false


func _update_process() -> void:
	if not is_inside_tree():
		set_process(false)
		return
	set_process(_transitioning and not Engine.is_editor_hint())


func _ensure_sprites() -> void:
	if _base == null or not is_instance_valid(_base):
		_base = get_node_or_null("Base") as Sprite2D
		if _base == null:
			# Compatibility with older scene instances that named the base "Shell".
			_base = get_node_or_null("Shell") as Sprite2D
		if _base == null:
			_base = Sprite2D.new()
			_base.name = "Base"
			add_child(_base)
	if _accent == null or not is_instance_valid(_accent):
		_accent = get_node_or_null("Accent") as Sprite2D
		if _accent == null:
			# Compatibility with older scene instances that named the overlay "Cracks".
			_accent = get_node_or_null("Cracks") as Sprite2D
		if _accent == null:
			_accent = Sprite2D.new()
			_accent.name = "Accent"
			add_child(_accent)

	for sprite: Sprite2D in [_base, _accent]:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		sprite.centered = true
		sprite.flip_h = false
		sprite.flip_v = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base.z_index = 0
	_accent.z_index = 1
	_base.show_behind_parent = false
	_accent.show_behind_parent = false


func _load_art() -> void:
	_ensure_sprites()
	_sleep_texture = load_texture_safely(SLEEP_TEXTURE_PATH)
	_gold_texture = load_texture_safely(GOLD_TEXTURE_PATH)
	_cyan_texture = load_texture_safely(CYAN_TEXTURE_PATH)

	_base.texture = _sleep_texture
	# Keep a valid accent texture even while dormant; alpha 0 hides it. This
	# makes the first light-up start from the exact sleep image.
	if _accent.texture == null:
		_accent.texture = _gold_texture
	if _sleep_texture == null or _gold_texture == null or _cyan_texture == null:
		_art_missing = true
		_missing_path = (
			SLEEP_TEXTURE_PATH if _sleep_texture == null
			else (GOLD_TEXTURE_PATH if _gold_texture == null else CYAN_TEXTURE_PATH)
		)
		for path: String in [SLEEP_TEXTURE_PATH, GOLD_TEXTURE_PATH, CYAN_TEXTURE_PATH]:
			if not ResourceLoader.exists(path, "Texture2D"):
				_warn_missing_once(path)
		# Show only the neutral placeholder when any state is missing; do not
		# float a partial state image that could be mistaken for the approved art.
		_base.visible = false
		_accent.visible = false
		return

	_art_missing = false
	_missing_path = ""
	_base.visible = true
	_accent.visible = true
	for path: String in [SLEEP_TEXTURE_PATH, GOLD_TEXTURE_PATH, CYAN_TEXTURE_PATH]:
		var texture: Texture2D = load_texture_safely(path)
		if texture != null and Vector2i(texture.get_size()) != SOURCE_SIZE:
			_warn_size_once(path, Vector2i(texture.get_size()))


func _warn_missing_once(path: String) -> void:
	if _warned_missing.has(path):
		return
	_warned_missing[path] = true
	push_warning(
		"RuneStoneVisual: art not found or not imported: %s. "
		% path
		+ "Showing a neutral dashed placeholder; no substitute stone is generated."
	)


func _warn_size_once(path: String, size: Vector2i) -> void:
	if _warned_size.has(path):
		return
	_warned_size[path] = true
	push_warning(
		"RuneStoneVisual: %s is %s, expected %s. It is shown 1:1 without rescaling."
		% [path, str(size), str(SOURCE_SIZE)]
	)


func _draw() -> void:
	if _art_missing and show_missing_placeholder:
		_draw_missing_placeholder()
	if should_draw_polarity_hint():
		_draw_polarity_hint()


func _draw_missing_placeholder() -> void:
	draw_rect(STONE_RECT, Color(0.02, 0.04, 0.05, 0.62))
	for offset: int in range(-16, 16, 4):
		draw_rect(Rect2(float(offset), -16.0, 2.0, 1.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(float(offset), 15.0, 2.0, 1.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(-16.0, float(offset), 1.0, 2.0), PLACEHOLDER_COLOR)
		draw_rect(Rect2(15.0, float(offset), 1.0, 2.0), PLACEHOLDER_COLOR)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(PLACEHOLDER_COLOR, 0.55))


func _draw_polarity_hint() -> void:
	var accent: Color = get_polarity_color(polarity_positive)
	var glyph: Array[Vector2i] = _hint_glyph_points()
	# A tiny dark drop shadow keeps the unrotated glyph readable over pale sky.
	for point: Vector2i in glyph:
		draw_rect(
			Rect2(float(point.x + 1), float(point.y + 1), 1.0, 1.0),
			HINT_OUTLINE
		)
	for point: Vector2i in glyph:
		draw_rect(Rect2(float(point.x), float(point.y), 1.0, 1.0), accent)


func _hint_glyph_points() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x: int = HINT_POSITION.x
	var y: int = HINT_POSITION.y
	if polarity_positive:
		for i: int in range(HINT_GLYPH_SIZE):
			points.append(Vector2i(x + i, y + 2))
			points.append(Vector2i(x + 2, y + i))
	else:
		for i: int in range(HINT_GLYPH_SIZE):
			points.append(Vector2i(x + i, y + 2))
	return points
