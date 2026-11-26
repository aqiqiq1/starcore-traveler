class_name RiftPhaseIcon
extends Control

## 20 x 20 phase icon for the rift HUD: gold sun = 辉相, cyan moon = 澜相.
## The same reading as the trial gate / core icons (large emblem, no text).
## All pixels are drawn here; no texture.  The icon grew from 16 to 20 px in
## the 2026-11-26 rework so the sun/moon state is readable at 640x360.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const INK: Color = Color(0.012, 0.030, 0.038, 0.96)
const WHITE: Color = Color(1.0, 0.99, 0.94)

var _positive: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20.0, 20.0)
	size = Vector2(20.0, 20.0)
	queue_redraw()


func set_positive(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	queue_redraw()


func is_positive() -> bool:
	return _positive


## "sun" / "moon" for tests and captures; matches the gate emblem vocabulary.
func get_kind() -> String:
	return "sun" if _positive else "moon"


func _draw() -> void:
	var center: Vector2 = size * 0.5
	if _positive:
		_draw_sun(center)
	else:
		_draw_moon(center)


func _draw_sun(center: Vector2) -> void:
	# 13 px dark-rimmed disc + eight 2 px rays, inside 20 x 20.
	_pixel_disc(center, 7, INK)
	_pixel_disc(center, 6, GOLD)
	# Four cardinal rays and four short diagonal rays.
	for offset: Vector2 in [
		Vector2(-1.0, -9.0), Vector2(-1.0, 8.0),
		Vector2(-9.0, -1.0), Vector2(8.0, -1.0),
	]:
		draw_rect(Rect2(center + offset, Vector2(2.0, 2.0)), GOLD)
	for offset: Vector2 in [
		Vector2(-6.0, -6.0), Vector2(5.0, -6.0),
		Vector2(-6.0, 5.0), Vector2(5.0, 5.0),
	]:
		draw_rect(Rect2(center + offset, Vector2(1.0, 1.0)), GOLD)
	# White core + one highlight pixel.
	draw_rect(Rect2(center + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), WHITE)
	draw_rect(Rect2(center + Vector2(2.0, -4.0), Vector2.ONE), Color(WHITE, 0.65))


func _draw_moon(center: Vector2) -> void:
	# 15 px crescent: a cyan disc minus a dark cut-out offset up-right.
	_pixel_disc(center, 7, INK)
	_pixel_disc(center, 6, CYAN)
	_pixel_disc(center + Vector2(3.0, -1.0), 5, INK)
	# Left rim light follows the crescent edge.
	for y: int in range(-6, 7):
		var span: int = int(round(sqrt(maxf(36.0 - float(y * y), 0.0))))
		draw_rect(
			Rect2(center.x - float(span), center.y + float(y), 1.0, 1.0),
			Color(CYAN.lightened(0.35), 0.9)
		)
	# Two 3 px stars, top-right and bottom-right; no text.
	for star: Vector2 in [Vector2(5.0, -8.0), Vector2(8.0, 5.0)]:
		var origin: Vector2 = center + star
		draw_rect(Rect2(origin, Vector2(3.0, 1.0)), WHITE)
		draw_rect(Rect2(origin + Vector2(1.0, -1.0), Vector2(1.0, 3.0)), WHITE)


func _pixel_disc(center: Vector2, radius: int, color: Color) -> void:
	for y: int in range(-radius, radius + 1):
		var span: int = int(round(sqrt(maxf(
			float(radius * radius) - float(y * y), 0.0
		))))
		draw_rect(
			Rect2(center.x - float(span), center.y + float(y),
				float(span * 2 + 1), 1.0),
			color
		)
