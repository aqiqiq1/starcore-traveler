class_name DebugOverlay
extends Node2D

## Developer-only overlay. Drawn in VisualRoot space so the chest marker
## follows the character's facing; the collision rectangle stays symmetric.

var chest_marker: Vector2 = Vector2.ZERO
var collision_rect: Rect2 = Rect2(-6.0, -30.0, 12.0, 30.0)


func update_overlay(chest: Vector2, body_rect: Rect2) -> void:
	chest_marker = chest
	collision_rect = body_rect
	queue_redraw()


func _draw() -> void:
	var body_color: Color = Color(0.25, 1.0, 0.95, 0.95)
	var cross_color: Color = Color(1.0, 0.82, 0.24, 1.0)
	draw_rect(collision_rect, body_color, false, 1.0)
	draw_line(chest_marker + Vector2(-4.0, 0.0), chest_marker + Vector2(4.0, 0.0), cross_color, 1.0)
	draw_line(chest_marker + Vector2(0.0, -4.0), chest_marker + Vector2(0.0, 4.0), cross_color, 1.0)
	draw_rect(Rect2(chest_marker - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), cross_color, false, 1.0)
