class_name LoomIntroCinematic
extends DlcIntroCinematic

## DLC3 星核织机 opening: black -> the hall's lamp rows light one by one -> the
## loom beams creak and the shuttle runs -> the two side orbs wake -> the central
## core ignites.  The chapter HUD is hidden by the chapter during the film and
## shown when `finished` arrives.
##
## The hall and loom use the chapter's own city background and loom sprite; the
## lamps, shuttle highlight, orbs and core are original integer/polygon work.

## The film hall must read as the same wall family as the level, so it uses the
## current city_v2 background (three matching cloud windows), not the old city
## sheet that the scene no longer shows.
const CITY_BACK: Texture2D = preload(
	"res://dlc/star_loom/assets/city_v2/city_back_960x360.png"
)
const LOOM: Texture2D = preload(
	"res://dlc/star_loom/assets/city/loom_boss_city_208x152_4f.png"
)

const LOOM_RECT: Rect2 = Rect2(112.0, 38.0, 416.0, 304.0)
const LOOM_FRAME_SIZE: Vector2 = Vector2(208.0, 152.0)
const CORE_CENTER: Vector2 = Vector2(320.0, 198.0)
const FLOOR_Y: float = 330.0
const LAMP_ROWS: Array[float] = [0.40, 0.68, 0.96]
const ORB_LEFT: Vector2 = Vector2(82.0, 192.0)
const ORB_RIGHT: Vector2 = Vector2(558.0, 192.0)

const WOOD: Color = Color("#4a3522")
const WOOD_HI: Color = Color("#76512c")
const WOOD_LO: Color = Color("#1b1310")
const WARM: Color = Color("#ffd58a")
const WHITE: Color = Color(1.0, 0.98, 0.90, 1.0)

var _lamp_streams: Array[AudioStream] = []
var _wood_stream: AudioStream = null
var _shuttle_stream: AudioStream = null
var _orb_low_stream: AudioStream = null
var _orb_high_stream: AudioStream = null
var _core_stream: AudioStream = null


func _setup_intro() -> void:
	duration = 3.30
	_lamp_streams = [
		DlcIntroSfx.lamp_on(0),
		DlcIntroSfx.lamp_on(1),
		DlcIntroSfx.lamp_on(2),
	]
	_wood_stream = DlcIntroSfx.wood_creak()
	_shuttle_stream = DlcIntroSfx.shuttle_slide()
	_orb_low_stream = DlcIntroSfx.orb_on(false)
	_orb_high_stream = DlcIntroSfx.orb_on(true)
	_core_stream = DlcIntroSfx.core_ignite()


func _tick_cues() -> void:
	_play_cue("lamp_row_1", 0.40, _lamp_streams[0], -12.0)
	_play_cue("lamp_row_2", 0.68, _lamp_streams[1], -12.0)
	_play_cue("lamp_row_3", 0.96, _lamp_streams[2], -12.0)
	_play_cue("wood_creak", 1.12, _wood_stream, -11.0)
	_play_cue("shuttle", 1.30, _shuttle_stream, -8.0)
	_play_cue("orb_left", 1.86, _orb_low_stream, -8.0)
	_play_cue("orb_right", 2.02, _orb_high_stream, -8.0)
	_play_cue("core_ignite", 2.20, _core_stream, -5.0)


func _draw_intro(canvas: CanvasItem) -> void:
	# The hall comes up with its lamps: the wall starts near-black and reads as
	# the level's cloud windows once the three rows are lit, so "lights on" is
	# visible on the environment and not only on the bulbs.  At full lift the
	# texture keeps the level's own value range (tint 0.82-0.90) under a thin
	# 0.18 black grade, while the lamp ramp still starts from near-black.
	var hall: float = clampf((_time - 0.30) / 0.85, 0.0, 1.0)
	canvas.draw_texture_rect(
		CITY_BACK,
		Rect2(-160.0, 0.0, 960.0, 360.0),
		false,
		Color(0.82, 0.88, 0.90, 0.10 + 0.86 * hall)
	)
	canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.004, 0.010, 0.012, 0.16 + 0.02 * (1.0 - hall)))
	canvas.draw_rect(Rect2(0.0, 300.0, VIEW_SIZE.x, 60.0), Color(0.012, 0.020, 0.020, 0.62))

	_draw_lamp_rows(canvas)
	_draw_wood_frame(canvas)
	_draw_loom(canvas)
	_draw_orbs(canvas)
	_draw_core(canvas)
	_draw_vignette(canvas)


func _draw_lamp_rows(canvas: CanvasItem) -> void:
	for row: int in range(LAMP_ROWS.size()):
		var lit: float = clampf((_time - LAMP_ROWS[row]) / 0.20, 0.0, 1.0)
		if lit <= 0.0:
			continue
		var y: float = 34.0 + float(row) * 15.0
		for column: int in range(3):
			var x: float = 180.0 + float(column) * 140.0
			for layer: int in range(3):
				canvas.draw_circle(Vector2(x, y), 7.0 + float(layer) * 5.0,
					Color(WARM, (0.12 - float(layer) * 0.030) * lit))
			canvas.draw_rect(Rect2(x - 4.0, y - 2.0, 8.0, 4.0), Color(0.34, 0.25, 0.16, 0.9))
			canvas.draw_rect(Rect2(x - 3.0, y - 1.0, 6.0, 2.0), Color(WARM, 0.35 + 0.65 * lit))
			# A short, soft shaft under each lamp.
			canvas.draw_colored_polygon(
				PackedVector2Array([
					Vector2(x - 5.0, y + 3.0),
					Vector2(x + 5.0, y + 3.0),
					Vector2(x + 14.0, 74.0),
					Vector2(x - 14.0, 74.0),
				]),
				Color(WARM, 0.040 * lit)
			)


func _draw_wood_frame(canvas: CanvasItem) -> void:
	# Two heavy posts and a top beam, built from the same brown family as the
	# chapter's city floor.  A short creak offset is visible at 1.12 s.
	var creak: float = 0.0
	if _time >= 1.12 and _time <= 1.44:
		var phase: float = (_time - 1.12) / 0.32
		creak = roundf(sin(phase * 34.0) * 1.0) * (1.0 - phase)
	canvas.draw_rect(Rect2(66.0 + creak, 16.0, 18.0, 304.0), WOOD_LO)
	canvas.draw_rect(Rect2(68.0 + creak, 16.0, 14.0, 304.0), WOOD)
	canvas.draw_rect(Rect2(68.0 + creak, 16.0, 2.0, 304.0), WOOD_HI)
	canvas.draw_rect(Rect2(556.0 - creak, 16.0, 18.0, 304.0), WOOD_LO)
	canvas.draw_rect(Rect2(558.0 - creak, 16.0, 14.0, 304.0), WOOD)
	canvas.draw_rect(Rect2(558.0 - creak, 16.0, 2.0, 304.0), WOOD_HI)
	canvas.draw_rect(Rect2(64.0, 14.0, 512.0, 14.0), WOOD_LO)
	canvas.draw_rect(Rect2(66.0, 15.0, 508.0, 10.0), WOOD)
	canvas.draw_rect(Rect2(66.0, 15.0, 508.0, 2.0), WOOD_HI)
	for index: int in range(8):
		var x: float = 82.0 + float(index) * 62.0
		canvas.draw_rect(Rect2(x, 15.0, 3.0, 10.0), WOOD_LO)


func _draw_loom(canvas: CanvasItem) -> void:
	var frame: int = 0
	if _time >= 1.26 and _time < 1.92:
		frame = 1 + int(floor((_time - 1.26) / 0.16)) % 4
	elif _time >= 1.92:
		frame = 0
	var shake: float = 0.0
	if _time >= 1.12 and _time <= 1.44:
		shake = roundf(sin(_time * 80.0) * 1.0)
	var destination: Rect2 = LOOM_RECT
	destination.position.x += shake
	var source: Rect2 = Rect2(float(frame) * LOOM_FRAME_SIZE.x, 0.0,
		LOOM_FRAME_SIZE.x, LOOM_FRAME_SIZE.y)
	# Soft warm ambient behind the 2x sprite, then a 1 px dark silhouette fringe
	# made from offset copies of the same frame (transparent texels contribute
	# nothing), so the loom's hard magnified edge sits into the hall.
	for layer: int in range(3):
		canvas.draw_colored_polygon(
			_ellipse_points(Vector2(destination.get_center().x, 192.0),
				238.0 + float(layer) * 26.0, 162.0 + float(layer) * 18.0, 40),
			Color(1.0, 0.82, 0.55, 0.028 - float(layer) * 0.008)
		)
	var outline_offsets: Array[Vector2] = [
		Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0),
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0),
	]
	for offset: Vector2 in outline_offsets:
		canvas.draw_texture_rect_region(
			LOOM,
			Rect2(destination.position + offset, destination.size),
			source,
			Color(0.075, 0.055, 0.045, 0.82)
		)
	canvas.draw_texture_rect_region(
		LOOM,
		destination,
		source,
		Color(0.86, 0.90, 0.88, 0.96)
	)

	# Readable shuttle marker sliding along the reed.
	var shuttle: float = smoothstep(1.28, 1.86, _time)
	if _time >= 1.20:
		var shuttle_x: float = lerpf(176.0, 470.0, shuttle)
		var shuttle_y: float = 198.0
		canvas.draw_rect(Rect2(142.0, shuttle_y - 1.0, 360.0, 2.0),
			Color(0.38, 0.28, 0.14, 0.65))
		canvas.draw_rect(Rect2(shuttle_x - 8.0, shuttle_y - 4.0, 16.0, 8.0), WOOD_LO)
		canvas.draw_rect(Rect2(shuttle_x - 6.0, shuttle_y - 3.0, 12.0, 6.0), GOLD)
		canvas.draw_rect(Rect2(shuttle_x - 4.0, shuttle_y - 2.0, 8.0, 2.0),
			Color(WARM, 0.9))
		for index: int in range(3):
			var trail: float = shuttle_x - 14.0 - float(index) * 9.0
			canvas.draw_rect(Rect2(trail, shuttle_y + 2.0 + float(index % 2), 5.0, 1.0),
				Color(GOLD, 0.28 - float(index) * 0.06))


func _draw_orbs(canvas: CanvasItem) -> void:
	var left_lit: float = clampf((_time - 1.86) / 0.24, 0.0, 1.0)
	var right_lit: float = clampf((_time - 2.02) / 0.24, 0.0, 1.0)
	_draw_orb(canvas, ORB_LEFT, GOLD, left_lit)
	_draw_orb(canvas, ORB_RIGHT, CYAN, right_lit)
	canvas.draw_line(ORB_LEFT, Vector2(112.0, 198.0),
		Color(0.28, 0.22, 0.15, 0.55), 1.0)
	canvas.draw_line(ORB_RIGHT, Vector2(528.0, 198.0),
		Color(0.16, 0.28, 0.29, 0.55), 1.0)


func _draw_orb(canvas: CanvasItem, center: Vector2, color: Color, lit: float) -> void:
	# Unlit orb: dark glass in an iron ring, not a flat black hole.  The 1 px
	# inner reflection keeps it legible now that the hall behind it is brighter.
	canvas.draw_circle(center, 19.0, Color(0.050, 0.080, 0.088, 0.96))
	canvas.draw_circle(center + Vector2(-4.0, -4.0), 12.0, Color(0.085, 0.130, 0.135, 0.42))
	canvas.draw_rect(Rect2(center + Vector2(-8.0, -7.0), Vector2(3.0, 2.0)),
		Color(0.34, 0.48, 0.47, 0.28))
	canvas.draw_arc(center, 19.0, 0.0, TAU, 28, Color(0.24, 0.31, 0.31, 0.95), 1.0)
	canvas.draw_arc(center, 16.5, PI * 1.05, PI * 1.80, 14,
		Color(0.42, 0.54, 0.52, 0.38), 1.0)
	if lit <= 0.0:
		return
	for layer: int in range(4):
		canvas.draw_circle(center, 8.0 + float(layer) * 7.0,
			Color(color, (0.14 - float(layer) * 0.030) * lit))
	canvas.draw_circle(center, 8.0 + 2.0 * lit, Color(color, 0.55 * lit))
	canvas.draw_circle(center, 3.5 * lit, Color(WHITE, 0.82 * lit))
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 + _time * 0.3
		canvas.draw_rect(
			Rect2(center + Vector2(cos(angle), sin(angle)) * (24.0 + 4.0 * lit), Vector2.ONE),
			Color(color.lightened(0.35), 0.55 * lit)
		)


func _draw_core(canvas: CanvasItem) -> void:
	var ignite: float = smoothstep(2.18, 2.86, _time)
	if ignite <= 0.0:
		return
	var pulse: float = 0.90 + 0.10 * sin(_time * 22.0)
	canvas.draw_circle(CORE_CENTER, 19.0, Color(0.010, 0.018, 0.020, 0.75 * ignite))
	for layer: int in range(5):
		var radius: float = (11.0 + float(layer) * 13.0) * ignite * pulse
		canvas.draw_circle(CORE_CENTER, radius,
			Color(GOLD, (0.22 - float(layer) * 0.035) * ignite))
	canvas.draw_circle(CORE_CENTER, 14.0 * ignite, Color(CYAN, 0.22 * ignite))
	canvas.draw_circle(CORE_CENTER, 8.0 * ignite, Color(GOLD.lightened(0.25), 0.78 * ignite))
	canvas.draw_circle(CORE_CENTER, 3.6 * ignite, Color(WHITE, 0.98 * ignite))
	# A diamond core silhouette nods to the boss core while staying a film-only
	# shape; the exact gameplay core is not duplicated here.
	canvas.draw_polyline(
		PackedVector2Array([
			CORE_CENTER + Vector2(0.0, -18.0 * ignite),
			CORE_CENTER + Vector2(13.0 * ignite, 0.0),
			CORE_CENTER + Vector2(0.0, 18.0 * ignite),
			CORE_CENTER + Vector2(-13.0 * ignite, 0.0),
			CORE_CENTER + Vector2(0.0, -18.0 * ignite),
		]),
		Color(CYAN, 0.65 * ignite),
		1.0
	)
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0 + _time * 0.22
		var inner: Vector2 = CORE_CENTER + Vector2(cos(angle), sin(angle)) * 14.0
		var outer: Vector2 = CORE_CENTER + Vector2(cos(angle), sin(angle)) * (22.0 + 12.0 * ignite)
		canvas.draw_line(inner, outer, Color(GOLD, 0.42 * ignite), 1.0)


func _draw_vignette(canvas: CanvasItem) -> void:
	for index: int in range(4):
		var thickness: float = 18.0 + float(index) * 12.0
		var alpha: float = 0.060 - float(index) * 0.012
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
