class_name CoreBayLook
extends RefCounted

## One drawing routine for the shared star-core bay look, used by
## CoreDeliveryBay (DLC2/DLC3) and by the base-game StarCoreBayVisual (L2/L3).
##
## The base 32x32 pedestal and glass PNGs stay the project's original art.  This
## module draws the low stone plinth, niche mouth, gold ring/cradle, floor
## conduit, 0.55 s white flash and rising sparks in the chapter's cold-stone /
## gold language.  `base_center` is the centre of the 32x32 base texture; the
## floor sits 16 px below it, so the same call places the look identically on a
## floor-origin bay (base at y=-16) and on the base levels' raised origin
## (base at y=0).

const GOLD: Color = Color("#f4cd63")
const GOLD_DIM: Color = Color(0.957, 0.804, 0.388, 0.34)
const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const DARK: Color = Color(0.02, 0.03, 0.04, 0.72)
const WHITE: Color = Color(1.0, 0.98, 0.90)


static func draw(
	canvas: CanvasItem,
	base_center: Vector2,
	lit: float,
	flash: float,
	time: float
) -> void:
	var pulse: float = 0.5 + 0.5 * sin(time * 3.6)
	var seam: Color = GOLD_DIM.lerp(GOLD, lit)
	# Floor offset: every plinth/niche/seat coordinate below is floor-relative.
	var oy: float = base_center.y + 16.0
	var center: Vector2 = base_center

	# The bay sits on the floor: a narrow dark shadow and two low stone lips.
	# The centre is the open niche, not one solid block.
	canvas.draw_rect(Rect2(-33.0, oy, 66.0, 2.0), DARK)
	canvas.draw_rect(Rect2(-27.0, oy + 2.0, 54.0, 1.0), Color(DARK, 0.35))

	# Flanking stone lips stay low (floor level) so the core can slide in above
	# them.  Tall posts would sit in the core's path and make the payload
	# visibly pass through a stone arm; the bay's identity comes from the base,
	# niche, ring and the glass that seals in when occupied.
	for side: float in [-1.0, 1.0]:
		var x: float = 21.0 if side > 0.0 else -33.0
		canvas.draw_rect(Rect2(x, oy - 7.0, 12.0, 8.0), STONE_EDGE)
		canvas.draw_rect(Rect2(x + 1.0, oy - 6.0, 10.0, 6.0), STONE)
		canvas.draw_rect(Rect2(x + 1.0, oy - 6.0, 10.0, 1.0), STONE_HI)
		canvas.draw_rect(Rect2(x + 2.0, oy - 5.0, 8.0, 1.0), seam)
		if lit > 0.01:
			canvas.draw_rect(Rect2(x + 2.0, oy - 4.0, 8.0, 1.0), Color(GOLD, 0.70 * lit))

	# Connect the low side seats to the pedestal with a 1 px floor rail, so the
	# bay reads as one low plinth instead of three detached rectangles.
	canvas.draw_rect(Rect2(-21.0, oy - 4.0, 5.0, 1.0), STONE)
	canvas.draw_rect(Rect2(16.0, oy - 4.0, 5.0, 1.0), STONE)
	canvas.draw_rect(Rect2(-21.0, oy - 5.0, 5.0, 1.0), seam)
	canvas.draw_rect(Rect2(16.0, oy - 5.0, 5.0, 1.0), seam)

	# The niche mouth: a dark recess cut into the pedestal, with a stone rim
	# and a gold core ring.
	canvas.draw_rect(Rect2(-12.0, oy - 29.0, 24.0, 24.0), STONE_EDGE)
	canvas.draw_rect(Rect2(-11.0, oy - 28.0, 22.0, 22.0), Color("#1b2528"))
	canvas.draw_rect(Rect2(-11.0, oy - 28.0, 22.0, 1.0), STONE_HI)
	canvas.draw_rect(Rect2(-11.0, oy - 7.0, 22.0, 1.0), STONE_LO)
	canvas.draw_rect(Rect2(-11.0, oy - 28.0, 1.0, 21.0), STONE_LO)
	canvas.draw_rect(Rect2(10.0, oy - 28.0, 1.0, 21.0), STONE_LO)
	# Cut the top corners by one pixel so the mouth has a small arch.
	canvas.draw_rect(Rect2(-12.0, oy - 29.0, 2.0, 1.0), Color("#1b2528"))
	canvas.draw_rect(Rect2(10.0, oy - 29.0, 2.0, 1.0), Color("#1b2528"))
	# Dim gold rim: the mouth is an empty but finished socket, not a hole.
	canvas.draw_rect(Rect2(-10.0, oy - 27.0, 20.0, 1.0), Color(GOLD, 0.22 + 0.30 * lit))
	canvas.draw_rect(Rect2(-10.0, oy - 6.0, 20.0, 1.0), Color(GOLD, 0.25 + 0.35 * lit))
	canvas.draw_rect(Rect2(-10.0, oy - 26.0, 1.0, 20.0), Color(GOLD, 0.12 + 0.25 * lit))
	canvas.draw_rect(Rect2(9.0, oy - 26.0, 1.0, 20.0), Color(GOLD, 0.12 + 0.25 * lit))

	# Empty core ring: 17 px diameter, dim gold when empty and bright when
	# the core is held.  The core itself covers the centre when seated.
	var ring_alpha: float = 0.42 + 0.45 * lit
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		canvas.draw_rect(
			Rect2(
				round(cos(angle) * 8.5),
				center.y + round(sin(angle) * 8.5),
				1.0, 1.0
			),
			Color(GOLD, ring_alpha)
		)
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + PI * 0.25
		canvas.draw_rect(
			Rect2(
				round(cos(angle) * 10.0),
				center.y + round(sin(angle) * 10.0),
				2.0, 2.0
			),
			Color(GOLD, ring_alpha + 0.18)
		)

	# Cradle across the pedestal top; the two prongs hold the core's lower
	# corners.  This is code-drawn over the base sprite.
	canvas.draw_rect(Rect2(-13.0, oy - 8.0, 26.0, 1.0), seam)
	for prong_x: float in [-13.0, 11.0]:
		canvas.draw_rect(Rect2(prong_x, oy - 12.0, 2.0, 4.0), Color(STONE_EDGE, 0.95))
		canvas.draw_rect(Rect2(prong_x, oy - 12.0, 2.0, 3.0), seam)

	# Floor conduit: dim groove when empty, moving gold dashes when powered.
	canvas.draw_rect(Rect2(21.0, oy - 2.0, 30.0, 1.0), Color(STONE_EDGE, 0.95))
	if lit > 0.01:
		var travel: float = fmod(time * 26.0, 30.0)
		canvas.draw_rect(Rect2(21.0 + travel, oy - 2.0, 5.0, 1.0), Color(GOLD, 0.86 * lit))
		canvas.draw_rect(Rect2(47.0, oy - 4.0, 2.0, 3.0), Color(GOLD, 0.80 * lit))
		canvas.draw_rect(Rect2(49.0, oy - 3.0, 1.0, 1.0), Color(GOLD, 0.55 * lit))

	# Lit bay: gold halo around the ring, a short light column and rising
	# sparks.  The existing glass sits in front, so the core reads as being
	# inside the dome.
	if lit > 0.01:
		_fill_diamond(canvas, center, 34.0, 30.0,
			Color(GOLD, (0.05 + 0.025 * pulse) * lit))
		_diamond_outline(canvas, center, 28.0, 24.0,
			Color(GOLD, (0.30 + 0.16 * pulse) * lit))
		for index: int in range(3):
			var line_x: float = -3.0 + 3.0 * float(index)
			var y: float = oy - 22.0
			while y > oy - 48.0:
				var fade: float = clampf((y - (oy - 48.0)) / 26.0, 0.0, 1.0)
				canvas.draw_rect(
					Rect2(line_x, y, 1.0, 2.0),
					Color(GOLD, (0.10 + 0.16 * pulse) * fade * lit)
				)
				y -= 4.0
		for index: int in range(6):
			var rise: float = fmod(time * 18.0 + float(index) * 7.0, 26.0)
			var spark_x: float = -10.0 + float(index) * 4.0
			canvas.draw_rect(
				Rect2(spark_x, center.y - rise, 1.0, 1.0),
				Color(1.0, 0.97, 0.86, (0.55 + 0.30 * pulse) * lit)
			)
		if flash > 0.0:
			var expand: float = 1.0 - flash
			_diamond_outline(
				canvas, center, 28.0 + 24.0 * expand, 24.0 + 20.0 * expand,
				Color(1.0, 0.98, 0.90, flash * 0.75)
			)
			_diamond_outline(
				canvas, center, 21.0 + 11.0 * expand, 18.0 + 9.0 * expand,
				Color(GOLD, flash * 0.55)
			)


static func _fill_diamond(
	canvas: CanvasItem, center: Vector2, width: float, height: float, color: Color
) -> void:
	var half_h: float = height * 0.5
	var half_w: float = width * 0.5
	var y_start: int = int(round(center.y - half_h))
	var y_end: int = int(round(center.y + half_h))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - center.y) / half_h
		if absf(cy) > 1.0:
			continue
		var span: int = int(round(half_w * (1.0 - absf(cy))))
		if span < 1:
			continue
		canvas.draw_rect(
			Rect2(center.x - float(span), float(y), float(span * 2), 1.0),
			color
		)


## One-pixel diamond rim, drawn with integer rows so it stays crisp at 1x.
static func _diamond_outline(
	canvas: CanvasItem, center: Vector2, width: float, height: float, color: Color
) -> void:
	var half_h: float = height * 0.5
	var half_w: float = width * 0.5
	var y_start: int = int(round(center.y - half_h))
	var y_end: int = int(round(center.y + half_h))
	for y: int in range(y_start, y_end):
		var cy: float = (float(y) + 0.5 - center.y) / half_h
		if absf(cy) > 1.0:
			continue
		var span: int = int(round(half_w * (1.0 - absf(cy))))
		if span < 1:
			continue
		canvas.draw_rect(Rect2(center.x - float(span), float(y), 1.0, 1.0), color)
		canvas.draw_rect(Rect2(center.x + float(span) - 1.0, float(y), 1.0, 1.0), color)
