class_name AnchorRoom
extends Node2D

## Isolated single-anchor trial room used by the basic prototype.
##
## Layout: a start ledge, a 224 px chasm, and a lower wide landing ledge.
## A fixed positive rune stone floats above the chasm. The player starts
## positive (repelled). The intended route is:
##   Q -> CYAN (attract) -> jump + hold right -> cross the stone -> Q -> GOLD
##   (repel) -> land on the wide ledge.
##
## The force is a gameplay field, not an extra movement state: it is a
## one-tick acceleration handed to the player before move_and_slide. Distances
## are body-centre distances; solid terrain blocks the centre line. The stone
## itself has no collision: it reuses the approved 32x32 RuneStoneVisual shell
## at the fixed anchor position, so F2 and the record room show the same stone.
## The near +/- hint is only a visual label; it owns no force.

signal success_reached
signal trial_reset

const TILE_SIZE: int = 16
const ATLAS: Texture2D = preload("res://assets/map/ruin_platform_tiles.png")
const RUNE_STONE_SCENE: PackedScene = preload("res://scenes/rune_stone_visual.tscn")

const START_RECT: Rect2 = Rect2(0.0, 288.0, 176.0, 80.0)
const DEST_RECT: Rect2 = Rect2(400.0, 336.0, 240.0, 32.0)
const PLATFORM_RECTS: Array[Rect2] = [START_RECT, DEST_RECT]

const SPAWN_POSITION: Vector2 = Vector2(72.0, 288.0)
const ANCHOR_POSITION: Vector2 = Vector2(320.0, 200.0)
const BODY_CENTER_OFFSET: Vector2 = Vector2(0.0, -15.0)

const RANGE: float = 160.0
const INNER_RADIUS: float = 16.0
const FULL_RADIUS: float = 52.0
const OUTER_FADE: float = 40.0
const BASE_ACCELERATION: float = 2400.0
const MIN_DISTANCE: float = 0.5

const STATUS_ATTRACT: String = "ATTRACT"
const STATUS_REPEL: String = "REPEL"
const STATUS_OUT_OF_RANGE: String = "OUT OF RANGE"
const STATUS_BLOCKED: String = "BLOCKED"
const STATUS_NEAR: String = "NEAR / STABLE"

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const MUTED: Color = Color("#a8bbb7")
const BLOCKED_COLOR: Color = Color("#ff7f72")
const LABEL_OUTLINE: Color = Color(0.008, 0.016, 0.02, 0.96)

var _active: bool = false
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _terrain: TileMapLayer
var _collision_bodies: Array[StaticBody2D] = []
var _success: bool = false
var _last_status: String = STATUS_OUT_OF_RANGE
var _last_distance: float = 0.0
var _last_force: Vector2 = Vector2.ZERO
var _last_blocked: bool = false
var _rune_stone: RuneStoneVisual
var _start_label: Label
var _dest_label: Label
var _stone_label: Label
var _route_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -10
	_build_terrain()
	_build_rune_stone()
	_build_labels()
	_set_collisions_active(false)
	visible = false


## The fixed anchor is a visual-only reuse of the shared rune stone. It adds no
## collision body and does not alter the force sample, range or route.
func _build_rune_stone() -> void:
	_rune_stone = RUNE_STONE_SCENE.instantiate() as RuneStoneVisual
	if _rune_stone == null:
		return
	_rune_stone.name = "FixedPositiveRuneStone"
	_rune_stone.position = ANCHOR_POSITION
	_rune_stone.polarity_positive = true
	_rune_stone.energized = true
	_rune_stone.show_polarity_hint = false
	add_child(_rune_stone)


func _build_terrain() -> void:
	_terrain = TileMapLayer.new()
	_terrain.name = "Terrain"
	add_child(_terrain)

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture = ATLAS
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for atlas_y: int in range(2):
		for atlas_x: int in range(12):
			atlas_source.create_tile(Vector2i(atlas_x, atlas_y))

	var source_id: int = tile_set.add_source(atlas_source)
	_terrain.tile_set = tile_set

	for index: int in range(PLATFORM_RECTS.size()):
		var rect: Rect2 = PLATFORM_RECTS[index]
		_paint_platform(rect, source_id)
		_add_collision_rect(rect, index)


func _paint_platform(rect: Rect2, source_id: int) -> void:
	var origin: Vector2i = Vector2i(
		int(rect.position.x) / TILE_SIZE,
		int(rect.position.y) / TILE_SIZE
	)
	var width_tiles: int = int(rect.size.x) / TILE_SIZE
	var height_tiles: int = int(rect.size.y) / TILE_SIZE
	for row: int in range(height_tiles):
		for column: int in range(width_tiles):
			var atlas_row: int = 0 if row == 0 else 1
			var atlas_column: int = _atlas_column(column, width_tiles)
			_terrain.set_cell(
				origin + Vector2i(column, row),
				source_id,
				Vector2i(atlas_column, atlas_row)
			)


func _atlas_column(column: int, width_tiles: int) -> int:
	if column == 0:
		return 0
	if column == width_tiles - 1:
		return 11
	return 1 + ((column - 1) % 10)


func _add_collision_rect(rect: Rect2, index: int) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "AnchorPlatformCollision%d" % index
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 0
	body.collision_mask = 0

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	_collision_bodies.append(body)


func _build_labels() -> void:
	_start_label = _make_label(
		"START\nQ: CYAN = ATTRACT\nJUMP + HOLD D",
		Vector2(10.0, 196.0),
		Vector2(158.0, 46.0),
		7,
		MUTED
	)
	_dest_label = _make_label(
		"WIDE LEDGE\nDESTINATION",
		Vector2(446.0, 306.0),
		Vector2(150.0, 24.0),
		8,
		GOLD
	)
	_dest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stone_label = _make_label(
		"FIXED + ANCHOR",
		Vector2(260.0, 162.0),
		Vector2(120.0, 11.0),
		7,
		GOLD
	)
	_stone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_route_label = _make_label(
		"CROSS THE STONE, THEN Q TO REPEL",
		Vector2(190.0, 118.0),
		Vector2(260.0, 11.0),
		7,
		MUTED
	)
	_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_label(
	text: String,
	pos: Vector2,
	box_size: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = box_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", LABEL_OUTLINE)
	label.add_theme_constant_override("outline_size", 1)
	add_child(label)
	return label


func activate(player: PrototypePlayer, hud: PrototypeHUD) -> void:
	_player = player
	_hud = hud
	_active = true
	_success = false
	_last_status = STATUS_OUT_OF_RANGE
	_last_distance = 0.0
	_last_force = Vector2.ZERO
	_last_blocked = false
	_set_collisions_active(true)
	_player.set_anchor_room_bounds(true)
	_player.clear_external_force()
	if _rune_stone != null:
		_rune_stone.show_polarity_hint = false
	if _hud != null:
		_hud.set_anchor_success(false)
		_hud.set_anchor_field(STATUS_OUT_OF_RANGE, 0.0, Vector2.ZERO)
	visible = true
	queue_redraw()


func deactivate() -> void:
	_active = false
	if _player != null:
		_player.clear_external_force()
		_player.set_anchor_room_bounds(false)
	_set_collisions_active(false)
	_success = false
	if _rune_stone != null:
		_rune_stone.show_polarity_hint = false
	if _hud != null:
		_hud.set_anchor_success(false)
	visible = false
	_player = null
	_hud = null


func _set_collisions_active(active: bool) -> void:
	for body: StaticBody2D in _collision_bodies:
		body.collision_layer = 1 if active else 0
		body.collision_mask = 1 if active else 0


func _physics_process(_delta: float) -> void:
	if not _active or _player == null:
		return

	if not _success and _is_on_destination():
		_mark_success()

	var center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var field: Dictionary = compute_field(center)
	_last_status = String(field["status"])
	_last_distance = float(field["distance"])
	var force: Vector2 = field["acceleration"]
	_last_force = force
	_last_blocked = bool(field["blocked"])

	if not _last_force.is_zero_approx():
		_player.apply_external_force(_last_force)

	# The + is a proximity label only, matching the record-room hint. It is
	# shown while the player is inside the 160 px field and is never baked
	# into the stone or used as a force sign.
	if _rune_stone != null:
		var hint_visible: bool = _last_distance < RANGE
		if _rune_stone.show_polarity_hint != hint_visible:
			_rune_stone.show_polarity_hint = hint_visible

	_update_hud()
	queue_redraw()


func compute_field(center: Vector2) -> Dictionary:
	var to_anchor: Vector2 = ANCHOR_POSITION - center
	var distance: float = to_anchor.length()
	var result: Dictionary = {
		"status": STATUS_OUT_OF_RANGE,
		"distance": distance,
		"strength": 0.0,
		"acceleration": Vector2.ZERO,
		"in_range": false,
		"blocked": false,
	}
	if distance >= RANGE:
		return result

	result["in_range"] = true
	if _is_line_blocked(center):
		result["status"] = STATUS_BLOCKED
		result["blocked"] = true
		return result

	if distance <= MIN_DISTANCE:
		result["status"] = STATUS_NEAR
		return result

	var strength: float = _strength_for(distance)
	if strength <= 0.001:
		result["status"] = STATUS_NEAR
		return result

	var direction: Vector2 = to_anchor / distance
	var player_positive: bool = true if _player == null else _player.is_positive()
	# Anchor is fixed positive: same sign repels, opposite sign attracts.
	if not player_positive:
		pass
	else:
		direction = -direction

	result["status"] = STATUS_REPEL if player_positive else STATUS_ATTRACT
	result["strength"] = strength
	result["acceleration"] = direction * BASE_ACCELERATION * strength
	return result


func _strength_for(distance: float) -> float:
	if distance >= RANGE or distance <= INNER_RADIUS:
		return 0.0
	var near_factor: float = smoothstep(INNER_RADIUS, FULL_RADIUS, distance)
	var outer_factor: float = 1.0 - smoothstep(RANGE - OUTER_FADE, RANGE, distance)
	return near_factor * outer_factor


func _is_line_blocked(center: Vector2) -> bool:
	if _player == null:
		return false
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if space == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		center, ANCHOR_POSITION, 1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array[RID] = [_player.get_rid()]
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty()


func _is_on_destination() -> bool:
	if _player == null or not _player.is_on_floor():
		return false
	var position: Vector2 = _player.global_position
	return (
		position.x >= DEST_RECT.position.x - 1.0
		and position.x <= DEST_RECT.end.x + 1.0
		and absf(position.y - DEST_RECT.position.y) <= 1.5
	)


func _mark_success() -> void:
	_success = true
	if _hud != null:
		_hud.set_anchor_success(true)
	success_reached.emit()


func _update_hud() -> void:
	if _hud == null:
		return
	_hud.set_anchor_field(_last_status, _last_distance, _last_force)
	if not _success:
		_hud.set_anchor_success(false)


func on_player_reset(_reason: String) -> void:
	_success = false
	_last_status = STATUS_OUT_OF_RANGE
	_last_force = Vector2.ZERO
	_last_blocked = false
	if _player != null:
		_player.clear_external_force()
	if _rune_stone != null:
		_rune_stone.show_polarity_hint = false
	if _hud != null:
		_hud.set_anchor_success(false)
	trial_reset.emit()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	# The fixed anchor stone is the shared RuneStoneVisual child at
	# ANCHOR_POSITION. There is deliberately no second procedural stone here.
	if _player != null and _player.is_debug_enabled():
		_draw_debug()


func _draw_debug() -> void:
	draw_arc(ANCHOR_POSITION, RANGE, 0.0, TAU, 96, Color(0.40, 0.88, 0.90, 0.50), 1.0)
	var center: Vector2 = _player.global_position + BODY_CENTER_OFFSET
	var line_color: Color = BLOCKED_COLOR if _last_blocked else Color(0.55, 1.0, 0.72, 0.75)
	draw_line(center, ANCHOR_POSITION, line_color, 1.0)
	draw_circle(center, 2.0, line_color)
	if not _last_force.is_zero_approx():
		var direction: Vector2 = _last_force.normalized()
		var length: float = clampf(_last_force.length() / BASE_ACCELERATION * 30.0, 8.0, 30.0)
		var tip: Vector2 = center + direction * length
		var force_color: Color = CYAN if _last_status == STATUS_ATTRACT else GOLD
		draw_line(center, tip, force_color, 1.5)
		draw_line(tip, tip - direction.rotated(0.55) * 5.0, force_color, 1.0)
		draw_line(tip, tip - direction.rotated(-0.55) * 5.0, force_color, 1.0)
	draw_circle(ANCHOR_POSITION, 2.5, GOLD)


func get_spawn_position() -> Vector2:
	return SPAWN_POSITION


func get_anchor_position() -> Vector2:
	return ANCHOR_POSITION


func get_rune_stone() -> RuneStoneVisual:
	return _rune_stone


func get_range() -> float:
	return RANGE


func get_platform_rects() -> Array[Rect2]:
	return PLATFORM_RECTS.duplicate()


func get_destination_rect() -> Rect2:
	return DEST_RECT


func get_status() -> String:
	return _last_status


func get_last_distance() -> float:
	return _last_distance


func get_last_force() -> Vector2:
	return _last_force


func is_success() -> bool:
	return _success


func is_active() -> bool:
	return _active


func get_collision_body_count() -> int:
	return _collision_bodies.size()

