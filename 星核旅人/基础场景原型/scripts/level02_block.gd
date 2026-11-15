@tool
class_name Level02Block
extends StaticBody2D

## Small editable terrain block for level 02.
##
## Unlike LevelTerrainBlock (which snaps to the 16 px atlas grid), this block
## keeps the exact pixel size authored in the scene. That is required for the
## low-corridor throat (20 px clear height) and for the perforated upper deck
## (8 px stone beams with 8 px real gaps). The origin is the top-left corner;
## collision and legacy drawing use the same rectangle. V3 slices below are
## separate non-collision art and may extend past the thin beam for presentation.
##
## Legacy art reuses the approved ruin atlas with its native 16 px tiles, Nearest
## filtering and white modulate. With `legacy_art_enabled` on, sizes that are not
## a multiple of 16 crop the source tile instead of scaling it, so every visible
## legacy pixel still matches the real collision rectangle and a gap is genuinely
## empty space (no full-sheet overlay pretending to be perforated).
##
## Level 02 V3 keeps the same nodes and collision but draws the approved
## continuous bridge slices from separate child Sprite2D nodes instead. Setting
## `legacy_art_enabled = false` in this scene only stops this body's old brown
## atlas drawing; it does not hide the node, change collision, or affect any
## other scene. The default stays true so existing copies/other levels are
## unchanged.

const ATLAS: Texture2D = preload("res://assets/map/ruin_platform_tiles.png")
const TILE_SIZE: int = 16
const ATLAS_COLUMNS: int = 12

@export var legacy_art_enabled: bool = true:
	set(value):
		legacy_art_enabled = value
		queue_redraw()

@export var block_size: Vector2 = Vector2(64.0, 16.0):
	set(value):
		block_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_refresh_collision()
		queue_redraw()

@export var surface_row: int = 0
@export var fill_row: int = 1

var _collision_shape: CollisionShape2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = Color.WHITE
	collision_layer = 1
	collision_mask = 1
	_ensure_collision_node()
	_refresh_collision()
	queue_redraw()


func _ensure_collision_node() -> void:
	# A duplicated editor Block can carry a copied CollisionShape2D child while
	# the script's cached reference still points at the original child. Re-resolve
	# unless the cached node is actually this block's own child.
	if is_instance_valid(_collision_shape) and _collision_shape.get_parent() == self:
		return
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		if Engine.is_editor_hint() and owner != null:
			_collision_shape.owner = owner


func _refresh_collision() -> void:
	if not is_inside_tree():
		return
	_ensure_collision_node()
	if _collision_shape == null:
		return
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
	else:
		# Editor duplicate copies the child shape resource by reference. Never
		# mutate that shared resource in place: give this block its own copy
		# first, then write its size. This path runs on ready/property changes,
		# never per frame.
		rect = rect.duplicate() as RectangleShape2D
	_collision_shape.shape = rect
	rect.resource_local_to_scene = true
	rect.size = block_size
	_collision_shape.position = block_size * 0.5


func _draw() -> void:
	if legacy_art_enabled and ATLAS != null:
		_draw_legacy_atlas()
	# Editor-only helper outline. It is never drawn in the running game. The
	# shipped scene shows the approved V3 child slices (or legacy tile art when
	# enabled); the real physics gaps stay genuinely empty even where V3 covers
	# them visually.
	if Engine.is_editor_hint():
		draw_rect(
			Rect2(Vector2.ZERO, block_size),
			Color(0.55, 0.90, 0.88, 0.30),
			false,
			1.0
		)


func _draw_legacy_atlas() -> void:
	var columns: int = ceili(block_size.x / float(TILE_SIZE))
	var rows: int = ceili(block_size.y / float(TILE_SIZE))
	for row: int in range(rows):
		var local_y: float = float(row * TILE_SIZE)
		var tile_h: float = minf(float(TILE_SIZE), block_size.y - local_y)
		if tile_h <= 0.0:
			continue
		for column: int in range(columns):
			var local_x: float = float(column * TILE_SIZE)
			var tile_w: float = minf(float(TILE_SIZE), block_size.x - local_x)
			if tile_w <= 0.0:
				continue
			var atlas_column: int
			if row == 0:
				atlas_column = _surface_column(column, columns)
			else:
				atlas_column = 0 if column == 0 else (
					ATLAS_COLUMNS - 1 if column == columns - 1
					else 1 + ((column + row * 3) % (ATLAS_COLUMNS - 2))
				)
			var atlas_row: int = surface_row if row == 0 else fill_row
			draw_texture_rect_region(
				ATLAS,
				Rect2(Vector2(local_x, local_y), Vector2(tile_w, tile_h)),
				Rect2(
					Vector2(float(atlas_column * TILE_SIZE), float(atlas_row * TILE_SIZE)),
					Vector2(tile_w, tile_h)
				)
			)


func _surface_column(column: int, width_tiles: int) -> int:
	if column == 0:
		return 0
	if column == width_tiles - 1:
		return ATLAS_COLUMNS - 1
	return 1 + ((column - 1) % (ATLAS_COLUMNS - 2))


func get_block_size() -> Vector2:
	return block_size


func is_legacy_art_enabled() -> bool:
	return legacy_art_enabled


func get_collision_size() -> Vector2:
	if _collision_shape == null:
		return Vector2.ZERO
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	return rect.size if rect != null else Vector2.ZERO


func get_collision_top_left() -> Vector2:
	if _collision_shape == null:
		return global_position
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rect == null:
		return global_position
	return _collision_shape.global_position - rect.size * 0.5


func get_block_rect() -> Rect2:
	return Rect2(global_position, block_size)


func get_atlas_path() -> String:
	return ATLAS.resource_path if ATLAS != null else ""


func get_texture_tile_size() -> int:
	return TILE_SIZE


func has_native_texture_tiling() -> bool:
	return (
		ATLAS != null
		and texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and modulate == Color.WHITE
	)
