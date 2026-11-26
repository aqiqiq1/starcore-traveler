class_name TrialPolarityIcon
extends Control

## Icon-only affinity badge for the trial header.
##
## The shared CompactLevelHeader prints "辉相 / 澜相" next to a talisman.  The
## 2026-11-26 rework asks for the same reading as the gates: a gold sun means
## 辉相, a cyan moon means 澜相, with no text.  This 16x16 control draws that
## icon only; TrialHUD hides the shared header's text/icon and places this in
## the same top-right corner.
##
## The sun/moon silhouettes follow the gate emblem's language (full sun with
## eight rays, crescent moon with small stars) at header scale; no third-party
## texture is used.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PLATE: Color = Color(0.012, 0.028, 0.032, 0.94)
const EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)
const ICON_SIZE: Vector2 = Vector2(16.0, 16.0)

var _positive: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	queue_redraw()


func set_positive(value: bool) -> void:
	_positive = value
	queue_redraw()


func is_positive() -> bool:
	return _positive


func get_icon_size() -> Vector2:
	return ICON_SIZE


func _draw() -> void:
	var color: Color = GOLD if _positive else CYAN
	draw_rect(Rect2(Vector2.ZERO, ICON_SIZE), EDGE)
	draw_rect(Rect2(Vector2.ONE, ICON_SIZE - Vector2(2.0, 2.0)), PLATE)
	draw_rect(Rect2(Vector2.ONE, ICON_SIZE - Vector2(2.0, 2.0)),
		Color(color, 0.9), false, 1.0)
	if _positive:
		_draw_sun(color)
	else:
		_draw_moon(color)


func _draw_sun(color: Color) -> void:
	var center: Vector2 = Vector2(8.0, 8.0)
	for y: int in range(-3, 4):
		var span: int = int(round(sqrt(maxf(9.0 - float(y * y), 0.0))))
		draw_rect(Rect2(center.x - float(span), center.y + float(y),
			float(span * 2 + 1), 1.0), color)
	for rect: Rect2 in [
		Rect2(7.0, 1.0, 2.0, 2.0), Rect2(7.0, 13.0, 2.0, 2.0),
		Rect2(1.0, 7.0, 2.0, 2.0), Rect2(13.0, 7.0, 2.0, 2.0),
		Rect2(2.0, 2.0, 2.0, 2.0), Rect2(12.0, 2.0, 2.0, 2.0),
		Rect2(2.0, 12.0, 2.0, 2.0), Rect2(12.0, 12.0, 2.0, 2.0),
	]:
		draw_rect(rect, color)
	draw_rect(Rect2(7.0, 7.0, 2.0, 2.0), WHITE)


func _draw_moon(color: Color) -> void:
	# A 9 px outer disc carved by a 9 px inner disc, leaving the left crescent.
	for y: int in range(-4, 5):
		var span: int = int(round(sqrt(maxf(16.0 - float(y * y), 0.0))))
		draw_rect(Rect2(8.0 - float(span), 8.0 + float(y),
			float(span * 2 + 1), 1.0), color)
	for y: int in range(-4, 5):
		var inner_y: int = y - 1
		var span: int = int(round(sqrt(maxf(16.0 - float(inner_y * inner_y), 0.0))))
		draw_rect(Rect2(10.0 - float(span), 8.0 + float(y),
			float(span * 2 + 1), 1.0), PLATE)
	# Two small stars in the upper-right.
	for star: Vector2 in [Vector2(11.0, 3.0), Vector2(13.0, 6.0)]:
		draw_rect(Rect2(star, Vector2(2.0, 1.0)), WHITE)
		draw_rect(Rect2(star + Vector2(1.0, -1.0), Vector2(1.0, 3.0)), WHITE)
