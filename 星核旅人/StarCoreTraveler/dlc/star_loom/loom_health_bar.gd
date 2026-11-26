class_name LoomHealthBar
extends Control

## Three-cell segmented health meter for 星核织机.
##
## This is the player's health VALUE, not the run's life count: each accepted
## hit removes one full cell, and the stage-1 clear refills all three.  The
## three hearts in the top icon row stay the separate life COUNT.  Cells are
## plain integer rectangles (12x8 with a 1 px dark frame), so the meter never
## reads as three hearts.

const SEGMENT_SIZE: Vector2 = Vector2(12.0, 8.0)
const SEGMENT_GAP: float = 2.0
const DEFAULT_MAX: int = 3

@export var max_segments: int = DEFAULT_MAX
@export var current: int = DEFAULT_MAX
@export var filled_color: Color = Color("#ff8f6b")
@export var empty_color: Color = Color(0.30, 0.36, 0.38, 0.97)
@export var border_color: Color = Color(0.018, 0.045, 0.052, 0.98)
@export var highlight_color: Color = Color(1.0, 0.93, 0.84, 0.70)


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


## Test hook: the meter is made of rectangles, never heart pips.
func get_style_name() -> String:
	return "segments"


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
		SEGMENT_SIZE.y
	)
	size = custom_minimum_size


func _draw() -> void:
	for index: int in range(max_segments):
		var origin: Vector2 = Vector2(
			float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP), 0.0
		)
		# 1 px dark frame around every cell keeps the empty slots readable on
		# both the dark city wall and the warm floor.
		draw_rect(Rect2(origin, SEGMENT_SIZE), border_color)
		var inner: Rect2 = Rect2(
			origin + Vector2.ONE,
			SEGMENT_SIZE - Vector2(2.0, 2.0)
		)
		draw_rect(inner, filled_color if index < current else empty_color)
		if index < current:
			# A one-pixel top highlight separates the filled cells from the
			# background without adding another outline colour.
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), highlight_color)
