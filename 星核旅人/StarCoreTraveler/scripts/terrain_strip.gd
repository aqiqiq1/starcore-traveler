@tool
class_name TerrainStrip
extends Node2D

## Editor-visible repeating tile strip for the interaction test room.
##
## The room's floor is a scene node with an exported texture region and size,
## not a runtime-generated map. It draws in the editor and at runtime. Collision
## is a separate StaticBody2D/CollisionShape2D node in the room scene.

@export var texture: Texture2D
@export var region: Rect2 = Rect2(0.0, 0.0, 16.0, 16.0)
@export var strip_size: Vector2 = Vector2(640.0, 16.0)


func _draw() -> void:
	if texture == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	var tiles_x: int = ceili(strip_size.x / region.size.x)
	var tiles_y: int = ceili(strip_size.y / region.size.y)
	for row: int in range(tiles_y):
		for column: int in range(tiles_x):
			draw_texture_rect_region(
				texture,
				Rect2(
					Vector2(float(column) * region.size.x, float(row) * region.size.y),
					region.size
				),
				region
			)
