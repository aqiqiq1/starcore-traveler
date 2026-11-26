class_name PlayerHealthBar
extends Control

## Shared player health VALUE bar for every combat level.
##
## Creator decision (2026-11-26): use one red segmented bar everywhere, not
## hearts or orange cells.  Layout reference: Hades/Dead Cells put a compact
## red bar at the screen edge, with a dark frame and a warm highlight; the
## empty part stays dark so the lost segment is obvious.  The bar is fixed at
## the lower-left HUD corner and never floats over the character.
##
## Boss/core counters stay separate; this control only shows the player's
## current lives-within-the-stage.

const SEGMENT_SIZE: Vector2 = Vector2(14.0, 8.0)
const SEGMENT_GAP: float = 2.0
## Fixed lower-left HUD slot shared by every chapter with an enemy.
const HUD_POSITION: Vector2 = Vector2(14.0, 324.0)
const LABEL_POSITION: Vector2 = Vector2(14.0, 310.0)
const LABEL_FONT_SIZE: int = 12

@export var max_segments: int = 3
@export var current: int = 3
@export var filled_color: Color = Color("#d95757")
@export var low_color: Color = Color("#ff7b7b")
@export var empty_color: Color = Color(0.13, 0.07, 0.08, 0.98)
@export var frame_color: Color = Color(0.02, 0.035, 0.04, 1.0)
@export var trim_color: Color = Color("#f4cd63")
@export var highlight_color: Color = Color(1.0, 0.88, 0.78, 0.75)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_size()
	queue_redraw()


func set_state(current_value: int, max_value: int) -> void:
	max_segments = maxi(max_value, 1)
	current = clampi(current_value, 0, max_segments)
	_refresh_size()
	queue_redraw()


func get_current() -> int:
	return current


func get_max() -> int:
	return max_segments


func get_style_name() -> String:
	return "bar"


func is_heart_style() -> bool:
	return false


func get_segment_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in range(max_segments):
		rects.append(Rect2(
			Vector2(float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP), 0.0),
			SEGMENT_SIZE
		))
	return rects


func _refresh_size() -> void:
	custom_minimum_size = Vector2(
		float(max_segments) * SEGMENT_SIZE.x
		+ float(maxi(max_segments - 1, 0)) * SEGMENT_GAP,
		SEGMENT_SIZE.y + 4.0
	)
	size = custom_minimum_size


func _draw() -> void:
	for index: int in range(max_segments):
		var origin: Vector2 = Vector2(
			float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP), 0.0
		)
		var outer: Rect2 = Rect2(origin, SEGMENT_SIZE)
		draw_rect(outer, frame_color)
		var inner: Rect2 = Rect2(
			origin + Vector2.ONE,
			SEGMENT_SIZE - Vector2(2.0, 2.0)
		)
		var color: Color = empty_color
		if index < current:
			# The last remaining segment gets the bright low-health red.
			color = low_color if current <= 1 else filled_color
		draw_rect(inner, color)
		if index < current:
			draw_rect(
				Rect2(inner.position, Vector2(inner.size.x, 1.0)),
				highlight_color
			)
	# A 1 px gold underline ties the bar to the game's gold UI trim.
	draw_rect(
		Rect2(Vector2(0.0, SEGMENT_SIZE.y + 1.0), Vector2(size.x, 1.0)),
		Color(trim_color, 0.65)
	)
