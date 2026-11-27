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
	# Cold workshop depth: a few vertical masonry bands and a low teal haze.
	for band: int in range(4):
		canvas.draw_rect(
			Rect2(0.0, 80.0 + float(band) * 54.0, VIEW_SIZE.x, 54.0),
			Color(0.045, 0.085, 0.095, 0.10 - float(band) * 0.015)
		)
	canvas.draw_rect(Rect2(0.0, 286.0, VIEW_SIZE.x, 74.0), Color(0.020, 0.038, 0.042, 1.0))
	canvas.draw_rect(Rect2(0.0, 286.0, VIEW_SIZE.x, 1.0), Color(0.14, 0.22, 0.22, 0.8))

	_draw_chains(canvas)
	_draw_mirror(canvas)
	_draw_eye(canvas)
	_draw_plates(canvas)
	_draw_phase_wave(canvas)
	_draw_vignette(canvas)


func _draw_chains(canvas: CanvasItem) -> void:
	for index: int in range(4):
		var base_x: float = 206.0 + float(index) * 76.0
		var sway: float = sin(_time * 1.6 + float(index) * 1.3) * 2.0
		var length: float = 76.0 + float(index % 2) * 24.0
		var top: Vector2 = Vector2(base_x, 0.0)
		var bottom: Vector2 = Vector2(base_x + sway, length)
		canvas.draw_line(top, bottom, Color(0.16, 0.22, 0.22, 0.75), 1.0)
		var links: int = int(length / 8.0)
		for link: int in range(links):
			var center: Vector2 = top.lerp(bottom, float(link) / float(maxi(links - 1, 1)))
			var link_color: Color = Color(0.20, 0.28, 0.28, 0.55)
			if link % 3 == 0:
				link_color = Color(0.30, 0.38, 0.36, 0.65)
			canvas.draw_rect(Rect2(roundf(center.x) - 2.0, roundf(center.y), 4.0, 2.0), link_color)
			canvas.draw_rect(Rect2(roundf(center.x) - 1.0, roundf(center.y) + 2.0, 2.0, 2.0), link_color)


func _draw_mirror(canvas: CanvasItem) -> void:
	var appear: float = smoothstep(0.12, 0.58, _time)
	if appear <= 0.0:
		return
	# Dark recess behind the frame, then the chapter's own mirror boss frame.
	canvas.draw_colored_polygon(
		_ellipse_points(MIRROR_CENTER + Vector2(0.0, 8.0), 150.0, 132.0, 28),
		Color(0.0, 0.0, 0.0, 0.72 * appear)
	)
	canvas.draw_texture_rect_region(
		MIRROR_FRAME,
		Rect2(MIRROR_CENTER.x - 140.0, MIRROR_CENTER.y - 123.0, 280.0, 246.0),
		Rect2(0.0, 0.0, 128.0, 112.0),
		Color(0.78, 0.88, 0.90, appear)
	)
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
	if lit <= 0.0:
		canvas.draw_texture_rect(texture, Rect2(position.x - 24.0, position.y - 24.0, 48.0, 48.0),
			false, Color(0.18, 0.22, 0.22, 0.38))
		return
	for layer: int in range(3):
		var radius: float = 22.0 + float(layer) * 7.0
		canvas.draw_circle(position, radius, Color(color, (0.12 - float(layer) * 0.03) * lit))
	canvas.draw_texture_rect(texture, Rect2(position.x - 24.0, position.y - 24.0, 48.0, 48.0),
		false, Color(1.0, 1.0, 1.0, 0.38 + 0.62 * lit))
	if lit < 1.0:
		var pulse: float = sin(_time * 18.0) * 0.5 + 0.5
		canvas.draw_arc(position, 28.0, 0.0, TAU, 28,
			Color(color, (1.0 - lit) * pulse * 0.35), 1.0)


func _draw_phase_wave(canvas: CanvasItem) -> void:
	var wave: float = smoothstep(2.12, 2.62, _time)
	if wave <= 0.0:
		return
	for ring: int in range(3):
		var radius: float = 34.0 + wave * (150.0 + float(ring) * 72.0)
		var points: PackedVector2Array = PackedVector2Array()
		for index: int in range(21):
			var ratio: float = float(index) / 20.0
			var x: float = MIRROR_CENTER.x - radius + ratio * radius * 2.0
			var lift: float = sin(ratio * PI) * (8.0 + float(ring) * 3.0)
			points.append(Vector2(x, FLOOR_Y - lift))
		var color: Color = GOLD if ring % 2 == 0 else CYAN
		canvas.draw_polyline(points, Color(color, (1.0 - wave) * 0.80), 3.0)
		canvas.draw_polyline(points, Color(color.lightened(0.35), (1.0 - wave) * 0.35), 1.0)
	for index: int in range(14):
		var spread: float = (float(index) - 6.5) / 6.5
		var x: float = MIRROR_CENTER.x + spread * (40.0 + wave * 250.0)
		var y: float = FLOOR_Y - 2.0 - fmod(_time * 42.0 + float(index) * 19.0, 34.0)
		canvas.draw_rect(Rect2(roundf(x), roundf(y), 1.0 + float(index % 2), 1.0),
			Color(0.72, 0.92, 0.90, (1.0 - wave) * 0.45))


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
