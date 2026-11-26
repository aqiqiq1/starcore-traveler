class_name PolarityPhaseIcon
extends Control

## Shared 20x20 phase badge for the three base-level HUDs.
##
## Gold sun = 辉相, cyan moon = 澜相; no text.  The geometry follows the same
## drawn language already used by the trial gates and DLC headers (a dark
## pixel plate keeps the gold/cyan glyph readable against the bright sky), but
## this implementation lives in scripts/ui and has no dependency on dlc/.
##
## Reference check (2026-11-26): Syed Sarib, "Sun moon pixel art icon"
## https://syedsarib.com/libraries/pixel-icons/sun-moon — observed the
## "bright disc + eight short rays" sun and "disc with a bitten-out crescent"
## moon read at 25 px.  Only the generic shape reading is borrowed; no pixels,
## palette or SVG are copied.  Celeste's tutorial card (local evidence
## dlc/ui/tests/out/ref/celeste_tutorial.jpg) was also re-opened for the
## icon-only, no-caption HUD read.

const ICON_SIZE: Vector2 = Vector2(20.0, 20.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PLATE: Color = Color(0.012, 0.028, 0.032, 0.94)
const EDGE: Color = Color(0.004, 0.012, 0.016, 0.96)
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)

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


## "sun" for 辉相, "moon" for 澜相; matches the gate emblem vocabulary.
func get_kind() -> String:
	return "sun" if _positive else "moon"


func get_phase_color() -> Color:
	return GOLD if _positive else CYAN


func get_icon_size() -> Vector2:
	return ICON_SIZE


func _draw() -> void:
	var color: Color = get_phase_color()
	draw_rect(Rect2(Vector2.ZERO, ICON_SIZE), EDGE)
	draw_rect(Rect2(Vector2.ONE, ICON_SIZE - Vector2(2.0, 2.0)), PLATE)
	draw_rect(
		Rect2(Vector2.ONE, ICON_SIZE - Vector2(2.0, 2.0)),
		Color(color, 0.9), false, 1.0
	)
	if _positive:
		_draw_sun(color)
	else:
		_draw_moon(color)


func _draw_sun(color: Color) -> void:
	var center: Vector2 = Vector2(10.0, 10.0)
	# 13 px dark-rimmed disc + eight 2 px rays, all inside the 18 px plate.
	_pixel_disc(center, 6, EDGE)
	_pixel_disc(center, 5, color)
	for rect: Rect2 in [
		Rect2(9.0, 2.0, 2.0, 2.0), Rect2(9.0, 16.0, 2.0, 2.0),
		Rect2(2.0, 9.0, 2.0, 2.0), Rect2(16.0, 9.0, 2.0, 2.0),
	]:
		draw_rect(rect, color)
	for rect: Rect2 in [
		Rect2(4.0, 4.0, 2.0, 2.0), Rect2(14.0, 4.0, 2.0, 2.0),
		Rect2(4.0, 14.0, 2.0, 2.0), Rect2(14.0, 14.0, 2.0, 2.0),
	]:
		draw_rect(rect, color)
	# White core + one highlight pixel: same hierarchy as the gate emblem.
	draw_rect(Rect2(9.0, 9.0, 3.0, 3.0), WHITE)
	draw_rect(Rect2(13.0, 6.0, 1.0, 1.0), Color(WHITE, 0.65))


func _draw_moon(color: Color) -> void:
	# 13 px crescent: a cyan disc minus a dark disc offset up-right.  The
	# cut-out is the plate colour, not transparent, so it reads at 1x.
	var center: Vector2 = Vector2(10.0, 10.0)
	_pixel_disc(center, 6, EDGE)
	_pixel_disc(center, 5, color)
	_pixel_disc(center + Vector2(3.0, -1.0), 4, PLATE)
	# Left rim light follows the crescent edge.
	for y: int in range(-5, 6):
		var span: int = int(round(sqrt(maxf(25.0 - float(y * y), 0.0))))
		draw_rect(
			Rect2(center.x - float(span), center.y + float(y), 1.0, 1.0),
			Color(color.lightened(0.35), 0.9)
		)
	# Two 3 px stars, upper-right and lower-right; no text.
	for star: Vector2 in [Vector2(14.0, 3.0), Vector2(15.0, 13.0)]:
		draw_rect(Rect2(star, Vector2(3.0, 1.0)), WHITE)
		draw_rect(Rect2(star + Vector2(1.0, -1.0), Vector2(1.0, 3.0)), WHITE)


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
