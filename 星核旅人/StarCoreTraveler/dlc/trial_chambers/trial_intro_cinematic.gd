class_name TrialIntroCinematic
extends DlcIntroCinematic

## DLC1 试炼场 opening: black -> the two affinity crystals light one after the
## other -> the sun/moon lock turns -> light leaks through the door seam ->
## the camera pulls back to the waiting player.  All shapes are original integer
## / polygon work in the chapter's own palette; the actual gate, crystals and
## player remain untouched underneath and are revealed by the final fade.

## The gate uses the level-2 stone family from PRESENTATION_SYSTEM.md, so the
## film frame and the live bridge read as the same masonry: 1 px lit top edge,
## 1 px dark seam, darker side, capital and base blocks on every pilaster.
const STONE_EDGE: Color = Color("#1c181d")
const STONE_LO: Color = Color("#3b343a")
const STONE_SHADOW: Color = Color("#4c4349")
const STONE: Color = Color("#706469")
const STONE_MID: Color = Color("#7c6e6d")
const STONE_HI: Color = Color("#a0938c")
const STONE_TOP: Color = Color("#b3a69b")
const WHITE: Color = Color(1.0, 0.98, 0.88, 1.0)

const GATE_X: float = 280.0
const FLOOR_Y: float = 320.0
const PLAYER_X: float = 40.0
const GOLD_CRYSTAL_X: float = 198.0
const CYAN_CRYSTAL_X: float = 362.0
const LOCK_Y: float = 214.0

var _gold_stream: AudioStream = null
var _cyan_stream: AudioStream = null
var _lock_stream: AudioStream = null
var _light_stream: AudioStream = null


func _setup_intro() -> void:
	duration = 2.90
	_gold_stream = DlcIntroSfx.crystal_pulse(880.0)
	_cyan_stream = DlcIntroSfx.crystal_pulse(659.25)
	_lock_stream = DlcIntroSfx.lock_turn()
	_light_stream = DlcIntroSfx.door_light()


func _tick_cues() -> void:
	_play_cue("gold_crystal", 0.34, _gold_stream, -9.0)
	_play_cue("cyan_crystal", 0.90, _cyan_stream, -9.0)
	_play_cue("lock_turn", 1.20, _lock_stream, -7.0)
	_play_cue("door_light", 1.96, _light_stream, -10.0)


func _draw_intro(canvas: CanvasItem) -> void:
	var pull: float = smoothstep(1.80, 2.35, _time)
	var zoom: float = lerpf(1.55, 1.0, pull)
	var focus: Vector2 = Vector2(GATE_X, 230.0).lerp(Vector2(320.0, 180.0), pull)
	var offset: Vector2 = VIEW_CENTER - focus * zoom

	# Deep hall behind the transformed gate; the base's black stays behind it.
	canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.010, 0.018, 0.020, 1.0))
	for band: int in range(5):
		var band_alpha: float = 0.055 - float(band) * 0.009
		canvas.draw_rect(
			Rect2(0.0, 74.0 + float(band) * 34.0, VIEW_SIZE.x, 34.0),
			Color(0.10, 0.16, 0.16, band_alpha)
		)

	canvas.draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	_draw_floor(canvas)
	_draw_gate(canvas)
	_draw_crystal(canvas, Vector2(GOLD_CRYSTAL_X, FLOOR_Y), true, 0.34)
	_draw_crystal(canvas, Vector2(CYAN_CRYSTAL_X, FLOOR_Y), false, 0.90)
	# The seam glow sits behind the lock so the rotating sun/moon disc keeps its
	# silhouette; the floor pool reads in front of the leaves.
	_draw_seam_light(canvas)
	_draw_floor_light_pool(canvas)
	_draw_lock(canvas)
	_draw_player(canvas)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_vignette(canvas)
	_draw_dust(canvas)


func _draw_floor(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-180.0, FLOOR_Y, 900.0, 60.0), Color(0.050, 0.044, 0.048, 1.0))
	canvas.draw_rect(Rect2(-180.0, FLOOR_Y, 900.0, 1.0), STONE_TOP)
	canvas.draw_rect(Rect2(-180.0, FLOOR_Y + 1.0, 900.0, 2.0), Color(0.22, 0.19, 0.19, 0.9))
	canvas.draw_rect(Rect2(-180.0, FLOOR_Y + 3.0, 900.0, 1.0), STONE_EDGE)
	# Wide floor slabs with one lit top edge and one dark seam each.
	for index: int in range(15):
		var x: float = -160.0 + float(index) * 60.0
		canvas.draw_rect(Rect2(x, FLOOR_Y + 9.0, 52.0, 1.0), Color(0.16, 0.14, 0.14, 0.7))
		canvas.draw_rect(Rect2(x, FLOOR_Y + 10.0, 52.0, 1.0), Color(0.02, 0.018, 0.02, 0.9))
		canvas.draw_rect(Rect2(x, FLOOR_Y + 18.0, 52.0, 1.0), Color(0.10, 0.09, 0.09, 0.5))
	for index: int in range(6):
		var x: float = -120.0 + float(index) * 160.0
		canvas.draw_rect(Rect2(x, FLOOR_Y + 4.0, 7.0, 4.0), STONE_SHADOW)
		canvas.draw_rect(Rect2(x, FLOOR_Y + 4.0, 7.0, 1.0), STONE_HI)


func _draw_gate(canvas: CanvasItem) -> void:
	# Lintel: three stacked stones, each with a lit top edge and a dark seat.
	canvas.draw_rect(Rect2(GATE_X - 76.0, 118.0, 152.0, 22.0), STONE_EDGE)
	canvas.draw_rect(Rect2(GATE_X - 74.0, 120.0, 148.0, 18.0), STONE_SHADOW)
	canvas.draw_rect(Rect2(GATE_X - 74.0, 120.0, 148.0, 1.0), STONE_TOP)
	canvas.draw_rect(Rect2(GATE_X - 70.0, 127.0, 140.0, 9.0), STONE)
	canvas.draw_rect(Rect2(GATE_X - 70.0, 127.0, 140.0, 1.0), STONE_HI)
	canvas.draw_rect(Rect2(GATE_X - 70.0, 135.0, 140.0, 1.0), STONE_EDGE)
	for index: int in range(5):
		var x: float = GATE_X - 60.0 + float(index) * 30.0
		canvas.draw_rect(Rect2(x, 128.0, 1.0, 7.0), Color(0.24, 0.21, 0.21, 0.7))

	# Two pilasters with capital and base.  The lit side faces the same upper-left
	# key light as the level; the right side stays in the L2 shadow value.
	for side: int in [-1, 1]:
		var px: float = GATE_X + float(side) * 60.0
		canvas.draw_rect(Rect2(px - 8.0, 150.0, 16.0, 156.0), STONE_EDGE)
		canvas.draw_rect(Rect2(px - 7.0, 150.0, 14.0, 156.0), STONE_SHADOW)
		canvas.draw_rect(Rect2(px - 6.0, 151.0, 12.0, 155.0), STONE)
		canvas.draw_rect(Rect2(px - 6.0, 151.0, 1.0, 155.0), STONE_MID)
		canvas.draw_rect(Rect2(px - 5.0, 151.0, 1.0, 155.0), STONE_TOP)
		canvas.draw_rect(Rect2(px + 6.0, 151.0, 1.0, 155.0), STONE_LO)
		for flute: int in range(3):
			var fx: float = px - 3.0 + float(flute) * 3.0
			canvas.draw_rect(Rect2(fx, 155.0, 1.0, 147.0), Color(0.33, 0.29, 0.29, 0.55))
		# Capital: abacus, echinus, necking.
		canvas.draw_rect(Rect2(px - 11.0, 136.0, 22.0, 5.0), STONE_LO)
		canvas.draw_rect(Rect2(px - 10.0, 136.0, 20.0, 4.0), STONE_MID)
		canvas.draw_rect(Rect2(px - 10.0, 136.0, 20.0, 1.0), STONE_TOP)
		canvas.draw_rect(Rect2(px - 9.0, 141.0, 18.0, 5.0), STONE)
		canvas.draw_rect(Rect2(px - 9.0, 141.0, 18.0, 1.0), STONE_HI)
		canvas.draw_rect(Rect2(px - 7.0, 146.0, 14.0, 2.0), STONE_LO)
		canvas.draw_rect(Rect2(px - 7.0, 148.0, 14.0, 2.0), STONE_SHADOW)
		# Base: plinth, torus, square foot.
		canvas.draw_rect(Rect2(px - 9.0, 302.0, 18.0, 4.0), STONE_LO)
		canvas.draw_rect(Rect2(px - 8.0, 302.0, 16.0, 3.0), STONE_MID)
		canvas.draw_rect(Rect2(px - 8.0, 302.0, 16.0, 1.0), STONE_TOP)
		canvas.draw_rect(Rect2(px - 11.0, 306.0, 22.0, 5.0), STONE_SHADOW)
		canvas.draw_rect(Rect2(px - 11.0, 306.0, 22.0, 1.0), STONE_HI)
		canvas.draw_rect(Rect2(px - 13.0, 311.0, 26.0, 7.0), STONE)
		canvas.draw_rect(Rect2(px - 13.0, 311.0, 26.0, 1.0), STONE_TOP)
		canvas.draw_rect(Rect2(px - 13.0, 317.0, 26.0, 1.0), STONE_EDGE)

	# Recessed stone surround with readable courses: 1 px highlight, 1 px seam.
	canvas.draw_rect(Rect2(GATE_X - 48.0, 140.0, 96.0, 180.0), STONE_EDGE)
	canvas.draw_rect(Rect2(GATE_X - 46.0, 142.0, 92.0, 178.0), STONE_LO)
	canvas.draw_rect(Rect2(GATE_X - 44.0, 144.0, 88.0, 176.0), STONE_SHADOW)
	canvas.draw_rect(Rect2(GATE_X - 44.0, 144.0, 88.0, 1.0), STONE_MID)
	for row: int in range(8):
		var y: float = 150.0 + float(row) * 21.0
		canvas.draw_rect(Rect2(GATE_X - 44.0, y, 88.0, 1.0), Color(0.10, 0.09, 0.10, 0.9))
		canvas.draw_rect(Rect2(GATE_X - 44.0, y + 1.0, 88.0, 1.0), Color(0.30, 0.27, 0.26, 0.55))
		var shift: float = 0.0 if row % 2 == 0 else 22.0
		for column: int in range(3):
			var x: float = GATE_X - 44.0 + shift + float(column) * 44.0
			if x > GATE_X + 42.0:
				continue
			canvas.draw_rect(Rect2(x, y, 1.0, 20.0), Color(0.12, 0.10, 0.11, 0.85))
			canvas.draw_rect(Rect2(x + 1.0, y, 1.0, 20.0), Color(0.28, 0.25, 0.24, 0.35))

	# Door leaves: vertical planks, two rails and small affinity marks.
	canvas.draw_rect(Rect2(GATE_X - 34.0, 158.0, 68.0, 160.0), Color(0.012, 0.024, 0.028, 1.0))
	canvas.draw_rect(Rect2(GATE_X - 34.0, 158.0, 32.0, 160.0), Color(0.026, 0.043, 0.048, 1.0))
	canvas.draw_rect(Rect2(GATE_X + 2.0, 158.0, 32.0, 160.0), Color(0.022, 0.038, 0.043, 1.0))
	for plank: int in range(5):
		var lx: float = GATE_X - 30.0 + float(plank) * 6.0
		canvas.draw_rect(Rect2(lx, 161.0, 1.0, 154.0), Color(0.008, 0.016, 0.019, 0.7))
		var rx: float = GATE_X + 4.0 + float(plank) * 6.0
		canvas.draw_rect(Rect2(rx, 161.0, 1.0, 154.0), Color(0.008, 0.016, 0.019, 0.55))
	for rail_y: float in [190.0, 285.0]:
		canvas.draw_rect(Rect2(GATE_X - 34.0, rail_y, 68.0, 2.0), Color(0.07, 0.10, 0.11, 0.9))
		canvas.draw_rect(Rect2(GATE_X - 34.0, rail_y, 68.0, 1.0), Color(0.16, 0.19, 0.19, 0.55))
	canvas.draw_rect(Rect2(GATE_X - 34.0, 158.0, 68.0, 2.0), Color(0.12, 0.18, 0.18, 0.8))
	canvas.draw_rect(Rect2(GATE_X - 1.0, 158.0, 2.0, 160.0), STONE_EDGE)
	_draw_sun(canvas, Vector2(GATE_X - 17.0, 250.0), 7.0, Color(GOLD, 0.42))
	_draw_moon(canvas, Vector2(GATE_X + 17.0, 250.0), 7.0, Color(CYAN, 0.42))


func _draw_crystal(canvas: CanvasItem, base: Vector2, positive: bool, start_time: float) -> void:
	var color: Color = GOLD if positive else CYAN
	var lit: float = clampf((_time - start_time) / 0.18, 0.0, 1.0)
	var bob: float = roundf(sin(_time * 2.4 + (0.0 if positive else 1.4)) * 1.0)

	# Three-step stand.
	canvas.draw_rect(Rect2(base.x - 12.0, base.y - 1.0, 24.0, 1.0), STONE_EDGE)
	canvas.draw_rect(Rect2(base.x - 11.0, base.y - 3.0, 22.0, 2.0), STONE)
	canvas.draw_rect(Rect2(base.x - 11.0, base.y - 3.0, 22.0, 1.0), STONE_HI)
	canvas.draw_rect(Rect2(base.x - 8.0, base.y - 6.0, 16.0, 3.0), STONE)
	canvas.draw_rect(Rect2(base.x - 8.0, base.y - 6.0, 16.0, 1.0), STONE_HI)
	canvas.draw_rect(Rect2(base.x - 5.0, base.y - 9.0, 10.0, 3.0), STONE)
	canvas.draw_rect(Rect2(base.x - 5.0, base.y - 9.0, 10.0, 1.0), STONE_HI)
	canvas.draw_rect(Rect2(base.x - 2.0, base.y - 13.0, 4.0, 4.0), STONE_EDGE)
	canvas.draw_rect(Rect2(base.x - 1.0, base.y - 12.0, 1.0, 2.0),
		Color(color, 0.35 + 0.65 * lit))

	var center: Vector2 = Vector2(base.x, base.y - 24.0 + bob)
	if lit > 0.0:
		for layer: int in range(3):
			var inflate: float = 5.0 + float(layer) * 5.0
			canvas.draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(0.0, -13.0 - inflate),
					center + Vector2(8.0 + inflate * 0.55, 0.0),
					center + Vector2(0.0, 13.0 + inflate),
					center + Vector2(-8.0 - inflate * 0.55, 0.0),
				]),
				Color(color, (0.14 - float(layer) * 0.035) * lit)
			)
		var pulse: float = clampf((_time - start_time) / 0.36, 0.0, 1.0)
		if pulse < 1.0:
			var radius: float = 12.0 + pulse * 20.0
			canvas.draw_polyline(
				PackedVector2Array([
					center + Vector2(0.0, -radius),
					center + Vector2(radius * 0.74, 0.0),
					center + Vector2(0.0, radius),
					center + Vector2(-radius * 0.74, 0.0),
					center + Vector2(0.0, -radius),
				]),
				Color(color.lightened(0.35), (1.0 - pulse) * 0.75 * lit),
				1.0
			)

	var dark: Color = Color(color.darkened(0.72), 0.55 + 0.45 * lit)
	var fill: Color = Color(color.darkened(0.42).lerp(color, lit), 0.42 + 0.58 * lit)
	var facet: Color = Color(color.lightened(0.35), 0.38 + 0.62 * lit)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -11.0),
			center + Vector2(7.0, -2.0),
			center + Vector2(0.0, 11.0),
			center + Vector2(-7.0, -2.0),
		]), dark
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -9.0),
			center + Vector2(5.0, -2.0),
			center + Vector2(0.0, 9.0),
			center + Vector2(-5.0, -2.0),
		]), fill
	)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -9.0),
			center + Vector2(2.0, -2.0),
			center + Vector2(0.0, 7.0),
			center + Vector2(-3.0, -2.0),
		]), facet
	)
	if lit > 0.2:
		canvas.draw_rect(Rect2(center + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)),
			Color(WHITE, lit))
		canvas.draw_rect(Rect2(center + Vector2(0.0, -1.0), Vector2.ONE),
			Color(1.0, 1.0, 1.0, 0.75 * lit))


func _draw_lock(canvas: CanvasItem) -> void:
	var turn: float = smoothstep(1.18, 1.95, _time)
	var outer_angle: float = turn * 2.1
	var inner_angle: float = -turn * 1.45
	var lit: float = clampf((_time - 1.10) / 0.30, 0.0, 1.0)
	var center: Vector2 = Vector2(GATE_X, LOCK_Y)

	canvas.draw_circle(center, 31.0, Color(0.008, 0.016, 0.018, 0.92))
	canvas.draw_arc(center, 29.0, 0.0, TAU, 40, Color(0.16, 0.22, 0.22, 0.9), 2.0)
	canvas.draw_arc(center, 25.0, 0.0, TAU, 40, Color(0.07, 0.11, 0.12, 1.0), 2.0)

	# Sun ring.
	for index: int in range(8):
		var angle: float = outer_angle + TAU * float(index) / 8.0
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * 17.0
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * 25.0
		canvas.draw_line(inner, outer, Color(GOLD, 0.35 + 0.55 * lit), 2.0)
	_draw_sun(canvas, center, 9.0, Color(GOLD, 0.38 + 0.58 * lit), outer_angle)

	# Moon ring, counter-rotating inside the sun ring.
	canvas.draw_arc(center, 15.0, inner_angle, inner_angle + PI * 1.55, 24,
		Color(CYAN, 0.30 + 0.55 * lit), 2.0)
	canvas.draw_arc(center, 11.0, inner_angle + PI, inner_angle + TAU, 24,
		Color(CYAN, 0.22 + 0.45 * lit), 1.0)
	_draw_moon(canvas, center, 7.0, Color(CYAN, 0.45 + 0.45 * lit), inner_angle)

	var core_alpha: float = 0.20 + 0.75 * lit
	canvas.draw_circle(center, 5.0, Color(0.01, 0.02, 0.02, 0.95))
	canvas.draw_circle(center, 3.0, Color(GOLD.lightened(0.35), core_alpha))
	if lit > 0.5:
		canvas.draw_circle(center, 2.0, Color(WHITE, (lit - 0.5) * 1.5))


func _draw_sun(
	canvas: CanvasItem, center: Vector2, radius: float, color: Color,
	angle: float = 0.0
) -> void:
	canvas.draw_circle(center, radius * 0.44, color)
	for index: int in range(8):
		var direction: Vector2 = Vector2(
			cos(angle + TAU * float(index) / 8.0),
			sin(angle + TAU * float(index) / 8.0)
		)
		canvas.draw_line(
			center + direction * radius * 0.62,
			center + direction * radius * 1.05,
			color, 2.0
		)


func _draw_moon(
	canvas: CanvasItem, center: Vector2, radius: float, color: Color,
	angle: float = 0.0
) -> void:
	canvas.draw_circle(center, radius, color)
	canvas.draw_circle(
		center + Vector2(cos(angle - 0.6), sin(angle - 0.6)) * radius * 0.48,
		radius * 0.78,
		Color(0.008, 0.016, 0.018, 1.0)
	)


func _draw_seam_light(canvas: CanvasItem) -> void:
	var open: float = smoothstep(1.92, 2.34, _time)
	if open <= 0.0:
		return
	var top: float = 158.0
	var bottom: float = FLOOR_Y
	var width: float = 2.0 + open * 7.0
	# A warm shaft, never a white divider: the core is cream, the falloff is
	# amber, and both fade vertically (weak at the lintel, strong at the floor).
	# Horizontal softness is built from 1-2 px layers; vertical softness comes
	# from vertex-colour strips, so no single hard-edged rectangle reads as a line.
	var half_widths: Array[float] = [0.0, 1.0, 3.0, 6.0, 10.0, 15.0]
	var layer_alphas: Array[float] = [0.44, 0.20, 0.11, 0.060, 0.032, 0.016]
	for layer: int in range(half_widths.size()):
		var half: float = width * 0.5 + half_widths[layer]
		var tone: Color = Color(1.0, 0.93, 0.74) if layer == 0 else Color(1.0, 0.80, 0.48)
		# Vertex-colour strips give a continuous vertical falloff; the previous
		# slice rects left visible horizontal bands in the shaft.
		_draw_seam_layer(canvas, half, top, bottom, tone, layer_alphas[layer] * open)
	# Perspective wedge: the shaft widens as it meets the floor.
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(GATE_X - width * 0.5 - 2.0, 214.0),
			Vector2(GATE_X + width * 0.5 + 2.0, 214.0),
			Vector2(GATE_X + 46.0, FLOOR_Y),
			Vector2(GATE_X - 46.0, FLOOR_Y),
		]),
		Color(1.0, 0.82, 0.50, 0.055 * open)
	)
	# Warm dust inside the shaft.
	for index: int in range(10):
		var rise: float = fmod(_time * 26.0 + float(index) * 37.0, 150.0)
		var x: float = GATE_X - 18.0 + fmod(float(index) * 17.0, 36.0)
		var y: float = 312.0 - rise
		canvas.draw_rect(Rect2(x, y, 1.0, 1.0),
			Color(1.0, 0.86, 0.58, (1.0 - rise / 150.0) * 0.45 * open))


func _draw_seam_layer(
	canvas: CanvasItem, half: float, top: float, bottom: float,
	tone: Color, peak_alpha: float
) -> void:
	var steps: int = 14
	for step: int in range(steps):
		var t0: float = float(step) / float(steps)
		var t1: float = float(step + 1) / float(steps)
		var v0: float = 0.30 + 0.70 * t0
		v0 *= smoothstep(0.0, 0.10, t0)
		v0 *= 1.0 - 0.22 * smoothstep(0.90, 1.0, t0)
		var v1: float = 0.30 + 0.70 * t1
		v1 *= smoothstep(0.0, 0.10, t1)
		v1 *= 1.0 - 0.22 * smoothstep(0.90, 1.0, t1)
		var y0: float = lerpf(top, bottom, t0)
		var y1: float = lerpf(top, bottom, t1)
		canvas.draw_polygon(
			PackedVector2Array([
				Vector2(GATE_X - half, y0), Vector2(GATE_X + half, y0),
				Vector2(GATE_X + half, y1), Vector2(GATE_X - half, y1),
			]),
			PackedColorArray([
				Color(tone, peak_alpha * v0), Color(tone, peak_alpha * v0),
				Color(tone, peak_alpha * v1), Color(tone, peak_alpha * v1),
			])
		)


func _draw_floor_light_pool(canvas: CanvasItem) -> void:
	var open: float = smoothstep(1.96, 2.30, _time)
	if open <= 0.05:
		return
	# The pool is an ellipse on the floor, not a bright bar across the base of
	# the door.  Three low-alpha layers give it a soft rim.
	for layer: int in range(3):
		var rx: float = maxf((28.0 + float(layer) * 20.0) * open, 5.0)
		var ry: float = maxf((4.0 + float(layer) * 3.0) * open, 1.5)
		canvas.draw_colored_polygon(
			_ellipse_points(Vector2(GATE_X, 324.0), rx, ry, 24),
			Color(1.0, 0.78, 0.44, (0.22 - float(layer) * 0.055) * open)
		)
	canvas.draw_colored_polygon(
		_ellipse_points(Vector2(GATE_X, 323.0), 14.0 * open, 2.2 * open, 20),
		Color(1.0, 0.88, 0.60, 0.30 * open)
	)
	# A 1 px hot centre only where the seam touches the floor.
	canvas.draw_rect(Rect2(GATE_X - 8.0 * open, FLOOR_Y + 1.0, 16.0 * open, 1.0),
		Color(1.0, 0.90, 0.66, 0.34 * open))


func _draw_player(canvas: CanvasItem) -> void:
	var appear: float = smoothstep(2.02, 2.42, _time)
	if appear <= 0.0:
		return
	var bob: float = roundf(sin(_time * 2.0) * 1.0)
	var x: float = PLAYER_X
	var y: float = FLOOR_Y
	# Ground shadow first, then a soft cool backlight.  Many low-alpha ellipses
	# avoid the single bright halo disc that made the earlier version read as a
	# UI pill; the gate sits to the player's right, so the warm rim is right-facing.
	canvas.draw_colored_polygon(_ellipse_points(Vector2(x, y - 1.0), 11.0, 2.5 * appear, 16),
		Color(0.0, 0.0, 0.0, 0.50 * appear))
	for layer: int in range(7):
		canvas.draw_colored_polygon(
			_ellipse_points(Vector2(x + 1.0, y - 17.0), 10.0 + float(layer) * 3.0,
				19.0 + float(layer) * 3.0, 24),
			Color(CYAN, (0.013 - float(layer) * 0.001) * appear)
		)
	var body: Color = Color(0.028, 0.058, 0.066, 0.98 * appear)
	var rim_warm: Color = Color(1.0, 0.84, 0.55, 0.82 * appear)
	var rim_cool: Color = Color(CYAN, 0.40 * appear)
	# Head (8 wide), neck, torso and a flared cloak: a human silhouette at 640x360.
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 5.0, y - 21.0 + bob),
			Vector2(x + 5.0, y - 21.0 + bob),
			Vector2(x + 10.0, y - 2.0),
			Vector2(x - 10.0, y - 2.0),
		]), body
	)
	canvas.draw_rect(Rect2(x - 4.0, y - 22.0 + bob, 8.0, 13.0), body)
	canvas.draw_rect(Rect2(x - 2.0, y - 25.0 + bob, 4.0, 3.0), body)
	canvas.draw_rect(Rect2(x - 4.0, y - 34.0 + bob, 8.0, 9.0), body)
	# Two legs with a 1 px gap; the cloak hangs behind them.
	canvas.draw_rect(Rect2(x - 4.0, y - 9.0 + bob, 4.0, 9.0), body)
	canvas.draw_rect(Rect2(x + 1.0, y - 9.0 + bob, 4.0, 9.0), body)
	canvas.draw_rect(Rect2(x, y - 9.0, 1.0, 8.0), Color(0.0, 0.0, 0.0, 0.85 * appear))
	# Cyan scarf / belt marks nod to the chapter's player without copying a sprite.
	canvas.draw_rect(Rect2(x - 4.0, y - 21.0 + bob, 8.0, 1.0), Color(CYAN, 0.46 * appear))
	canvas.draw_rect(Rect2(x - 3.0, y - 13.0 + bob, 2.0, 1.0), Color(CYAN, 0.55 * appear))
	canvas.draw_line(Vector2(x - 4.0, y - 20.0 + bob), Vector2(x - 11.0, y - 18.0 + bob),
		Color(CYAN, 0.34 * appear), 1.0)
	# 1 px contour: right side catches the gate's warm light, left side is cool.
	canvas.draw_rect(Rect2(x + 3.0, y - 34.0 + bob, 1.0, 9.0), rim_warm)
	canvas.draw_rect(Rect2(x + 4.0, y - 22.0 + bob, 1.0, 13.0), rim_warm)
	canvas.draw_line(Vector2(x + 5.0, y - 21.0 + bob), Vector2(x + 9.0, y - 2.0),
		rim_warm, 1.0)
	canvas.draw_rect(Rect2(x - 4.0, y - 34.0 + bob, 8.0, 1.0),
		Color(1.0, 0.90, 0.66, 0.55 * appear))
	canvas.draw_rect(Rect2(x - 4.0, y - 34.0 + bob, 1.0, 9.0), rim_cool)
	canvas.draw_rect(Rect2(x - 4.0, y - 22.0 + bob, 1.0, 13.0), rim_cool)
	canvas.draw_line(Vector2(x - 5.0, y - 21.0 + bob), Vector2(x - 9.0, y - 2.0),
		rim_cool, 1.0)
	canvas.draw_rect(Rect2(x + 1.0, y - 30.0 + bob, 1.0, 1.0), Color(WHITE, 0.85 * appear))
	# Faint warm contact light on the floor in front of the player.
	canvas.draw_rect(Rect2(x + 8.0, y - 1.0, 10.0, 1.0), Color(1.0, 0.78, 0.46, 0.12 * appear))


func _draw_vignette(canvas: CanvasItem) -> void:
	for index: int in range(4):
		var thickness: float = 18.0 + float(index) * 12.0
		var alpha: float = 0.055 - float(index) * 0.012
		canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, thickness), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(0.0, VIEW_SIZE.y - thickness, VIEW_SIZE.x, thickness),
			Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(0.0, 0.0, thickness, VIEW_SIZE.y), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(VIEW_SIZE.x - thickness, 0.0, thickness, VIEW_SIZE.y),
			Color(0.0, 0.0, 0.0, alpha))


func _draw_dust(canvas: CanvasItem) -> void:
	for index: int in range(26):
		var speed: float = 4.0 + fmod(float(index) * 3.0, 7.0)
		var x: float = fmod(float(index) * 47.0 + _time * speed, VIEW_SIZE.x)
		var y: float = fmod(float(index) * 31.0 + _time * speed * 0.37, VIEW_SIZE.y)
		var alpha: float = 0.10 + 0.10 * sin(_time * 1.4 + float(index))
		canvas.draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0),
			Color(0.78, 0.82, 0.74, alpha))


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
