class_name L3GateDepthWall
extends Node2D

## Right-side building for the gate depth pass (2026-11-16, gate-inset revision,
## wall-detail pass 2026-11-16 evening).
##
## The building keeps its WORLD placement no matter where the gate sits:
##   RETURN_SIDE   (12 px) - shaded flank of the building's left end;
##   CORNER_PILASTER (16 px) - lit corner member at that left end;
##   FRONT         - lower storey up to world y 200, 4 px cornice at 196..200,
##                   upper storey set back 16 px with its own dark side face,
##                   three pilasters + recessed bays, base line at world 314.
##
## Wall-detail pass (approved supplementary brief 2026-11-16): the upper wall
## keeps its outline, 96 px bay rhythm and the 196 cornice; it only gains
##   * a 4 px belt course at world y 104..107 with a light top and a dark
##     underside, and a capital under it on every pilaster (2 px outset);
##   * one narrow blind arched niche per upper bay (16 x 36 px, sill at world
##     164), drawn as recessed stone with a 1 px lit side and 2 px dark side -
##     never a black window, never a second gate;
##   * a short pilaster base merged into the existing cornice;
##   * deterministic low-contrast weathering on about one block in ten
##     (1 px chips, 2-4 px cracks, a slightly darker block wash), confined to
##     the upper storey and quieter next to the gate.
## The same drawing and the same 16/24 world grid are used by the back face and
## by the clipped right foreground copy, so the two never split at the seam.
##
## `base_drop` sinks the foreground base below the ground line (default 0 keeps
## the back face unchanged). It exists because the body's lowest visible alpha
## row sits at world 320: a foreground piece that stops at 319 lets a 1 px band
## of feet/cape show along the wall bottom. The material is the same base stone,
## one dark contact row at the bottom - no collision, no alpha tricks.
##
## Palette: three tones close to the gate's base colour (90,81,85 / 94,84,88 /
## 98,88,91) plus the lit corner (106,94,97), the facade highlight 143,128,126,
## the dark 60,52,57 and the base line 198,187,174. No tiled ground strip, no
## random bright/dark checker, no yellow disc, no black brick, no second arch.
## Visual only: no collision, no visibility/alpha changes.

enum Mode { RETURN_SIDE, CORNER_PILASTER, FRONT }

const TONE_A: Color = Color(0.345, 0.310, 0.325, 1.0)      # 88 79 83, recess
const TONE_B: Color = Color(0.369, 0.329, 0.345, 1.0)      # 94 84 88, field
const TONE_C: Color = Color(0.424, 0.376, 0.388, 1.0)      # 108 96 99, pilaster
const SIDE: Color = Color(0.306, 0.275, 0.306, 1.0)        # 78 70 78, side face
const SIDE_LIT: Color = Color(0.349, 0.290, 0.318, 1.0)    # 89 74 81
const ARRIS: Color = Color(0.416, 0.369, 0.380, 1.0)       # 106 94 97, corner
const HILITE: Color = Color(0.561, 0.502, 0.494, 1.0)      # 143 128 126
const LIGHT: Color = Color(0.470, 0.408, 0.408, 1.0)       # 120 104 104
const ARCT: Color = Color(0.235, 0.204, 0.224, 1.0)        # 60 52 57
const BASE_LINE: Color = Color(0.776, 0.733, 0.682, 1.0)   # 198 187 174
const NICHE_FILL: Color = Color(0.298, 0.263, 0.282, 1.0)  # 76 67 72, recessed stone
const COURSE: float = 16.0
const JOINT: float = 24.0
const CORNICE_TOP_WORLD_Y: float = 196.0
const LOWER_TOP_WORLD_Y: float = 200.0
const SETBACK: float = 16.0
const BASE_WORLD_Y: float = 314.0
const GROUND_WORLD_Y: float = 320.0
## Belt course between the two wall stages (upper wall only).
const BELT_WORLD_Y: float = 104.0
const BELT_H: float = 4.0
## Narrow blind arched niche per upper bay.
const NICHE_W: float = 16.0
const NICHE_H: float = 36.0
const NICHE_BOTTOM_WORLD_Y: float = 164.0
## Capital under the belt, pilaster base on the cornice.
const CAPITAL_H: float = 6.0
const PILASTER_BASE_H: float = 8.0
const NO_CLIP: float = 100000.0

@export var mode: Mode = Mode.FRONT
@export var size: Vector2 = Vector2(292.0, 400.0)
## World x window this piece actually draws into (used for the right-hand
## foreground copy of the same FRONT drawing).
@export var clip_world_x: Vector2 = Vector2(-NO_CLIP, NO_CLIP)
## True = drawn in front of the player; false = back layer.
@export var foreground: bool = true
## Extra base rows below the ground line, so a foreground piece really covers
## the body's lowest visible alpha row (world 320). 0 = classic base.
@export var base_drop: float = 0.0


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	match mode:
		Mode.RETURN_SIDE:
			_draw_return()
		Mode.CORNER_PILASTER:
			_draw_corner()
		_:
			_draw_front()


## World rect this piece really covers (clipped), for occlusion measurement.
func get_draw_rect() -> Rect2:
	var left: float = maxf(global_position.x, clip_world_x.x)
	var right: float = minf(global_position.x + size.x, clip_world_x.y)
	return Rect2(left, global_position.y,
		maxf(right - left, 0.0), size.y + maxf(base_drop, 0.0))


func _local_y(world_y: float) -> float:
	return world_y - global_position.y


func _clip() -> Vector2:
	return Vector2(clip_world_x.x - global_position.x, clip_world_x.y - global_position.x)


func _r(x: float, y: float, w: float, h: float, color: Color) -> void:
	var clip: Vector2 = _clip()
	var x0: float = maxf(x, clip.x)
	var x1: float = minf(x + w, clip.y)
	if x1 <= x0:
		return
	draw_rect(Rect2(x0, y, x1 - x0, h), color)


func _vline(x: float, y0: float, y1: float, color: Color) -> void:
	var clip: Vector2 = _clip()
	if x < clip.x or x >= clip.y:
		return
	draw_line(Vector2(x, y0), Vector2(x, y1), color, 1.0)


func _hline(x0: float, x1: float, y: float, color: Color) -> void:
	_r(x0, y, x1 - x0, 1.0, color)


## Courses on the same world grid in every piece, so the joints line up.
func _draw_courses(x0: float, x1: float, top_world_y: float, alpha: float) -> void:
	var y: float = _local_y(GROUND_WORLD_Y) - COURSE
	var limit: float = _local_y(top_world_y)
	while y > limit:
		_hline(x0, x1, y, Color(ARCT, alpha))
		y -= COURSE


func _draw_joints(x0: float, x1: float, top_world_y: float, alpha: float) -> void:
	var course: int = 0
	var y: float = _local_y(GROUND_WORLD_Y)
	var limit: float = _local_y(top_world_y)
	while y - COURSE > limit:
		var x: float = x0 + (0.0 if course % 2 == 0 else JOINT * 0.5)
		while x < x1:
			if x > x0:
				_r(x, y - COURSE, 1.0, COURSE, Color(ARCT, alpha))
			x += JOINT
		y -= COURSE
		course += 1


func _draw_base(x0: float, x1: float) -> void:
	var base_y: float = _local_y(BASE_WORLD_Y)
	_hline(x0, x1, base_y, BASE_LINE)
	_r(x0, base_y + 1.0, x1 - x0, GROUND_WORLD_Y - BASE_WORLD_Y - 2.0, TONE_B)
	_hline(x0, x1, _local_y(GROUND_WORLD_Y) - 1.0, ARCT)
	if base_drop > 0.0:
		# Same plinth stone carried below the ground line, closed by one dark
		# contact row that lines up with the gatehouse plinth (world 322).
		_r(x0, _local_y(GROUND_WORLD_Y), x1 - x0, base_drop - 1.0, TONE_B)
		_hline(x0, x1, _local_y(GROUND_WORLD_Y) + base_drop - 1.0, ARCT)


func _draw_return() -> void:
	# Receding flank of the lower storey (below the cornice only).
	var top: float = CORNICE_TOP_WORLD_Y
	var y0: float = _local_y(top)
	_r(0.0, y0, size.x, size.y - y0, SIDE)
	_r(0.0, y0, 1.0, size.y - y0, ARCT)
	_r(size.x - 1.0, y0, 1.0, size.y - y0, SIDE_LIT)
	_draw_courses(1.0, size.x, top, 0.22)


func _draw_corner() -> void:
	# Lit corner member of the lower storey, capped by the front's cornice.
	var top: float = CORNICE_TOP_WORLD_Y
	var y0: float = _local_y(top)
	_r(0.0, y0, size.x, size.y - y0, ARRIS)
	_r(0.0, y0, 2.0, size.y - y0, HILITE)
	_r(size.x - 1.0, y0, 1.0, size.y - y0, ARCT)
	_draw_courses(2.0, size.x - 1.0, top, 0.20)


func _draw_front() -> void:
	var top_local: float = _local_y(CORNICE_TOP_WORLD_Y)
	var lower_local: float = _local_y(LOWER_TOP_WORLD_Y)
	var ground_local: float = _local_y(GROUND_WORLD_Y)
	var pilaster_xs: Array[float] = [44.0, 140.0, 236.0]
	var pilaster_w: float = 18.0
	# --- fields: lower storey (near plane) + upper storey (set back) -------
	_r(0.0, lower_local, size.x, ground_local - lower_local, TONE_B)
	_r(0.0, 0.0, SETBACK, top_local, SIDE)
	_r(SETBACK, 0.0, size.x - SETBACK, top_local, TONE_B)
	# --- recessed bays between the pilasters (both storeys) -----------------
	for index: int in range(pilaster_xs.size() - 1):
		var bay_x: float = pilaster_xs[index] + pilaster_w
		var bay_w: float = pilaster_xs[index + 1] - bay_x
		if bay_w > 14.0:
			_r(bay_x + 6.0, 0.0, bay_w - 12.0, ground_local, TONE_A)
	# --- masonry grid over fields and bays ---------------------------------
	_draw_courses(0.0, size.x, LOWER_TOP_WORLD_Y, 0.20)
	_draw_joints(0.0, size.x, LOWER_TOP_WORLD_Y, 0.22)
	_draw_courses(1.0, SETBACK, -80.0, 0.22)
	_draw_courses(SETBACK, size.x, -80.0, 0.20)
	_draw_joints(SETBACK, size.x, -80.0, 0.22)
	# --- one-block-in-ten weathering, upper storey only --------------------
	_draw_weathering(lower_local)
	# --- pilasters run the whole height, broken only by the cornice --------
	for index: int in range(pilaster_xs.size()):
		var px: float = pilaster_xs[index]
		if px + pilaster_w > size.x:
			continue
		_r(px, 0.0, pilaster_w, ground_local, TONE_C)
		_r(px, 0.0, 2.0, ground_local, HILITE)
		_r(px + pilaster_w - 1.0, 0.0, 1.0, ground_local, ARCT)
		_r(px + pilaster_w, 0.0, 2.0, ground_local, Color(ARCT, 0.28))
	# bay inner shadow / lit return
	for index: int in range(pilaster_xs.size() - 1):
		var bay_x: float = pilaster_xs[index] + pilaster_w
		var bay_w: float = pilaster_xs[index + 1] - bay_x
		if bay_w <= 14.0:
			continue
		_r(bay_x + 6.0, 0.0, 2.0, ground_local, Color(ARCT, 0.45))
		_r(bay_x + bay_w - 7.0, 0.0, 1.0, ground_local, Color(HILITE, 0.30))
	# --- belt course + pilaster capitals (new detail) ----------------------
	_draw_belt(pilaster_xs, pilaster_w)
	# --- one blind arched niche per upper bay (new detail) -----------------
	_draw_niches(pilaster_xs, pilaster_w)
	# --- 4 px cornice band on the gate's tower-top line, world y 196..200 ---
	_hline(-28.0, size.x, top_local, HILITE)
	_r(-28.0, top_local + 1.0, size.x + 28.0, 2.0, LIGHT)
	_hline(-28.0, size.x, top_local + 3.0, ARCT)
	# --- shadow under the oversailing cornice ------------------------------
	_r(-28.0, lower_local, size.x + 28.0, 3.0, Color(ARCT, 0.30))
	# upper storey's own dark side face reads as the 16 px setback
	_r(0.0, 0.0, 1.0, top_local, ARCT)
	_r(SETBACK - 1.0, 0.0, 1.0, top_local, SIDE_LIT)
	# front left edge reads as the corner member's shadow
	_r(0.0, lower_local, 1.0, ground_local - lower_local, Color(ARCT, 0.45))
	_draw_base(0.0, size.x)


## 4 px belt at world 104..107: light top, lit band, dark underside, plus a
## capital under it on every pilaster that protrudes 2 px each side.
func _draw_belt(pilaster_xs: Array[float], pilaster_w: float) -> void:
	var y0: float = _local_y(BELT_WORLD_Y)
	_hline(0.0, size.x, y0, LIGHT)
	_r(0.0, y0 + 1.0, size.x, BELT_H - 2.0, TONE_C)
	_hline(0.0, size.x, y0 + BELT_H - 1.0, Color(ARCT, 0.85))
	# shadow the belt casts on the wall below it
	_hline(SETBACK, size.x, y0 + BELT_H, Color(ARCT, 0.28))
	var cap_y: float = y0 + BELT_H
	for index: int in range(pilaster_xs.size()):
		var px: float = pilaster_xs[index]
		if px + pilaster_w > size.x:
			continue
		_r(px - 2.0, cap_y, pilaster_w + 4.0, CAPITAL_H, TONE_C)
		_hline(px - 2.0, px + pilaster_w + 2.0, cap_y, HILITE)
		_hline(px - 2.0, px + pilaster_w + 2.0, cap_y + CAPITAL_H - 1.0,
			Color(ARCT, 0.55))
		# short pilaster base sitting on the existing cornice
		var base_y: float = _local_y(CORNICE_TOP_WORLD_Y) - PILASTER_BASE_H
		_r(px - 2.0, base_y, pilaster_w + 4.0, PILASTER_BASE_H, TONE_C)
		_hline(px - 2.0, px + pilaster_w + 2.0, base_y, HILITE)
		_hline(px - 2.0, px + pilaster_w + 2.0, base_y + PILASTER_BASE_H - 1.0,
			Color(ARCT, 0.45))


## One recessed blind niche per upper bay: 16 x 36 px, stepped head, sill at
## world 164, 1 px lit jamb, 2 px dark jamb. Recessed stone, never black.
func _draw_niches(pilaster_xs: Array[float], pilaster_w: float) -> void:
	var bottom: float = _local_y(NICHE_BOTTOM_WORLD_Y)
	for index: int in range(pilaster_xs.size()):
		var bay_left: float = pilaster_xs[index] + pilaster_w
		var bay_right: float = size.x
		if index + 1 < pilaster_xs.size():
			bay_right = pilaster_xs[index + 1]
		var inner_left: float = bay_left + 6.0
		var inner_right: float = bay_right - 6.0
		if inner_right - inner_left < NICHE_W + 8.0:
			continue
		var nx: float = round((inner_left + inner_right - NICHE_W) * 0.5)
		_draw_niche(nx, bottom)


func _draw_niche(nx: float, bottom_local: float) -> void:
	var top: float = bottom_local - NICHE_H
	# stepped blind arch head, three 2 px steps narrowing to the top
	_r(nx + 6.0, top, NICHE_W - 12.0, 2.0, NICHE_FILL)
	_r(nx + 4.0, top + 2.0, NICHE_W - 8.0, 2.0, NICHE_FILL)
	_r(nx + 2.0, top + 4.0, NICHE_W - 4.0, 2.0, NICHE_FILL)
	# recessed face below the head
	var face_top: float = top + 6.0
	var inner_h: float = bottom_local - 1.0 - face_top
	_r(nx + 1.0, face_top, NICHE_W - 2.0, inner_h, NICHE_FILL)
	# 1 px lit jamb (light from the left), 2 px dark jamb, dark sill shadow
	_r(nx + 1.0, face_top, 1.0, inner_h, Color(HILITE, 0.34))
	_r(nx + NICHE_W - 2.0, face_top, 2.0, inner_h, Color(ARCT, 0.62))
	_hline(nx + 1.0, nx + NICHE_W - 1.0, face_top, Color(ARCT, 0.30))
	_r(nx + 1.0, bottom_local - 1.0, NICHE_W - 2.0, 1.0, Color(ARCT, 0.45))
	# one lit sill course, 1 px outset each side
	_r(nx - 1.0, bottom_local, NICHE_W + 2.0, 2.0, TONE_C)
	_hline(nx - 1.0, nx + NICHE_W + 1.0, bottom_local, HILITE)
	_hline(nx - 1.0, nx + NICHE_W + 1.0, bottom_local + 1.0, Color(ARCT, 0.35))


## Deterministic, low-contrast wear on the same 16/24 world grid: about one
## block in ten gets a 1 px chip, a 2-4 px crack or a slightly darker wash.
## Never a full-face checker; structural lines stay stronger than the wear.
func _draw_weathering(upper_limit_local: float) -> void:
	var course: int = 0
	var y: float = _local_y(GROUND_WORLD_Y)
	while y - COURSE > 0.0:
		var top_y: float = y - COURSE
		var x: float = 0.0 if course % 2 == 0 else JOINT * 0.5
		while x + JOINT <= size.x:
			if top_y < upper_limit_local - 8.0:
				var h: int = _cell_hash(course, int(round(x)))
				if h % 10 == 0:
					var variant: int = (h / 10) % 4
					match variant:
						0:
							_r(x + 1.0, top_y + 1.0, 1.0, 1.0, Color(ARCT, 0.45))
						1:
							_r(x + 1.0, top_y + 1.0, JOINT - 2.0, COURSE - 2.0,
								Color(TONE_A, 0.20))
						2:
							_r(x + 7.0, top_y + 3.0, 1.0, 4.0, Color(ARCT, 0.36))
						_:
							_r(x + 15.0, top_y + 6.0, 3.0, 1.0, Color(ARCT, 0.30))
			x += JOINT
		y -= COURSE
		course += 1


## Stable per-block hash (no randomness at runtime, identical on every redraw).
func _cell_hash(course: int, x: int) -> int:
	var h: int = (course + 1) * 73856093 ^ (x + 7) * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	h = h & 0x7fffffff
	return h
