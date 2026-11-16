@tool
class_name L3CityBack
extends Node2D

## Dark inner-city back wall behind the opened gate. Drawn in code so the city
## start space is visibly different from the outdoor bridge without painting a
## new environment pack. The real interior gateway sample is a separate sprite.

@export var wall_rect: Rect2 = Rect2(2220.0, 132.0, 300.0, 188.0)
@export var wall_color: Color = Color(0.118, 0.126, 0.132, 1.0)
@export var mortar_color: Color = Color(0.078, 0.086, 0.094, 1.0)
@export var glow_center: Vector2 = Vector2(2420.0, 268.0)
@export var glow_radius: float = 92.0
@export var glow_color: Color = Color(0.98, 0.76, 0.42, 1.0)
@export var joint_spacing: float = 42.0


func _draw() -> void:
	draw_rect(wall_rect, wall_color)
	# Warm interior light: a few low-alpha discs read as depth, not a spotlight.
	for index: int in range(4):
		var radius: float = glow_radius * (1.0 - float(index) * 0.18)
		var alpha: float = 0.055 + float(index) * 0.022
		draw_circle(glow_center, radius, Color(glow_color, alpha))
	# Masonry joints.
	var y: float = wall_rect.position.y + 24.0
	var row: int = 0
	while y < wall_rect.end.y:
		draw_line(
			Vector2(wall_rect.position.x, y),
			Vector2(wall_rect.end.x, y),
			mortar_color,
			1.0
		)
		var x: float = wall_rect.position.x + joint_spacing * (1.0 if row % 2 == 0 else 0.5)
		while x < wall_rect.end.x:
			draw_line(Vector2(x, y - 24.0), Vector2(x, y), mortar_color, 1.0)
			x += joint_spacing
		y += 24.0
		row += 1
	# Floor lip and a faint warm strip at the base.
	draw_rect(
		Rect2(Vector2(wall_rect.position.x, wall_rect.end.y - 5.0), Vector2(wall_rect.size.x, 5.0)),
		Color(0.075, 0.080, 0.085, 1.0)
	)
	draw_line(
		Vector2(wall_rect.position.x, wall_rect.end.y),
		Vector2(wall_rect.end.x, wall_rect.end.y),
		Color(0.62, 0.52, 0.36, 0.45),
		1.0
	)
