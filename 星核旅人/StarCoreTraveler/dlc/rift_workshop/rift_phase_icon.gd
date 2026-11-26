class_name RiftPhaseIcon
extends Control

## 16 x 16 phase icon for the rift HUD: gold sun = 辉相, cyan moon = 澜相.
## The same reading as the trial gate / core icons (large emblem, no text),
## reduced to the HUD's 16 px slot.  All pixels are drawn here; no texture.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const INK: Color = Color(0.012, 0.030, 0.038, 0.96)
const WHITE: Color = Color(1.0, 0.99, 0.94)

var _positive: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(16.0, 16.0)
	size = Vector2(16.0, 16.0)
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
	var center: Vector2 = Vector2(8.0, 8.0)
	if _positive:
		_draw_sun(center)
	else:
		_draw_moon(center)


func _draw_sun(center: Vector2) -> void:
	# 11 px dark-rimmed disc + eight 2 px rays, inside 16 x 16.
	_pixel_disc(center, 6, INK)
	_pixel_disc(center, 5, GOLD)
	# Four cardinal and four diagonal rays; alternate lengths keep the sun
	# readable at 1x without a halo.
	for offset: Vector2 in [
		Vector2(-1.0, -7.0), Vector2(-1.0, 6.0),
		Vector2(-7.0, -1.0), Vector2(6.0, -1.0),
	]:
		draw_rect(Rect2(center + offset, Vector2(2.0, 2.0)), GOLD)
	for offset: Vector2 in [
		Vector2(-5.0, -5.0), Vector2(4.0, -5.0),
		Vector2(-5.0, 4.0), Vector2(4.0, 4.0),
	]:
		draw_rect(Rect2(center + offset, Vector2(1.0, 1.0)), GOLD)
	# White core + one highlight pixel: same hierarchy as the gate emblem.
	draw_rect(Rect2(center + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), WHITE)
	draw_rect(Rect2(center + Vector2(2.0, -3.0), Vector2.ONE), Color(WHITE, 0.65))


func _draw_moon(center: Vector2) -> void:
	# 13 px crescent: a cyan disc minus a dark cut-out offset up-right.  The
	# cut-out is ink, not transparent, so it reads on the bright sky.
	_pixel_disc(center + Vector2(0.0, 0.0), 6, INK)
	_pixel_disc(center + Vector2(0.0, 0.0), 5, CYAN)
	_pixel_disc(center + Vector2(3.0, -1.0), 4, INK)
	# Left rim light follows the same crescent edge.
	for y: int in range(-5, 6):
		var span: int = int(round(sqrt(maxf(25.0 - float(y * y), 0.0))))
		draw_rect(
			Rect2(center.x - float(span), center.y + float(y), 1.0, 1.0),
			Color(CYAN.lightened(0.35), 0.9)
		)
	# Two 3 px stars, top-right and bottom-right; no text.
	for star: Vector2 in [Vector2(4.0, -6.0), Vector2(6.0, 4.0)]:
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
