class_name RiftIntroCinematic
extends DlcIntroCinematic

## DLC2 裂隙工坊 opening: black -> a hanging chain rattles -> one eye opens in
## the dark mirror (lids part, the pupil dilates) -> the gold and cyan face
## plates light in order -> a phase wave crosses the floor.
##
## The mirror frame and the two 48x48 face plates are the chapter's own boss
## sprites, so the film and the fight read as the same object.  The eye, chains
## and wave are original integer/polygon drawing in the chapter palette.

const MIRROR_FRAME: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_boss_128x112_8f.png"
)
const FACE_GOLD: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_gold_48x48.png"
)
const FACE_CYAN: Texture2D = preload(
	"res://dlc/rift_workshop/assets/sprites/mirror_face_cyan_48x48.png"
)

const MIRROR_CENTER: Vector2 = Vector2(320.0, 184.0)
const FLOOR_Y: float = 316.0
const SCLERA: Color = Color(0.025, 0.060, 0.070, 1.0)
const SCLERA_HI: Color = Color(0.08, 0.16, 0.17, 1.0)
const PUPIL: Color = Color(0.008, 0.012, 0.014, 1.0)
const WHITE: Color = Color(1.0, 0.98, 0.90, 1.0)
const IRON: Color = Color("#241b15")
const IRON_HI: Color = Color("#4a3828")
const WOOD: Color = Color("#2a1c13")
const WOOD_HI: Color = Color("#4d3622")
const COLD_GLOW: Color = Color("#74c4c8")

var _chain_a: AudioStream = null
var _chain_b: AudioStream = null
var _eye_stream: AudioStream = null
var _heart_stream: AudioStream = null
var _gold_plate_stream: AudioStream = null
var _cyan_plate_stream: AudioStream = null
var _wave_stream: AudioStream = null


func _setup_intro() -> void:
	duration = 2.90
	_chain_a = DlcIntroSfx.chain_rustle(1)
	_chain_b = DlcIntroSfx.chain_rustle(4)
	_eye_stream = DlcIntroSfx.mirror_eye()
	_heart_stream = DlcIntroSfx.heartbeat()
	_gold_plate_stream = DlcIntroSfx.plate_on(false)
	_cyan_plate_stream = DlcIntroSfx.plate_on(true)
	_wave_stream = DlcIntroSfx.phase_sweep()


func _tick_cues() -> void:
	_play_cue("chain_a", 0.18, _chain_a, -12.0)
	_play_cue("chain_b", 0.62, _chain_b, -13.0)
	_play_cue("eye_open", 0.70, _eye_stream, -9.0)
	_play_cue("heart_a", 0.88, _heart_stream, -10.0)
	_play_cue("heart_b", 1.54, _heart_stream, -12.0)
	_play_cue("gold_plate", 1.62, _gold_plate_stream, -9.0)
	_play_cue("cyan_plate", 1.98, _cyan_plate_stream, -9.0)
	_play_cue("phase_wave", 2.12, _wave_stream, -7.0)


func _draw_intro(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.006, 0.012, 0.015, 1.0))
	var context: float = smoothstep(0.02, 0.55, _time)
	_draw_workshop_wall(canvas, context)
	_draw_ceiling_beams(canvas, context)
	_draw_chains(canvas, context)
	_draw_floor(canvas, context)
	_draw_mirror(canvas)
	_draw_eye(canvas)
	_draw_plates(canvas)
	_draw_phase_wave(canvas)
	_draw_vignette(canvas)


func _draw_workshop_wall(canvas: CanvasItem, lift: float) -> void:
	# Very dark masonry: just enough block rhythm to place the mirror in a room
	# instead of on a UI layer.  Values stay under the mirror's own rim light.
	for row: int in range(8):
		var y: float = 44.0 + float(row) * 36.0
		canvas.draw_rect(Rect2(0.0, y, VIEW_SIZE.x, 1.0),
			Color(0.075, 0.125, 0.135, 0.075 * lift))
		canvas.draw_rect(Rect2(0.0, y + 1.0, VIEW_SIZE.x, 1.0),
			Color(0.14, 0.20, 0.20, 0.035 * lift))
		var shift: float = 0.0 if row % 2 == 0 else 48.0
		for column: int in range(11):
			var x: float = -48.0 + shift + float(column) * 96.0
			canvas.draw_rect(Rect2(x, y, 1.0, 36.0),
				Color(0.065, 0.105, 0.115, 0.065 * lift))
	# A barely-there cold haze around the mirror recess.
	for layer: int in range(3):
		canvas.draw_rect(Rect2(0.0, 148.0 + float(layer) * 42.0, VIEW_SIZE.x, 42.0),
			Color(0.040, 0.085, 0.095, 0.030 * lift))


func _draw_ceiling_beams(canvas: CanvasItem, lift: float) -> void:
	# Horizontal timber above the mirror: the chain anchors and the top frame
	# now share one structure instead of hanging from empty black.
	canvas.draw_rect(Rect2(0.0, 18.0, VIEW_SIZE.x, 16.0), Color(0.085, 0.060, 0.042, 0.95 * lift))
	canvas.draw_rect(Rect2(0.0, 18.0, VIEW_SIZE.x, 1.0), Color(WOOD_HI, 0.80 * lift))
	canvas.draw_rect(Rect2(0.0, 25.0, VIEW_SIZE.x, 1.0), Color(0.16, 0.11, 0.075, 0.55 * lift))
	canvas.draw_rect(Rect2(0.0, 33.0, VIEW_SIZE.x, 1.0), Color(0.0, 0.0, 0.0, 0.85 * lift))
	for index: int in range(4):
		var x: float = 64.0 + float(index) * 188.0
		canvas.draw_rect(Rect2(x, 19.0, 7.0, 15.0), Color(IRON, 0.90 * lift))
		canvas.draw_rect(Rect2(x, 19.0, 1.0, 15.0), Color(IRON_HI, 0.55 * lift))
		canvas.draw_rect(Rect2(x + 1.0, 22.0, 5.0, 1.0), Color(IRON_HI, 0.65 * lift))
		canvas.draw_rect(Rect2(x + 2.0, 27.0, 2.0, 2.0), Color(0.55, 0.45, 0.28, 0.35 * lift))
	# A second slim beam crosses behind the upper ring.
	canvas.draw_rect(Rect2(0.0, 88.0, VIEW_SIZE.x, 8.0), Color(WOOD, 0.72 * lift))
	canvas.draw_rect(Rect2(0.0, 88.0, VIEW_SIZE.x, 1.0), Color(WOOD_HI, 0.50 * lift))
	canvas.draw_rect(Rect2(0.0, 95.0, VIEW_SIZE.x, 1.0), Color(0.0, 0.0, 0.0, 0.70 * lift))
	# Side posts close the workshop box.
	for x: float in [10.0, 616.0]:
		canvas.draw_rect(Rect2(x, 34.0, 14.0, 282.0), Color(0.070, 0.050, 0.036, 0.85 * lift))
		canvas.draw_rect(Rect2(x + 1.0, 34.0, 1.0, 282.0), Color(WOOD_HI, 0.42 * lift))
		canvas.draw_rect(Rect2(x + 12.0, 34.0, 1.0, 282.0), Color(0.0, 0.0, 0.0, 0.65 * lift))


func _draw_chains(canvas: CanvasItem, lift: float) -> void:
	# Alternating oval links on a 2 px pitch, hung from the top beam.  Two short
	# centre chains meet the mirror's top ring and visually carry its weight.
	var positions: Array[float] = [96.0, 158.0, 226.0, 414.0, 482.0, 548.0]
	var lengths: Array[float] = [96.0, 72.0, 118.0, 108.0, 76.0, 98.0]
	for index: int in range(positions.size()):
		_draw_chain(canvas, positions[index], lengths[index], index, lift)
	# Hangers: from beam to the outer rim of the mirror (top y=61).
	_draw_chain(canvas, 292.0, 28.0, 7, lift)
	_draw_chain(canvas, 348.0, 28.0, 8, lift)


func _draw_chain(canvas: CanvasItem, x: float, length: float, index: int, lift: float) -> void:
	var sway: float = sin(_time * 1.4 + float(index) * 1.2) * 1.5
	var top_y: float = 34.0
	var end: Vector2 = Vector2(x + sway, top_y + length)
	# Anchor plate on the beam.
	canvas.draw_rect(Rect2(x - 3.0, 32.0, 6.0, 4.0), Color(IRON, 0.95 * lift))
	canvas.draw_rect(Rect2(x - 3.0, 32.0, 6.0, 1.0), Color(IRON_HI, 0.70 * lift))
	# The chain core is almost black; the links carry the read.
	canvas.draw_line(Vector2(x, top_y + 2.0), end, Color(0.06, 0.09, 0.09, 0.80 * lift), 1.0)
	var links: int = maxi(int(length / 6.0), 1)
	for link: int in range(links):
		var ratio: float = float(link) / float(maxi(links - 1, 1))
		var cx: float = roundf(lerpf(x, end.x, ratio))
		var cy: float = roundf(top_y + 2.0 + float(link) * 6.0)
		var vertical: bool = link % 2 == 0
		var link_rect: Rect2 = Rect2(cx - 2.0, cy, 4.0, 6.0) if vertical else Rect2(cx - 3.0, cy + 1.0, 6.0, 4.0)
		canvas.draw_rect(link_rect, Color(0.26, 0.33, 0.32, 0.62 * lift), false, 1.0)
		if link % 3 == 0:
			canvas.draw_rect(Rect2(link_rect.position.x, link_rect.position.y, 1.0, link_rect.size.y),
				Color(0.50, 0.56, 0.52, 0.40 * lift))
	# Small iron counterweight closes each chain.
	canvas.draw_rect(Rect2(end.x - 3.0, end.y, 6.0, 7.0), Color(0.10, 0.13, 0.13, 0.88 * lift))
	canvas.draw_rect(Rect2(end.x - 3.0, end.y, 6.0, 1.0), Color(0.30, 0.36, 0.34, 0.55 * lift))
	canvas.draw_rect(Rect2(end.x - 1.0, end.y + 7.0, 2.0, 3.0), Color(0.16, 0.20, 0.19, 0.65 * lift))


func _draw_floor(canvas: CanvasItem, lift: float) -> void:
	# Cold stone floor, a low dais for the mirror and a broken light band.
	canvas.draw_rect(Rect2(0.0, 300.0, VIEW_SIZE.x, 60.0), Color(0.022, 0.040, 0.045, 0.92 * lift))
	canvas.draw_rect(Rect2(0.0, 300.0, VIEW_SIZE.x, 1.0), Color(0.12, 0.20, 0.20, 0.55 * lift))
	for index: int in range(5):
		var y: float = 306.0 + float(index) * 10.0 + float(index * index)
		canvas.draw_rect(Rect2(0.0, y, VIEW_SIZE.x, 1.0),
			Color(0.10, 0.16, 0.16, (0.28 - float(index) * 0.04) * lift))
	# Low dais under the mirror.
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(284.0, 305.0), Vector2(356.0, 305.0),
			Vector2(380.0, 316.0), Vector2(260.0, 316.0),
		]),
		Color(0.030, 0.050, 0.054, 0.95 * lift)
	)
	canvas.draw_line(Vector2(284.0, 305.0), Vector2(356.0, 305.0),
		Color(0.24, 0.34, 0.33, 0.50 * lift), 1.0)
	canvas.draw_line(Vector2(260.0, 316.0), Vector2(380.0, 316.0),
		Color(0.08, 0.13, 0.13, 0.75 * lift), 1.0)
	# Cold light band across the floor: a centre-weighted gradient plus a broken
	# crest, so it reads as light on stone instead of a straight HUD separator.
	_draw_cold_light_band(canvas, lift)
	# Short vertical joints keep the floor from reading as stacked rules.
	for index: int in range(9):
		var joint_x: float = 8.0 + float(index) * 76.0
		for row: int in range(3):
			var joint_y: float = 304.0 + float(row) * 12.0
			canvas.draw_rect(Rect2(joint_x + float(row % 2) * 24.0, joint_y, 1.0, 9.0),
				Color(0.10, 0.15, 0.15, (0.22 - float(row) * 0.04) * lift))
	# Mirror reflection: a soft vertical smear on the floor.
	for layer: int in range(3):
		canvas.draw_rect(Rect2(248.0 - float(layer) * 14.0, 317.0 + float(layer) * 3.0,
			144.0 + float(layer) * 28.0, 3.0 + float(layer) * 2.0),
			Color(0.14, 0.30, 0.30, (0.045 - float(layer) * 0.012) * lift))


func _draw_cold_light_band(canvas: CanvasItem, lift: float) -> void:
	var steps: int = 30
	var left: float = 24.0
	var right: float = 616.0
	var step_width: float = (right - left) / float(steps)
	for step: int in range(steps):
		var x0: float = left + float(step) * step_width
		var x1: float = x0 + step_width + 0.5
		var cx: float = (x0 + x1) * 0.5
		var falloff: float = clampf(1.0 - absf(cx - MIRROR_CENTER.x) / 330.0, 0.0, 1.0)
		falloff = falloff * falloff
		var a0: float = 0.050 * falloff * lift
		var a1: float = 0.085 * falloff * lift
		canvas.draw_polygon(
			PackedVector2Array([
				Vector2(x0, 311.0), Vector2(x1, 311.0),
				Vector2(x1, 319.0), Vector2(x0, 319.0),
			]),
			PackedColorArray([
				Color(COLD_GLOW, a0 * 0.45), Color(COLD_GLOW, a0 * 0.45),
				Color(COLD_GLOW, a1), Color(COLD_GLOW, a1),
			])
		)
	# Broken 1 px crest: gaps every few pixels stop it reading as one long rule.
	for segment: int in range(10):
		if segment % 4 == 3:
			continue
		var sx: float = 168.0 + float(segment) * 31.0
		var falloff: float = clampf(1.0 - absf(sx + 15.0 - MIRROR_CENTER.x) / 190.0, 0.0, 1.0)
		canvas.draw_rect(Rect2(sx, 315.0, 26.0, 1.0),
			Color(0.52, 0.82, 0.82, 0.10 * falloff * lift))


func _draw_mirror(canvas: CanvasItem) -> void:
	var appear: float = smoothstep(0.12, 0.58, _time)
	if appear <= 0.0:
		return
	# Soft cold halo separates the dark frame from the workshop wall.
	for layer: int in range(3):
		canvas.draw_colored_polygon(
			_ellipse_points(MIRROR_CENTER + Vector2(0.0, 4.0), 148.0 + float(layer) * 13.0,
				134.0 + float(layer) * 11.0, 32),
			Color(0.12, 0.32, 0.32, (0.028 - float(layer) * 0.008) * appear)
		)
	# Dark recess behind the frame, then the chapter's own mirror boss frame.
	canvas.draw_colored_polygon(
		_ellipse_points(MIRROR_CENTER + Vector2(0.0, 8.0), 150.0, 132.0, 28),
		Color(0.0, 0.0, 0.0, 0.72 * appear)
	)
	# 1 px outer rim + 1 px inner dark ring: the same value hierarchy as the
	# level's stone trim, so the big disc has a rim instead of a flat cutout.
	var outer_rim: PackedVector2Array = _ellipse_points(MIRROR_CENTER, 130.0, 127.0, 56)
	outer_rim.append(outer_rim[0])
	canvas.draw_polyline(outer_rim, Color(0.58, 0.76, 0.74, 0.30 * appear), 1.0)
	canvas.draw_texture_rect_region(
		MIRROR_FRAME,
		Rect2(MIRROR_CENTER.x - 140.0, MIRROR_CENTER.y - 123.0, 280.0, 246.0),
		Rect2(0.0, 0.0, 128.0, 112.0),
		Color(0.78, 0.88, 0.90, appear)
	)
	# The inner dark ring must sit over the frame texture's inner lip; drawing it
	# before the texture let the sprite paint over it.
	var inner_rim: PackedVector2Array = _ellipse_points(MIRROR_CENTER, 120.0, 117.0, 56)
	inner_rim.append(inner_rim[0])
	canvas.draw_polyline(inner_rim, Color(0.004, 0.008, 0.010, 0.55 * appear), 1.0)
	# A thin reflected band on the floor gives the frame weight.
	canvas.draw_rect(Rect2(196.0, 313.0, 248.0, 2.0), Color(0.12, 0.20, 0.20, 0.55 * appear))
	canvas.draw_rect(Rect2(220.0, 315.0, 200.0, 1.0), Color(0.05, 0.10, 0.11, 0.65 * appear))


func _draw_eye(canvas: CanvasItem) -> void:
	var open: float = smoothstep(0.72, 1.62, _time)
	var center: Vector2 = MIRROR_CENTER + Vector2(0.0, 2.0)
	var half_width: float = 62.0
	var aperture: float = 34.0 * open

	if open < 0.02:
		# Closed mirror: a thin dark seam with a faint warm line inside.
		canvas.draw_rect(Rect2(center.x - half_width, center.y - 2.0, half_width * 2.0, 5.0),
			Color(0.030, 0.045, 0.048, 0.95))
		canvas.draw_rect(Rect2(center.x - 30.0, center.y, 60.0, 1.0),
			Color(GOLD, 0.16))
		return

	var top_points: PackedVector2Array = PackedVector2Array()
	var bottom_points: PackedVector2Array = PackedVector2Array()
	var segments: int = 28
	for index: int in range(segments + 1):
		var ratio: float = float(index) / float(segments)
		var x: float = center.x - half_width + ratio * half_width * 2.0
		var arch: float = sin(ratio * PI)
		top_points.append(Vector2(x, center.y - aperture * arch))
		bottom_points.append(Vector2(x, center.y + aperture * 0.70 * arch))

	var lens: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in top_points:
		lens.append(point)
	for index: int in range(bottom_points.size() - 1, -1, -1):
		lens.append(bottom_points[index])
	canvas.draw_colored_polygon(lens, Color(0.006, 0.012, 0.014, 0.96))
	# Sclera: dark mirror glass, slightly inset from the lid rim.
	var sclera: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in top_points:
		sclera.append(center + (point - center) * 0.94)
	for index: int in range(bottom_points.size() - 1, -1, -1):
		sclera.append(center + (bottom_points[index] - center) * 0.94)
	canvas.draw_colored_polygon(sclera, Color(SCLERA, 0.92 * open))
	# A single soft reflective band along the upper lid; short line segments
	# keep this safe even while the aperture is only a few pixels tall.
	for index: int in range(6, 22):
		var ratio: float = float(index) / 22.0
		var x: float = center.x - half_width + ratio * half_width * 2.0
		var arch: float = sin(ratio * PI)
		canvas.draw_line(
			Vector2(x, center.y - aperture * arch + 4.0),
			Vector2(x, center.y - aperture * arch + 8.0),
			Color(SCLERA_HI, 0.22 * open), 1.0
		)

	# Iris: a pale gold disc with a cyan inner rim, matching the boss plates.
	var iris_radius: float = 18.0 + 3.0 * open
	canvas.draw_circle(center, iris_radius + 2.0, Color(0.02, 0.03, 0.03, 0.95 * open))
	canvas.draw_circle(center, iris_radius, Color(0.84, 0.66, 0.27, 0.96 * open))
	canvas.draw_arc(center, iris_radius - 1.0, 0.0, TAU, 32,
		Color(CYAN, 0.50 * open), 1.0)
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0 + 0.12
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (iris_radius * 0.38)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (iris_radius * 0.90)
		canvas.draw_line(inner, outer, Color(0.38, 0.28, 0.10, 0.45 * open), 1.0)

	# Pupil dilation is the readable beat: 4 px when the lid first parts,
	# 12 px when the eye is fully awake.
	var pupil_t: float = smoothstep(0.98, 1.78, _time)
	var pupil_radius: float = lerpf(4.0, 12.0, pupil_t) * open
	canvas.draw_circle(center, pupil_radius, Color(PUPIL, 0.98 * open))
	canvas.draw_circle(center + Vector2(-2.0, -2.0), maxf(pupil_radius * 0.30, 0.5),
		Color(0.72, 0.88, 0.86, 0.22 * open))
	canvas.draw_rect(
		Rect2(center.x + 4.0, center.y - 5.0, 2.0, 2.0),
		Color(WHITE, 0.75 * open)
	)

	# Eyelid rim: dark lid edge with one gold/one cyan accent.
	canvas.draw_polyline(top_points, Color(0.008, 0.016, 0.018, 0.98), 3.0)
	canvas.draw_polyline(bottom_points, Color(0.008, 0.016, 0.018, 0.98), 3.0)
	canvas.draw_polyline(top_points, Color(GOLD, 0.38 * open), 1.0)
	canvas.draw_polyline(bottom_points, Color(CYAN, 0.30 * open), 1.0)

	# A slow blink at the very end closes the mirror just before the hand-off.
	if _time > 2.56:
		var blink: float = smoothstep(2.56, 2.72, _time)
		var lid_y: float = center.y - aperture + aperture * 2.0 * blink
		canvas.draw_rect(
			Rect2(center.x - half_width, lid_y, half_width * 2.0, maxf(aperture * 2.0 * blink, 1.0)),
			Color(0.006, 0.012, 0.014, 0.92 * blink)
		)


func _draw_plates(canvas: CanvasItem) -> void:
	var gold_lit: float = clampf((_time - 1.62) / 0.22, 0.0, 1.0)
	var cyan_lit: float = clampf((_time - 1.98) / 0.22, 0.0, 1.0)
	_draw_plate(canvas, FACE_GOLD, Vector2(158.0, 208.0), gold_lit, GOLD)
	_draw_plate(canvas, FACE_CYAN, Vector2(482.0, 208.0), cyan_lit, CYAN)


func _draw_plate(
	canvas: CanvasItem, texture: Texture2D, position: Vector2, lit: float, color: Color
) -> void:
	var rect: Rect2 = Rect2(position.x - 24.0, position.y - 24.0, 48.0, 48.0)
	if lit <= 0.0:
		canvas.draw_texture_rect(texture, rect, false, Color(0.18, 0.22, 0.22, 0.38))
		canvas.draw_arc(position, 24.0, 0.0, TAU, 32, Color(0.30, 0.38, 0.37, 0.28), 1.0)
		return
	for layer: int in range(3):
		var radius: float = 22.0 + float(layer) * 7.0
		canvas.draw_circle(position, radius, Color(color, (0.12 - float(layer) * 0.03) * lit))
	canvas.draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.38 + 0.62 * lit))
	# 1 px outer rim + 1 px inner dark ring, drawn over the texture so the lip
	# actually darkens the disc edge instead of being hidden by the sprite.
	canvas.draw_arc(position, 24.0, 0.0, TAU, 32,
		Color(color.lightened(0.35), 0.42 * lit), 1.0)
	canvas.draw_arc(position, 21.0, 0.0, TAU, 32,
		Color(0.004, 0.008, 0.009, 0.50 * lit), 1.0)
	if lit < 1.0:
		var pulse: float = sin(_time * 18.0) * 0.5 + 0.5
		canvas.draw_arc(position, 28.0, 0.0, TAU, 28,
			Color(color, (1.0 - lit) * pulse * 0.35), 1.0)


func _draw_phase_wave(canvas: CanvasItem) -> void:
	var wave: float = smoothstep(2.12, 2.62, _time)
	if wave <= 0.0:
		return
	# Each phase front is a filled 4-6 px band with a single 1 px crest, so it
	# reads as a wave crossing the floor rather than two lonely polylines.
	for ring: int in range(3):
		var radius: float = 34.0 + wave * (148.0 + float(ring) * 70.0)
		var amplitude: float = 8.0 + float(ring) * 3.0
		var band_height: float = 5.0 + float(ring)
		var crest: PackedVector2Array = PackedVector2Array()
		var foot: PackedVector2Array = PackedVector2Array()
		for index: int in range(25):
			var ratio: float = float(index) / 24.0
			var x: float = MIRROR_CENTER.x - radius + ratio * radius * 2.0
			var lift: float = sin(ratio * PI) * amplitude
			crest.append(Vector2(x, FLOOR_Y - lift))
			foot.append(Vector2(x, FLOOR_Y - lift + band_height))
		var band: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in crest:
			band.append(point)
		for index: int in range(foot.size() - 1, -1, -1):
			band.append(foot[index])
		var color: Color = GOLD if ring % 2 == 0 else CYAN
		canvas.draw_colored_polygon(band, Color(color, (1.0 - wave) * 0.20))
		canvas.draw_polyline(crest, Color(color, (1.0 - wave) * 0.50), 2.0)
		canvas.draw_polyline(crest, Color(color.lightened(0.35), (1.0 - wave) * 0.24), 1.0)
	for index: int in range(14):
		var spread: float = (float(index) - 6.5) / 6.5
		var x: float = MIRROR_CENTER.x + spread * (40.0 + wave * 250.0)
		var y: float = FLOOR_Y - 2.0 - fmod(_time * 42.0 + float(index) * 19.0, 34.0)
		canvas.draw_rect(Rect2(roundf(x), roundf(y), 1.0 + float(index % 2), 1.0),
			Color(0.72, 0.92, 0.90, (1.0 - wave) * 0.38))


func _draw_vignette(canvas: CanvasItem) -> void:
	for index: int in range(4):
		var thickness: float = 18.0 + float(index) * 12.0
		var alpha: float = 0.065 - float(index) * 0.013
		canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, thickness), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(0.0, VIEW_SIZE.y - thickness, VIEW_SIZE.x, thickness),
			Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(0.0, 0.0, thickness, VIEW_SIZE.y), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(Rect2(VIEW_SIZE.x - thickness, 0.0, thickness, VIEW_SIZE.y),
			Color(0.0, 0.0, 0.0, alpha))


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
