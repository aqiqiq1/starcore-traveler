class_name ConductiveActivation
extends Node2D

## L2 first-relay activation display (2026-11-18 crystal draft, cleanup).
##
## Pure presentation: it never reads or writes gameplay progress, forces,
## collision, RIDs, bay state, audio or the camera. Level02 owns the boolean
## `_special_wall_unlocked` and calls `set_unlocked()` only after that value
## changes. Level02 also passes this tick's real shared-field result through
## `update_force_state()`; this node never fabricates force data.
##
## The old RelayBay -> ConductiveRoof connection layer has been removed:
## no cyan polyline, no roof lower seam, no moving head, no bay/corner nodes and
## no two gold corner terminals. This is true in locked, unlocking, held and
## restored/R states. The 0.7 s clock mirrors the material's lit sweep for
## read-only callers; it still draws no route or terminal.
##
## The first ConductiveRoof and LinkedWall+Lip are both owned by
## `LayeredCoreMaterial`. The old Wall/Lip static marks are replaced by the
## linked crystal component; only ReturnPlatform keeps a static mark.
## The linked component is a single 200x60 texture (stone cap + exposed
## crystal + lip), so after it binds successfully the original Wall/Lip
## Sprite2D nodes are hidden and their previous `visible` is remembered for
## rebuild/cleanup; a failed bind leaves the original art untouched.
## The material's real player-core gold/cyan tint (per its own mask) and the
## core's own polarity marker are untouched.
##
## The whole effect is behind the player/core (z=2 vs player 5, core 4) and the
## material is limited palette, nearest-filter pixels. The material's fade clock
## is pausable, so a real pause freezes it. No sound is started here.

const LAYERED_CORE_MATERIAL = preload("res://scripts/narrative/layered_core_material.gd")

const LINKED_BASE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_linked_v3_base_200x60.png"
const LINKED_ACTIVE_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_linked_v3_active_200x60.png"
const LINKED_MASK_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_linked_v3_mask_200x60.png"
const LINKED_ARRIVAL_PATH: String = "res://assets/interaction_projection_20261117/layered_core/layered_linked_v3_arrival_200x60.png"
const LINKED_SIZE: Vector2 = Vector2(200.0, 60.0)

const DURATION: float = 0.7
const Z_INDEX: int = 2

const OTHER_SEAM: Color = Color(0.45, 0.75, 0.72, 0.30)
const OTHER_GOLD: Color = Color(0.77, 0.64, 0.37, 0.52)

var _activated: bool = false
var _animating: bool = false
var _elapsed: float = 0.0
var _configured: bool = false
var _geometry_valid: bool = false

var _other_marks: Array[Dictionary] = []
var _layered_core: LayeredCoreMaterial = null
var _linked_platform: LayeredCoreMaterial = null
var _linked_sources: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = Z_INDEX
	z_as_relative = true
	visible = false
	set_process(false)


## Called once by Level02 after the node is in the tree. Caches the real stone
## bounds for the remaining ReturnPlatform mark and creates both crystal materials.
## No gameplay state is read here.
func setup_from_level(level: Node) -> void:
	if level == null:
		return
	var roof_sprite: Sprite2D = level.get_node_or_null("ConductiveRoof/Visual") as Sprite2D
	var roof_rect: Rect2 = _sprite_world_rect(roof_sprite)
	if roof_rect.size == Vector2.ZERO:
		_geometry_valid = false
		_clear_layered_core()
		push_warning("ConductiveActivation: roof sprite missing; effect disabled")
		visible = false
		return
	_other_marks.clear()
	# LinkedWall/Lip are replaced by the crystal component; only the return
	# platform keeps its old static mark.
	_add_other_mark(level.get_node_or_null("ReturnPlatform/Visual") as Sprite2D, "top")
	_build_layered_core(roof_sprite)
	_build_linked_platform(level)
	_geometry_valid = true
	_configured = true
	queue_redraw()


## False -> locked: the layered material stays visible (black crystal) and no
## connection layer is drawn. True with animate=true starts the 0.7 s state
## clock that mirrors the material's lit sweep; it draws no route. Any later
## call presents the settled state directly. This is display only.
func set_unlocked(unlocked: bool, animate_first: bool = false, snap_held: bool = false) -> void:
	if not unlocked:
		_activated = false
		_animating = false
		_elapsed = 0.0
		visible = _geometry_valid
		if _layered_core != null:
			_layered_core.set_unlocked(false)
		if _linked_platform != null:
			_linked_platform.set_unlocked(false)
		set_process(false)
		queue_redraw()
		return
	if not _geometry_valid:
		visible = false
		return
	if _activated:
		if snap_held or not _animating:
			_animating = false
			_elapsed = DURATION
			set_process(false)
		if _layered_core != null:
			_layered_core.set_unlocked(true, false)
		if _linked_platform != null:
			_linked_platform.set_unlocked(true, false)
		visible = true
		queue_redraw()
		return
	_activated = true
	visible = true
	if _layered_core != null:
		_layered_core.set_unlocked(true, animate_first)
	if _linked_platform != null:
		_linked_platform.set_unlocked(true, animate_first)
	if animate_first:
		_animating = true
		_elapsed = 0.0
		set_process(true)
	else:
		_animating = false
		_elapsed = DURATION
		set_process(false)
	queue_redraw()


## Forwarded by Level02 once per unpaused physics tick with the real shared
## field result. The helper gates validity and the mask crossing itself.
func update_force_state(
	core_active: bool,
	status: String,
	blocked: bool,
	pair_core_force: Vector2,
	pair_player_force: Vector2,
	player_center: Vector2,
	core_center: Vector2,
	player_positive: bool
) -> void:
	if _layered_core != null:
		_layered_core.update_force_state(
			core_active, status, blocked, pair_core_force, pair_player_force,
			player_center, core_center, player_positive
		)
	if _linked_platform != null:
		_linked_platform.update_force_state(
			core_active, status, blocked, pair_core_force, pair_player_force,
			player_center, core_center, player_positive
		)


func clear_force_target() -> void:
	if _layered_core != null:
		_layered_core.clear_force_target()
	if _linked_platform != null:
		_linked_platform.clear_force_target()


func _process(delta: float) -> void:
	# State clock only; no route/terminal is drawn at any elapsed value.
	if not _animating:
		return
	_elapsed = minf(_elapsed + delta, DURATION)
	if _elapsed >= DURATION:
		_animating = false
		set_process(false)


func _draw() -> void:
	if not _geometry_valid or not _activated:
		return
	# Only ReturnPlatform keeps a static mark. The first
	# ConductiveRoof has no connection layer or gold terminals.
	for mark: Dictionary in _other_marks:
		_draw_other_mark(mark)


func _build_layered_core(roof_sprite: Sprite2D) -> void:
	_clear_layered_core()
	if roof_sprite == null:
		return
	_layered_core = LAYERED_CORE_MATERIAL.new()
	_layered_core.name = "LayeredCoreMaterial"
	add_child(_layered_core)
	if not _layered_core.setup(roof_sprite):
		push_warning("ConductiveActivation: layered core material failed to set up")
		_layered_core.queue_free()
		_layered_core = null


func _build_linked_platform(level: Node) -> void:
	_clear_linked_platform()
	var anchor: Sprite2D = level.get_node_or_null("LinkedLip/Visual") as Sprite2D
	if anchor == null:
		push_warning("ConductiveActivation: LinkedLip visual missing; linked crystal disabled")
		return
	var wall_sprite: Sprite2D = level.get_node_or_null("LinkedWall/Visual") as Sprite2D
	_linked_platform = LAYERED_CORE_MATERIAL.new()
	_linked_platform.name = "LayeredLinkedPlatform"
	add_child(_linked_platform)
	if not _linked_platform.setup_custom(anchor, LINKED_BASE_PATH, LINKED_ACTIVE_PATH,
			LINKED_MASK_PATH, LINKED_ARRIVAL_PATH, LINKED_SIZE):
		push_warning("ConductiveActivation: linked crystal material failed to set up")
		_linked_platform.queue_free()
		_linked_platform = null
		# Fallback: the original stone stays exactly as the scene authored it.
		return
	# The component now owns the whole 200x60 L in one texture (cap + crystal +
	# lip), so the old Wall/Lip art must not show behind or beside it.
	_hide_linked_sources(anchor, wall_sprite)


## Remembers each source sprite's own visible value and hides it. Restored by
## `_restore_linked_sources()` on rebuild/cleanup, so a failed or removed
## material always falls back to the original art.
func _hide_linked_sources(lip_sprite: Sprite2D, wall_sprite: Sprite2D) -> void:
	for sprite: Sprite2D in [lip_sprite, wall_sprite]:
		if sprite == null or not is_instance_valid(sprite):
			continue
		_linked_sources.append({"sprite": sprite, "visible": sprite.visible})
		sprite.visible = false


func _restore_linked_sources() -> void:
	for record: Dictionary in _linked_sources:
		var sprite: Sprite2D = record.get("sprite") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = bool(record.get("visible", true))
	_linked_sources.clear()


func _clear_linked_platform() -> void:
	_restore_linked_sources()
	if _linked_platform != null and is_instance_valid(_linked_platform):
		_linked_platform.queue_free()
	_linked_platform = null


func _clear_layered_core() -> void:
	if _layered_core != null and is_instance_valid(_layered_core):
		_layered_core.queue_free()
	_layered_core = null


func _draw_part(from: Vector2, axis: String, length: float, color: Color) -> void:
	if length <= 0.0:
		return
	if axis == "h":
		draw_rect(Rect2(Vector2(roundf(from.x), roundf(from.y)), Vector2(length, 1.0)), color)
	else:
		draw_rect(Rect2(Vector2(roundf(from.x), roundf(from.y)), Vector2(1.0, length)), color)


func _draw_rect_px(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(Vector2(roundf(rect.position.x), roundf(rect.position.y)),
		Vector2(roundf(rect.size.x), roundf(rect.size.y))), color)


func _draw_node(center: Vector2, color: Color) -> void:
	_draw_rect_px(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), color)


func _sprite_world_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	return sprite.global_transform * sprite.get_rect()


func _add_other_mark(sprite: Sprite2D, edge: String) -> void:
	var rect: Rect2 = _sprite_world_rect(sprite)
	if rect.size == Vector2.ZERO:
		return
	var y: float = rect.end.y - 2.0 if edge == "bottom" else rect.position.y + 1.0
	var x0: float = rect.position.x + 2.0
	var x1: float = rect.end.x - 5.0
	var terminal_y: float = y - 1.0
	_other_marks.append({
		"x0": x0,
		"x1": x1,
		"y": y,
		"terminal": Rect2(x1, terminal_y, 5.0, 3.0),
	})


func _draw_other_mark(mark: Dictionary) -> void:
	var y: float = mark["y"]
	var x0: float = mark["x0"]
	var x1: float = mark["x1"]
	_draw_part(Vector2(x0, y), "h", maxf(x1 - x0, 0.0), OTHER_SEAM)
	_draw_node(Vector2(x0, y), OTHER_GOLD)
	var terminal: Rect2 = mark["terminal"]
	_draw_rect_px(terminal, OTHER_GOLD)


# --- test/read-only accessors ---------------------------------------------

func is_activated() -> bool:
	return _activated


func is_overlay_visible() -> bool:
	return visible and _geometry_valid


func is_energy_visible() -> bool:
	# Legacy name kept for external callers; it now means the material/other
	# marks are allowed to draw after a real unlock, not a visible route.
	return visible and _geometry_valid and _activated


func is_animating() -> bool:
	return _animating


func is_geometry_valid() -> bool:
	return _geometry_valid


func get_animation_elapsed() -> float:
	return _elapsed


func get_animation_duration() -> float:
	return DURATION


func get_phase_label() -> String:
	# State-clock labels. None of these states draws the removed route.
	if not _activated:
		return "inactive"
	if not _animating:
		return "lit_settled"
	var t: float = _elapsed / DURATION
	if t < 0.25:
		return "lit_early"
	if t < 0.60:
		return "lit_mid"
	if t < 0.98:
		return "lit_late"
	return "lit_settled"


func get_layered_core() -> LayeredCoreMaterial:
	return _layered_core


func get_linked_platform() -> LayeredCoreMaterial:
	return _linked_platform


func has_layered_core() -> bool:
	return _layered_core != null and _layered_core.is_configured()


func has_linked_platform() -> bool:
	return _linked_platform != null and _linked_platform.is_configured()


func get_other_mark_count() -> int:
	return _other_marks.size()


## Test/read-only: the source Wall/Lip records while the component owns them.
## Each entry holds the real Sprite2D and the `visible` value it had before.
func get_linked_source_records() -> Array[Dictionary]:
	return _linked_sources.duplicate()
