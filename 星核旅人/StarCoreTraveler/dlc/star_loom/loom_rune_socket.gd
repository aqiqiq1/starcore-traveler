class_name LoomRuneSocket
extends Node2D

## Floor socket for the movable rune stone.
##
## The groove is presentation only; the chapter decides occupancy from the
## stone's x position and calls `set_occupied()`.  The drawing uses the same
## cold-stone / gold-line palette as the city floor and the polarity gate:
## a dark recess, two raised stone lips, and a 1 px gold seam that brightens
## while the stone is seated.  No new external art.

const STONE: Color = Color("#2b3537")
const STONE_HI: Color = Color("#485558")
const STONE_LO: Color = Color("#0d1517")
const STONE_EDGE: Color = Color("#080d0f")
const GOLD: Color = Color("#f4cd63")
const GOLD_DIM: Color = Color(0.957, 0.804, 0.388, 0.38)

var _occupied: bool = false


func set_occupied(value: bool) -> void:
	if _occupied == value:
		return
	_occupied = value
	queue_redraw()


func is_occupied() -> bool:
	return _occupied


func _draw() -> void:
	# Recess cut into the floor.  Its top two rows sit behind the stone's
	# bottom (stone bottom = y 0), so the seated stone visibly sinks into the
	# channel instead of floating over a separate plate.
	draw_rect(Rect2(-24.0, -2.0, 48.0, 9.0), STONE_EDGE)
	draw_rect(Rect2(-23.0, -1.0, 46.0, 7.0), STONE_LO)
	draw_rect(Rect2(-23.0, -1.0, 46.0, 1.0), STONE)

	# Raised lips at both ends: the stone (32 px) sits between them.
	for side: float in [-1.0, 1.0]:
		var x: float = 24.0 if side > 0.0 else -30.0
		draw_rect(Rect2(x, -4.0, 6.0, 11.0), STONE_EDGE)
		draw_rect(Rect2(x + 1.0, -3.0, 4.0, 9.0), STONE)
		draw_rect(Rect2(x + 1.0, -3.0, 4.0, 1.0), STONE_HI)
		draw_rect(Rect2(x + 1.0, 5.0, 4.0, 1.0), STONE_LO)

	# Gold seam.  Empty = dim and interrupted; seated = bright and continuous,
	# plus an upright tick on each lip so the pressure state reads at 1x.
	var seam: Color = GOLD if _occupied else GOLD_DIM
	if _occupied:
		draw_rect(Rect2(-22.0, 6.0, 44.0, 1.0), seam)
		draw_rect(Rect2(-22.0, 7.0, 44.0, 1.0), Color(GOLD, 0.45))
		for x: float in [-29.0, 25.0]:
			draw_rect(Rect2(x, -1.0, 2.0, 7.0), Color(GOLD.lightened(0.25), 0.92))
		for x: float in [-19.0, 15.0]:
			draw_rect(Rect2(x, 6.0, 4.0, 1.0), Color(GOLD.lightened(0.35), 0.95))
	else:
		draw_rect(Rect2(-18.0, 6.0, 10.0, 1.0), seam)
		draw_rect(Rect2(8.0, 6.0, 10.0, 1.0), seam)
		draw_rect(Rect2(-4.0, 6.0, 8.0, 1.0), Color(seam, seam.a * 0.5))
