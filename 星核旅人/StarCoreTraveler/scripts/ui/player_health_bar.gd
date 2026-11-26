class_name PlayerHealthBar
extends Control

## Shared player health VALUE bar for every chapter.
##
## Approved layout (dlc/PRESENTATION_SYSTEM.md + UI_HEALTH_BAR_REFERENCE):
##   fixed lower-left group anchored at (14,324); 10x10 red heart at the left,
##   then 2 / 3 red segments of 14x8 with a 2 px gap.  No "生命值" word is ever
##   printed: the heart plus the empty/filled count carries the read.
##
## The control position stays (14,324); the heart occupies the first 10 px and
## the first segment starts at x=14 inside the control.  This keeps the group
## on the approved 14 px margin and the bar segments pixel-aligned.

const SEGMENT_SIZE: Vector2 = Vector2(14.0, 8.0)
const SEGMENT_GAP: float = 2.0
const HEART_SIZE: Vector2 = Vector2(10.0, 10.0)
const HEART_GAP: float = 4.0
const HEART_OFFSET_X: float = HEART_SIZE.x + HEART_GAP
## Fixed lower-left HUD slot shared by every chapter.
const HUD_POSITION: Vector2 = Vector2(14.0, 324.0)

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


## Segment rects are local to the control: the first one starts after the
## 10 px heart + 4 px gap, so the heart is always left of the red cells.
func get_segment_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in range(max_segments):
		rects.append(Rect2(
			Vector2(
				HEART_OFFSET_X + float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP),
				1.0
			),
			SEGMENT_SIZE
		))
	return rects


func get_heart_rect() -> Rect2:
	return Rect2(Vector2(0.0, 1.0), HEART_SIZE)


func _refresh_size() -> void:
	var bar_width: float = float(max_segments) * SEGMENT_SIZE.x
	bar_width += float(maxi(max_segments - 1, 0)) * SEGMENT_GAP
	custom_minimum_size = Vector2(
		HEART_OFFSET_X + bar_width,
		SEGMENT_SIZE.y + 4.0
	)
	size = custom_minimum_size


func _draw() -> void:
	_draw_heart()
	for index: int in range(max_segments):
		var origin: Vector2 = Vector2(
			HEART_OFFSET_X + float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP),
			1.0
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
		Rect2(
			Vector2(HEART_OFFSET_X, SEGMENT_SIZE.y + 2.0),
			Vector2(size.x - HEART_OFFSET_X, 1.0)
		),
		Color(trim_color, 0.65)
	)


## 10x9 heart with a 1 px dark rim.  Filled while any segment remains; an empty
## dark heart at 0 keeps the lost state readable without printing a word.
func _draw_heart() -> void:
	var origin: Vector2 = Vector2(0.0, 1.0)
	var dark_rows: Array[String] = [
		"..xx..xx..",
		".xxxxxxxx.",
		"xxxxxxxxxx",
		"xxxxxxxxxx",
		"xxxxxxxxxx",
		".xxxxxxxx.",
		"..xxxxxx..",
		"...xxxx...",
		"....xx....",
	]
	var fill_rows: Array[String] = [
		".xx..xx.",
		"xxxxxxxx",
		"xxxxxxxx",
		"xxxxxxxx",
		".xxxxxx.",
		"..xxxx..",
		"...xx...",
	]
	for y: int in range(dark_rows.size()):
		for x: int in range(dark_rows[y].length()):
			if dark_rows[y][x] == "x":
				draw_rect(
					Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE),
					frame_color
				)
	var fill_color: Color = low_color if current <= 1 else filled_color
	if current <= 0:
		fill_color = Color(0.28, 0.12, 0.14, 0.95)
	for y: int in range(fill_rows.size()):
		for x: int in range(fill_rows[y].length()):
			if fill_rows[y][x] == "x":
				draw_rect(
					Rect2(
						origin + Vector2(float(x) + 1.0, float(y) + 1.0),
						Vector2.ONE
					),
					fill_color
				)
