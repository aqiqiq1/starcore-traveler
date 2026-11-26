class_name HudBossBar
extends Control

## One boss bar for every combat chapter: base L3 guard, trial guard, rift
## double mirror and star loom.
##
## Approved layout (dlc/PRESENTATION_SYSTEM.md, 2026-11-27):
##   360 x 16 at the top centre: 12 px name, red fill bar, phase / core cells.
##   DLC3 may add its three life hearts under the same bar; no text count.
##
## Reference check (2026-11-27): Hades Lernie boss fight frame
## (screenshots/hud_refs/hades_boss_maxresdefault.jpg): a small top-centre
## name above a thin red bar, with no big panel and no repeated counter row.
## Only that edge-anchored, thin-bar reading is borrowed; no pixels or art.
##
## Player health stays a separate lower-left bar; this control never draws it.

const BAR_SIZE: Vector2 = Vector2(360.0, 16.0)
const HUD_POSITION: Vector2 = Vector2(140.0, 22.0)
const NAME_POSITION: Vector2 = Vector2(7.0, 12.0)
const FONT_SIZE: int = 12
const OUTLINE_SIZE: int = 1
const NAME_WIDTH: float = 58.0
const FILL_POSITION: Vector2 = Vector2(68.0, 5.0)
const FILL_SIZE: Vector2 = Vector2(158.0, 6.0)
const CORE_START_X: float = 252.0
const CORE_PITCH: float = 13.0
const CORE_RADIUS: float = 5.0
const PHASE_START_OFFSET: float = 45.0
const PHASE_CELL: Vector2 = Vector2(5.0, 8.0)
const PHASE_GAP: float = 3.0
const FACE_X: float = 236.0
const FACE_SIZE: float = 10.0
const FACE_GAP: float = 4.0
const NODE_SIZE: float = 7.0
const LIVES_START: float = 161.0
const LIVES_PITCH: float = 14.0
const LIVES_Y: float = 18.0
const FADE_TIME: float = 0.15
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const TEXT: Color = Color("#e8e2d5")
const MUTED: Color = Color("#9fb0b2")
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const WHITE: Color = Color(1.0, 0.98, 0.90)
const RED: Color = Color("#d95757")
const LOW_RED: Color = Color("#ff7b7b")
const EMPTY_RED: Color = Color(0.13, 0.07, 0.08, 0.98)
const INK: Color = Color(0.004, 0.010, 0.014, 0.94)
const PANEL: Color = Color(0.008, 0.018, 0.024, 0.88)
const EDGE: Color = Color(0.30, 0.45, 0.44, 0.55)
const PURPLE: Color = Color("#b98cff")
const BROKEN: Color = Color(0.86, 0.28, 0.24, 0.95)
const LIFE_RED: Color = Color("#ef6b6b")

@export var boss_name: String = ""
@export var font: Font = null

var _core_current: int = 3
var _core_max: int = 3
var _phase_index: int = 0
var _phase_count: int = 1
var _hp_ratio: float = 1.0
var _faces_visible: bool = false
var _gold_intact: bool = true
var _cyan_intact: bool = true
var _exposed: bool = false
var _nodes_visible: bool = false
var _nodes_alive: int = 0
var _nodes_max: int = 0
var _lives_visible: bool = false
var _lives_current: int = 3
var _lives_max: int = 3
var _gold_anchored: bool = false
var _cyan_anchored: bool = false
var _gold_window: float = 0.0
var _cyan_window: float = 0.0
var _boss_present: bool = false
var _modal_suppressed: bool = false
var _fade_tween: Tween
var _built: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	position = HUD_POSITION
	_built = true
	if font == null:
		font = _load_font()
	visible = false
	modulate.a = 0.0
	queue_redraw()
	_refresh_visibility(false)


func configure(name_text: String, core_max: int, phase_max: int, font_value: Font = null) -> void:
	boss_name = name_text
	_core_max = maxi(core_max, 1)
	_phase_count = maxi(phase_max, 1)
	if font_value != null:
		font = font_value
	if _built:
		queue_redraw()


func set_bar_values(
	core_current: int, core_max: int, phase_index: int, phase_count: int,
	hp_ratio: float = -1.0
) -> void:
	var next_ratio: float = hp_ratio
	if next_ratio < 0.0:
		next_ratio = float(core_current) / float(maxi(core_max, 1))
	var changed: bool = (
		core_current != _core_current or core_max != _core_max
		or phase_index != _phase_index or phase_count != _phase_count
		or not is_equal_approx(next_ratio, _hp_ratio)
	)
	_core_current = clampi(core_current, 0, maxi(core_max, 1))
	_core_max = maxi(core_max, 1)
	_phase_index = maxi(phase_index, 0)
	_phase_count = maxi(phase_count, 1)
	_hp_ratio = clampf(next_ratio, 0.0, 1.0)
	if changed:
		queue_redraw()


func set_boss_name(name_text: String) -> void:
	if boss_name == name_text:
		return
	boss_name = name_text
	queue_redraw()


## Mirror only: two face plates (gold / cyan).  A broken face stays on the bar
## dimmed with a red X; the exposed core gets a white rim on the core cells.
func set_faces(
	gold_intact: bool, cyan_intact: bool, exposed: bool, shown: bool = true
) -> void:
	_faces_visible = shown
	_gold_intact = gold_intact
	_cyan_intact = cyan_intact
	_exposed = exposed
	queue_redraw()


## Loom only: two live orbit nodes shown before the core cells.
func set_nodes(alive: int, total: int, shown: bool = true) -> void:
	_nodes_visible = shown
	_nodes_alive = clampi(alive, 0, maxi(total, 1))
	_nodes_max = clampi(total, 0, 2)
	queue_redraw()


## Loom only: the run's three life hearts sit centred under the boss bar.
func set_lives(current: int, total: int, shown: bool = true) -> void:
	_lives_visible = shown
	_lives_max = maxi(total, 1)
	_lives_current = clampi(current, 0, _lives_max)
	queue_redraw()


## Kept separate from set_bar_values so the rift call sites keep their shape.
func set_anchor_state(
	gold_anchored: bool, cyan_anchored: bool,
	gold_window: float, cyan_window: float
) -> void:
	_gold_anchored = gold_anchored
	_cyan_anchored = cyan_anchored
	_gold_window = maxf(gold_window, 0.0)
	_cyan_window = maxf(cyan_window, 0.0)
	queue_redraw()


func set_active(value: bool) -> void:
	if _boss_present == value:
		return
	_boss_present = value
	_refresh_visibility(true)


func is_active() -> bool:
	return _boss_present


## Pause / guide / mechanic popup / recovery / completion hide the whole bar
## (and the DLC3 hearts) while keeping the boss data; restoring fades in.
func set_modal_suppressed(value: bool) -> void:
	if _modal_suppressed == value:
		return
	_modal_suppressed = value
	_refresh_visibility(true)


func is_modal_suppressed() -> bool:
	return _modal_suppressed


func _refresh_visibility(animated: bool) -> void:
	var want: bool = _boss_present and not _modal_suppressed
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if want:
		visible = true
		if not animated or modulate.a >= 0.999:
			modulate.a = 1.0
			return
		modulate.a = 0.0
		_fade_tween = _make_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
		return
	if not visible:
		return
	if not animated:
		visible = false
		modulate.a = 0.0
		return
	_fade_tween = _make_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_fade_tween.tween_callback(_hide_after_fade)


func _hide_after_fade() -> void:
	if _boss_present and not _modal_suppressed:
		return
	visible = false
	modulate.a = 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, BAR_SIZE), PANEL)
	draw_rect(Rect2(0.0, 0.0, BAR_SIZE.x, 1.0), EDGE)
	draw_rect(Rect2(0.0, BAR_SIZE.y - 1.0, BAR_SIZE.x, 1.0), EDGE)
	var draw_font: Font = font if font != null else ThemeDB.fallback_font
	if not boss_name.is_empty():
		draw_string_outline(
			draw_font, NAME_POSITION, boss_name,
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH, FONT_SIZE, OUTLINE_SIZE, INK
		)
		draw_string(
			draw_font, NAME_POSITION, boss_name,
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH, FONT_SIZE, TEXT
		)

	# Red fill: dark track, coral fill, 1 px warm highlight.
	draw_rect(Rect2(FILL_POSITION, FILL_SIZE), EMPTY_RED)
	draw_rect(Rect2(FILL_POSITION, FILL_SIZE), INK, false, 1.0)
	var fill_width: float = floorf(FILL_SIZE.x * _hp_ratio)
	if fill_width > 0.0:
		var fill_color: Color = LOW_RED if _hp_ratio <= 0.34 else RED
		draw_rect(Rect2(FILL_POSITION, Vector2(fill_width, FILL_SIZE.y)), fill_color)
		draw_rect(
			Rect2(FILL_POSITION, Vector2(fill_width, 1.0)),
			Color(1.0, 0.88, 0.78, 0.55)
		)

	var core_x: float = CORE_START_X
	if _faces_visible:
		_draw_face(Vector2(FACE_X, 3.0), true, _gold_intact, _gold_anchored, _gold_window)
		_draw_face(
			Vector2(FACE_X + FACE_SIZE + FACE_GAP, 3.0),
			false, _cyan_intact, _cyan_anchored, _cyan_window
		)
		core_x = FACE_X + FACE_SIZE * 2.0 + FACE_GAP + 4.0
	elif _nodes_visible:
		for index: int in range(_nodes_max):
			var alive: bool = index < _nodes_alive
			var node_color: Color = CYAN if alive else Color(0.20, 0.28, 0.29, 0.95)
			_draw_diamond(
				Vector2(FACE_X + 3.0 + float(index) * (NODE_SIZE + 3.0), 8.0),
				3.0, node_color, Color(0.45, 0.62, 0.60, 0.85)
			)
		core_x = FACE_X + float(_nodes_max) * (NODE_SIZE + 3.0) + 3.0

	for index: int in range(_core_max):
		var filled: bool = index < _core_current
		var fill_color: Color = WHITE if filled else Color(0.20, 0.27, 0.28, 0.95)
		var edge_color: Color = GOLD if filled else Color(0.42, 0.54, 0.52, 0.80)
		if _exposed and _faces_visible:
			edge_color = Color(1.0, 1.0, 1.0, 0.95) if filled else edge_color
		_draw_diamond(
			Vector2(core_x + CORE_RADIUS + float(index) * CORE_PITCH, 8.0),
			CORE_RADIUS, fill_color, edge_color
		)

	if _phase_count > 1:
		var phase_x: float = core_x + float(_core_max) * CORE_PITCH + 6.0
		for index: int in range(_phase_count):
			var active: bool = index <= _phase_index
			var phase_color: Color = GOLD if index % 2 == 0 else CYAN
			draw_rect(
				Rect2(
					phase_x + float(index) * (PHASE_CELL.x + PHASE_GAP), 4.0,
					PHASE_CELL.x, PHASE_CELL.y
				),
				Color(phase_color, 0.94) if active else Color(0.18, 0.25, 0.27, 0.88)
			)

	if _lives_visible:
		for index: int in range(_lives_max):
			var color: Color = LIFE_RED if index < _lives_current else Color(0.30, 0.17, 0.19, 0.95)
			_draw_heart(Vector2(LIVES_START + float(index) * LIVES_PITCH, LIVES_Y), color)


func _draw_face(
	origin: Vector2, positive: bool, intact: bool,
	anchored: bool, window: float
) -> void:
	var color: Color = GOLD if positive else CYAN
	var alpha: float = 1.0 if intact else 0.45
	draw_rect(Rect2(origin, Vector2(FACE_SIZE, FACE_SIZE)), INK)
	draw_rect(Rect2(origin + Vector2.ONE, Vector2(FACE_SIZE - 2.0, FACE_SIZE - 2.0)),
		Color(0.04, 0.07, 0.08, 0.96))
	draw_rect(
		Rect2(origin, Vector2(FACE_SIZE, FACE_SIZE)),
		Color(color, 0.72 * alpha), false, 1.0
	)
	if positive:
		_draw_diamond(origin + Vector2(5.0, 5.0), 2.5, Color(color, alpha),
			Color(color.lightened(0.3), alpha))
	else:
		draw_rect(Rect2(origin + Vector2(2.0, 2.0), Vector2(6.0, 6.0)),
			Color(color, alpha))
		draw_rect(Rect2(origin + Vector2(4.0, 2.0), Vector2(4.0, 4.0)),
			Color(0.04, 0.07, 0.08, 0.96))
	if not intact:
		draw_line(origin + Vector2(2.0, 2.0), origin + Vector2(8.0, 8.0),
			BROKEN, 1.0)
		draw_line(origin + Vector2(8.0, 2.0), origin + Vector2(2.0, 8.0),
			BROKEN, 1.0)
	if anchored:
		draw_rect(Rect2(origin, Vector2(FACE_SIZE, FACE_SIZE)), PURPLE, false, 1.0)
	elif window > 0.0:
		var lit: int = int(round(clampf(window / 6.0, 0.0, 1.0) * FACE_SIZE))
		draw_rect(Rect2(origin + Vector2(0.0, FACE_SIZE), Vector2(float(lit), 1.0)),
			Color(GOLD, 0.95))


func _draw_diamond(center: Vector2, radius: float, fill: Color, edge: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, fill)
	for index: int in range(points.size()):
		draw_line(points[index], points[(index + 1) % points.size()], edge, 1.0)


## 10x9 heart with a dark 1 px rim, used only for DLC3's lives row.
func _draw_heart(origin: Vector2, color: Color) -> void:
	var dark_rows: Array[String] = [
		"..xx..xx..",
		".xxxxxxxx.",
		"xxxxxxxxxx",
		"xxxxxxxxxx",
		"xxxxxxxxxx",
		".xxxxxxxx.",
		"..xxxxxx..",
		"...xxxx...",
		"....xx....",
	]
	var fill_rows: Array[String] = [
		".xx..xx.",
		"xxxxxxxx",
		"xxxxxxxx",
		"xxxxxxxx",
		".xxxxxx.",
		"..xxxx..",
		"...xx...",
	]
	for y: int in range(dark_rows.size()):
		for x: int in range(dark_rows[y].length()):
			if dark_rows[y][x] == "x":
				draw_rect(Rect2(origin + Vector2(float(x), float(y)), Vector2.ONE), INK)
	for y: int in range(fill_rows.size()):
		for x: int in range(fill_rows[y].length()):
			if fill_rows[y][x] == "x":
				draw_rect(
					Rect2(origin + Vector2(float(x) + 1.0, float(y) + 1.0), Vector2.ONE),
					color
				)


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var font_file: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if font_file == null:
		return ThemeDB.fallback_font
	var copy: FontFile = font_file.duplicate() as FontFile
	if copy == null:
		return font_file
	copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	copy.hinting = TextServer.HINTING_NONE
	copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	copy.allow_system_fallback = false
	copy.generate_mipmaps = false
	copy.oversampling = 1.0
	return copy


func _make_tween() -> Tween:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


# --- read-only state accessors ---------------------------------------------

func get_name_text() -> String:
	return boss_name


func get_core_hp() -> int:
	return _core_current


func get_core_max() -> int:
	return _core_max


func get_phase_index() -> int:
	return _phase_index


func get_phase_count() -> int:
	return _phase_count


func get_form_text() -> String:
	return "形态 %d/%d" % [_phase_index + 1, _phase_count]


func get_hp_ratio() -> float:
	return _hp_ratio


func is_gold_intact() -> bool:
	return _gold_intact


func is_cyan_intact() -> bool:
	return _cyan_intact


func is_core_exposed() -> bool:
	return _exposed


func is_gold_anchored() -> bool:
	return _gold_anchored


func is_cyan_anchored() -> bool:
	return _cyan_anchored


func get_gold_window() -> float:
	return _gold_window


func get_cyan_window() -> float:
	return _cyan_window


func get_anchor_window_max() -> float:
	return 6.0


func is_lives_visible() -> bool:
	return _lives_visible


func get_lives_current() -> int:
	return _lives_current


func get_lives_max() -> int:
	return _lives_max


func is_nodes_visible() -> bool:
	return _nodes_visible


func get_nodes_alive() -> int:
	return _nodes_alive


func get_nodes_max() -> int:
	return _nodes_max


func get_bar_rect() -> Rect2:
	return Rect2(position, BAR_SIZE)


func is_bar_visible() -> bool:
	return visible and modulate.a > 0.01
