class_name LoomPhaseIcon
extends Control

## 20x20 top-right affinity marker: gold sun for 辉相, cyan moon for 澜相.
## No text; the same shared glyph geometry as the exposed core.

const ICON_SIZE: Vector2 = Vector2(20.0, 20.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const WHITE: Color = Color(1.0, 0.98, 0.94, 1.0)
const INK: Color = Color(0.03, 0.02, 0.04, 0.96)

var _positive: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	queue_redraw()


func set_positive(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	queue_redraw()


func is_positive() -> bool:
	return _positive


func get_state_name() -> String:
	return "sun" if _positive else "moon"


func get_phase_color() -> Color:
	return GOLD if _positive else CYAN


func _draw() -> void:
	var center: Vector2 = Vector2(10.0, 10.0)
	if _positive:
		for pixel: Dictionary in LoomPhaseGlyph.sun_pixels(
			center, 6, 5, [8.0], INK, GOLD, GOLD, WHITE
		):
			draw_rect(pixel["rect"], pixel["color"])
	else:
		for pixel: Dictionary in LoomPhaseGlyph.moon_pixels(
			center, 9, 8, Vector2(7.0, -6.0), 7, INK, CYAN
		):
			draw_rect(pixel["rect"], pixel["color"])
