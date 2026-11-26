class_name LoomStatusIcon
extends Control

## Tiny 10x10 glyph that labels one icon-only HUD group.  The row no longer
## spells "受击 0 / 3"; each group is a glyph plus a HitPips row, so the count
## is read from shapes at 1x.  All glyphs are integer rects, no anti-aliasing.

enum Kind { STAGE, NODE, CORE, HIT }

@export var kind: Kind = Kind.STAGE
@export var color: Color = Color("#f4cd63")

var _white: Color = Color(1.0, 0.98, 0.92, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(10.0, 10.0)
	size = custom_minimum_size
	queue_redraw()


func set_color(value: Color) -> void:
	color = value
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.STAGE:
			_draw_stage()
		Kind.NODE:
			_draw_node()
		Kind.CORE:
			_draw_core()
		Kind.HIT:
			_draw_hit()
		_:
			pass


## A tiny loom: top beam, two posts and three warp threads.
func _draw_stage() -> void:
	draw_rect(Rect2(1.0, 1.0, 8.0, 1.0), color)
	draw_rect(Rect2(1.0, 2.0, 1.0, 7.0), color)
	draw_rect(Rect2(8.0, 2.0, 1.0, 7.0), color)
	draw_rect(Rect2(1.0, 8.0, 8.0, 1.0), color)
	for x: float in [3.0, 5.0, 7.0]:
		draw_rect(Rect2(x, 3.0, 1.0, 4.0), Color(color, 0.85))


## Orbit node: diamond outline with a bright centre.
func _draw_node() -> void:
	_diamond_outline(4.0, color)
	draw_rect(Rect2(4.0, 4.0, 1.0, 1.0), _white)


## Loom core: diamond with four corner ticks.
func _draw_core() -> void:
	_diamond_outline(4.0, color)
	for corner: Vector2 in [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
		Vector2(-1.0, 1.0), Vector2(1.0, 1.0),
	]:
		draw_rect(
			Rect2(5.0 + corner.x * 4.0, 5.0 + corner.y * 4.0, 1.0, 1.0),
			_white
		)
	draw_rect(Rect2(4.0, 4.0, 2.0, 2.0), _white)


## Damage taken: a small shield with a bright rivet.
func _draw_hit() -> void:
	var rows: Array[String] = [
		".xxxxx.",
		"xxxxxxx",
		"xxxxxxx",
		"xxxxxxx",
		".xxxxx.",
		"..xxx..",
		"...x...",
	]
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			if rows[y][x] != "x":
				continue
			draw_rect(
				Rect2(1.0 + float(x), 1.0 + float(y), 1.0, 1.0),
				color
			)
	draw_rect(Rect2(4.0, 3.0, 2.0, 2.0), _white)


func _diamond_outline(radius: float, line_color: Color) -> void:
	var r: int = int(radius)
	for y: int in range(-r, r + 1):
		var width: int = r - absi(y)
		var row_y: float = 5.0 + float(y)
		draw_rect(Rect2(5.0 - float(width), row_y, 1.0, 1.0), line_color)
		if width > 0:
			draw_rect(Rect2(5.0 + float(width), row_y, 1.0, 1.0), line_color)
