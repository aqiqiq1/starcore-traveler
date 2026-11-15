@tool
class_name LevelTerrainBlock
extends StaticBody2D

## A single editable platform block for the formal level.
##
## The node origin is the top-left corner. `block_size` is the single source of
## truth: _draw() paints the same rectangle and the child CollisionShape2D is
## resized/centred from it. Moving the node moves both the art and the collision
## because both live in this node's local space. Sizes are snapped to the 16 px
## tile grid so a partially painted edge cannot disagree with the collider.
##
## Use one node per platform / wall. It intentionally does not build a TileMap
## or a second hardcoded collision table at runtime.

const ATLAS: Texture2D = preload("res://assets/map/ruin_platform_tiles.png")
const TILE_SIZE: int = 16
const ATLAS_COLUMNS: int = 12

@export var block_size: Vector2 = Vector2(256.0, 64.0):
	set(value):
		block_size = _snap_size(value)
		_refresh_collision()
		queue_redraw()

@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_refresh_collision()
		queue_redraw()

@export var draw_visual: bool = true:
	set(value):
		draw_visual = value
		queue_redraw()

@export var surface_row: int = 0
@export var fill_row: int = 1

var _collision_shape: CollisionShape2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 1 if collision_enabled else 0
	collision_mask = 1 if collision_enabled else 0
	_ensure_collision_node()
	_refresh_collision()
	queue_redraw()


func _snap_size(value: Vector2) -> Vector2:
	return Vector2(
		maxf(TILE_SIZE, roundf(value.x / float(TILE_SIZE)) * float(TILE_SIZE)),
		maxf(TILE_SIZE, roundf(value.y / float(TILE_SIZE)) * float(TILE_SIZE))
	)


func _ensure_collision_node() -> void:
	if is_instance_valid(_collision_shape):
		return
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		# In the editor this makes a newly created shape part of the edited
		# scene instead of a runtime-only ghost.
		if Engine.is_editor_hint() and owner != null:
			_collision_shape.owner = owner


func _refresh_collision() -> void:
	if not is_inside_tree():
		return
	_ensure_collision_node()
	if _collision_shape == null:
		return
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rect != null and rect.size != block_size:
		# Duplicated editor blocks can share one RectangleShape2D. Copy before
		# writing so block_size only changes this instance's collision.
		rect = rect.duplicate() as RectangleShape2D
		_collision_shape.shape = rect
	if rect == null:
		rect = RectangleShape2D.new()
		_collision_shape.shape = rect
	rect.size = block_size
	_collision_shape.position = block_size * 0.5
	_collision_shape.disabled = not collision_enabled
	collision_layer = 1 if collision_enabled else 0
	collision_mask = 1 if collision_enabled else 0


func _draw() -> void:
	if not draw_visual or ATLAS == null:
		return
	var tiles_x: int = int(block_size.x) / TILE_SIZE
	var tiles_y: int = int(block_size.y) / TILE_SIZE
	for row: int in range(tiles_y):
		for column: int in range(tiles_x):
			var atlas_column: int
			if row == 0:
				atlas_column = _surface_column(column, tiles_x)
			else:
				atlas_column = 0 if column == 0 else (ATLAS_COLUMNS - 1 if column == tiles_x - 1 else 1 + ((column + row * 3) % (ATLAS_COLUMNS - 2)))
			var atlas_row: int = surface_row if row == 0 else fill_row
			draw_texture_rect_region(
				ATLAS,
				Rect2(
					Vector2(float(column * TILE_SIZE), float(row * TILE_SIZE)),
					Vector2(float(TILE_SIZE), float(TILE_SIZE))
				),
				Rect2(
					Vector2(float(atlas_column * TILE_SIZE), float(atlas_row * TILE_SIZE)),
					Vector2(float(TILE_SIZE), float(TILE_SIZE))
				)
			)


func _surface_column(column: int, width_tiles: int) -> int:
	if column == 0:
		return 0
	if column == width_tiles - 1:
		return ATLAS_COLUMNS - 1
	return 1 + ((column - 1) % (ATLAS_COLUMNS - 2))


## Helpers used by the level tests and by the editor documentation.
func get_block_size() -> Vector2:
	return block_size


func get_collision_size() -> Vector2:
	if _collision_shape == null:
		return Vector2.ZERO
	var rect: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	return rect.size if rect != null else Vector2.ZERO


func get_collision_top_left() -> Vector2:
	if _collision_shape == null:
		return global_position
	return _collision_shape.global_position - block_size * 0.5
