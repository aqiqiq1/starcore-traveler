class_name RiftBossStatus
extends Control

## Compact mirror-boss status row for the rift HUD.
##
## Read order, left to right: gold sun shield, cyan moon shield, three core
## diamonds, three phase marks and "1/3".  A broken shield is dimmed with a
## crack and a red X; a core diamond empties as the exposed core is hit.
## No key/legend sentence is printed here.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const INK: Color = Color(0.006, 0.014, 0.018, 0.94)
const MUTED: Color = Color("#a4b3be")
const PANEL: Color = Color(0.012, 0.028, 0.034, 0.90)
const BORDER: Color = Color(0.30, 0.45, 0.45, 0.75)
const WHITE: Color = Color(1.0, 0.98, 0.90)
const BROKEN: Color = Color(0.86, 0.28, 0.24, 0.95)
const RED: Color = Color("#ff5a4f")
const PURPLE: Color = Color("#a86cff")
const PURPLE_PALE: Color = Color("#e0c8ff")
const ANCHOR_WINDOW: float = 6.0

const ROW_SIZE: Vector2 = Vector2(340.0, 28.0)

var font: Font = null
var _phase_index: int = 0
var _phase_count: int = 3
var _core_hp: int = 3
var _max_core: int = 3
var _gold_intact: bool = true
var _cyan_intact: bool = true
var _exposed: bool = false
var _gold_anchored: bool = false
var _cyan_anchored: bool = false
var _gold_window: float = 0.0
var _cyan_window: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = ROW_SIZE
	size = ROW_SIZE
	queue_redraw()


func set_state(
	phase_index: int, phase_count: int, core_hp: int, max_core: int,
	gold_intact: bool, cyan_intact: bool, exposed: bool
) -> void:
	var changed: bool = (
		phase_index != _phase_index or phase_count != _phase_count
		or core_hp != _core_hp or max_core != _max_core
		or gold_intact != _gold_intact or cyan_intact != _cyan_intact
		or exposed != _exposed
	)
	_phase_index = phase_index
	_phase_count = phase_count
	_core_hp = core_hp
	_max_core = max_core
	_gold_intact = gold_intact
	_cyan_intact = cyan_intact
	_exposed = exposed
	if changed:
		queue_redraw()


## Called separately from set_state so the existing HUD call sites keep their
## shape while the anchor read is still explicit.
func set_anchor_state(
	gold_anchored: bool, cyan_anchored: bool,
	gold_window: float, cyan_window: float
) -> void:
	var changed: bool = (
		gold_anchored != _gold_anchored or cyan_anchored != _cyan_anchored
		or not is_equal_approx(gold_window, _gold_window)
		or not is_equal_approx(cyan_window, _cyan_window)
	)
	_gold_anchored = gold_anchored
	_cyan_anchored = cyan_anchored
	_gold_window = maxf(gold_window, 0.0)
	_cyan_window = maxf(cyan_window, 0.0)
	if changed:
		queue_redraw()


func get_form_text() -> String:
	return "形态 %d/%d" % [_phase_index + 1, _phase_count]


func is_gold_anchored() -> bool:
	return _gold_anchored


func is_cyan_anchored() -> bool:
	return _cyan_anchored


func get_gold_window() -> float:
	return _gold_window


func get_cyan_window() -> float:
	return _cyan_window


func get_anchor_window_max() -> float:
	return ANCHOR_WINDOW


func get_phase_index() -> int:
	return _phase_index


func get_core_hp() -> int:
	return _core_hp


func is_gold_intact() -> bool:
	return _gold_intact


func is_cyan_intact() -> bool:
	return _cyan_intact


func is_core_exposed() -> bool:
	return _exposed


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, ROW_SIZE.x, ROW_SIZE.y), PANEL)
	draw_rect(Rect2(0.0, 0.0, ROW_SIZE.x, 1.0), BORDER)
	draw_rect(Rect2(0.0, ROW_SIZE.y - 1.0, ROW_SIZE.x, 1.0), BORDER)
	if font != null:
		draw_string(
			font, Vector2(7.0, 15.0), "双面镜",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED
		)

	_draw_face(Vector2(72.0, 14.0), true, _gold_intact)
	_draw_face(Vector2(102.0, 14.0), false, _cyan_intact)
	_draw_anchor_overlay(Vector2(72.0, 14.0), _gold_intact, _gold_anchored, _gold_window)
	_draw_anchor_overlay(Vector2(102.0, 14.0), _cyan_intact, _cyan_anchored, _cyan_window)

	for index: int in range(_max_core):
		var filled: bool = index >= _max_core - _core_hp
		_draw_diamond(
			Vector2(132.0 + float(index) * 14.0, 14.0), 6.0,
			WHITE if filled else Color(0.22, 0.30, 0.31, 0.90),
			Color(0.45, 0.62, 0.60, 0.85)
		)

	for index: int in range(_phase_count):
		var active: bool = index <= _phase_index
		var color: Color = GOLD if index % 2 == 0 else CYAN
		draw_rect(
			Rect2(190.0 + float(index) * 8.0, 9.0, 5.0, 10.0),
			Color(color, 0.92) if active else Color(0.18, 0.25, 0.27, 0.85)
		)
	if font != null:
		draw_string(
			font, Vector2(220.0, 19.0), get_form_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, MUTED
		)


func _draw_face(center: Vector2, positive: bool, intact: bool) -> void:
	var color: Color = GOLD if positive else CYAN
	var pale: Color = GOLD_PALE if positive else CYAN_PALE
	var alpha: float = 1.0 if intact else 0.48
	# Shield outline: a 20 x 22 heater shape.
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -11.0),
		center + Vector2(9.0, -7.0),
		center + Vector2(8.0, 5.0),
		center + Vector2(0.0, 11.0),
		center + Vector2(-8.0, 5.0),
		center + Vector2(-9.0, -7.0),
	])
	draw_colored_polygon(points, Color(0.06, 0.09, 0.10, 0.96))
	for index: int in range(points.size()):
		draw_line(points[index], points[(index + 1) % points.size()],
			Color(color, 0.90 * alpha), 1.0)
	# Large sun / moon emblem inside the shield.
	if positive:
		draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(7.0, 7.0)),
			Color(color, alpha))
		for offset: Vector2 in [
			Vector2(0.0, -7.0), Vector2(0.0, 6.0),
			Vector2(-7.0, 0.0), Vector2(6.0, 0.0),
		]:
			draw_rect(Rect2(center + offset - Vector2(0.5, 0.5), Vector2(2.0, 2.0)),
				Color(pale, alpha))
		draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(3.0, 3.0)),
			Color(WHITE, alpha))
	else:
		draw_rect(Rect2(center - Vector2(4.0, 4.0), Vector2(9.0, 9.0)),
			Color(color, alpha))
		draw_rect(Rect2(center + Vector2(1.0, -4.0), Vector2(4.0, 4.0)), INK)
		draw_rect(Rect2(center + Vector2(-5.0, -4.0), Vector2(1.0, 1.0)),
			Color(pale, alpha))
		draw_rect(Rect2(center + Vector2(5.0, 4.0), Vector2(1.0, 1.0)),
			Color(pale, alpha))
	if not intact:
		# Broken: dim face, a crack, and a small red X in the corner.
		draw_line(center + Vector2(-4.0, -8.0), center + Vector2(1.0, -1.0),
			Color(0.08, 0.10, 0.10, 1.0), 1.0)
		draw_line(center + Vector2(1.0, -1.0), center + Vector2(-3.0, 6.0),
			Color(0.08, 0.10, 0.10, 1.0), 1.0)
		draw_line(center + Vector2(5.0, -11.0), center + Vector2(9.0, -7.0),
			BROKEN, 1.0)
		draw_line(center + Vector2(9.0, -11.0), center + Vector2(5.0, -7.0),
			BROKEN, 1.0)


## A live anchor gets a violet chain ring; a killed anchor shows the amber 6 s
## window as a partial right-hand arc.  Both reads sit on the shield itself, so
## the HUD stays one compact row.
func _draw_anchor_overlay(
	center: Vector2, intact: bool, anchored: bool, window: float
) -> void:
	if not intact:
		return
	if anchored:
		for index: int in range(12):
			var angle: float = float(index) * TAU / 12.0
			var dot: Vector2 = center + Vector2(
				round(cos(angle) * 13.0), round(sin(angle) * 13.0)
			)
			draw_rect(Rect2(dot, Vector2(1.0, 1.0)), Color(PURPLE, 0.92))
		draw_rect(Rect2(center + Vector2(-1.0, -14.0), Vector2(3.0, 3.0)),
			Color(PURPLE_PALE, 0.95))
		return
	if window <= 0.0:
		return
	var ratio: float = clampf(window / ANCHOR_WINDOW, 0.0, 1.0)
	var lit: int = int(round(ratio * 10.0))
	for index: int in range(10):
		var y: float = -9.0 + float(index) * 2.0
		var color: Color = Color(GOLD_PALE, 0.95) if index < lit else Color(0.22, 0.28, 0.28, 0.85)
		draw_rect(Rect2(center + Vector2(13.0, y), Vector2(1.0, 2.0)), color)
	draw_rect(Rect2(center + Vector2(12.0, -11.0), Vector2(3.0, 1.0)),
		Color(RED, 0.75))


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
