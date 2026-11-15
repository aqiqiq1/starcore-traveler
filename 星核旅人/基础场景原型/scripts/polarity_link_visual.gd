@tool
class_name PolarityLinkVisual
extends Node2D

## Pure visual overlay for the approved "bay records a polarity -> short link ->
## rune stone" presentation idea.
##
## This component owns no bay state, storage, core movement, force field, rune
## state, removal/recovery rule, collision, or input. `record_positive` and
## `record_available` are only the currently displayed lamp state.
## `play_transfer()` only animates one short pulse from source to target and
## then emits a signal.
##
## Gameplay integration may set `update_record_on_delivery = false` and call
## `set_record_display()` at the instant the bay records, so the lamp shows the
## real record immediately and the later pulse arrival cannot pretend to be the
## moment the bay remembered it. An unavailable record draws a neutral lens
## instead of inventing a default gold record. Existing visual-only callers keep
## the original default (lamp updates when the pulse arrives).
##
## Visual pieces, all code-drawn except the bay instance placed by a caller:
##   - a 7x9 record lamp with a dark housing, a gold/cyan lens, and a tiny +/-
##     symbol. It sits just left of the bay pedestal and never covers the
##     32x32 base PNG or the existing 4x3 lock mark;
##   - a one-pixel dashed rune guide with small cross ticks;
##   - a 5-pixel pulse head plus a short trail travelling source -> target;
##   - a very short arrival glint at the target.
##
## No PNG is added or edited. The lamp is deliberately gold/cyan only; the
## purple core stays the existing LOCKED StarCoreVisual inside the bay.
##
## Pixel contract: all geometry is drawn at integer local coordinates with
## nearest filtering. The preview shows 1x for judgement and a 4x inspection
## panel for the lamp. All z indices in the bay and in this scene are
## non-negative (bay Base/LockMark=1, Core=2, Glass=3; this overlay=4), so a
## Control background cannot hide the base.
##
## Playback contract:
##   - `play_transfer(positive)` restarts from the source; if called again, the
##     latest call wins and no completion for the abandoned request is emitted;
##   - tree pause freezes progress and the arrival glint;
##   - `stop_transfer()` abandons the request without a signal;
##   - completion emits exactly one `visual_delivery_finished(positive: bool)`
##     for the request that reached the target, and updates the lamp.
##
## Anchors: set `source_path` / `target_path` to Node2D nodes for editor
## placement, or leave them empty and use `source_position` / `target_position`
## (local to this component). Offsets are local pixels in this component's
## space. In the editor the anchors are re-checked so moving either node
## refreshes the drawing.

signal visual_delivery_finished(positive: bool)

const BAY_RECT: Rect2 = Rect2(-16.0, -16.0, 32.0, 32.0)
const BAY_PEDESTAL_RECT: Rect2 = Rect2(-16.0, 8.0, 32.0, 8.0)
const BAY_LOCK_MARK_RECT: Rect2 = Rect2(4.0, 11.0, 4.0, 3.0)

## Lamp geometry is relative to the resolved source origin. At the default
## offset the 7x9 housing spans x=-24..-18, y=7..15, immediately left of the
## 32x32 bay rect (x=-16..16) with a one-pixel gap. It never covers the base or
## the 4x3 lock mark at x=4..8, y=11..14.
const RECORD_LAMP_SIZE: Vector2 = Vector2(7.0, 9.0)
const RECORD_LAMP_LENS_RECT: Rect2 = Rect2(1.0, 2.0, 5.0, 5.0)
const RECORD_LAMP_BRACKET_RECT: Rect2 = Rect2(7.0, 3.0, 1.0, 3.0)
const DEFAULT_RECORD_LAMP_OFFSET: Vector2 = Vector2(-24.0, 7.0)

const POSITIVE_COLOR: Color = Color("#f4cd63")
const NEGATIVE_COLOR: Color = Color("#5fe1e6")
const NEUTRAL_COLOR: Color = Color("#7f938f")
const NEUTRAL_LENS: Color = Color("#263438")
const LAMP_FRAME_DARK: Color = Color("#0d171a")
const LAMP_FRAME_MID: Color = Color("#435456")
const LAMP_FRAME_LIGHT: Color = Color("#a9bcb9")
const LAMP_SYMBOL: Color = Color("#0b1417")
const LAMP_GLINT: Color = Color(1.0, 0.98, 0.92, 0.88)

const LINK_DASH_ALPHA: float = 0.44
const LINK_UNDERLAY_ALPHA: float = 0.13
const LINK_TICK_ALPHA: float = 0.62
const PULSE_HEAD_COLOR: Color = Color.WHITE
const ARRIVAL_FLASH_DURATION: float = 0.18
const MAX_TRANSFER_DURATION: float = 5.0
const MIN_TRANSFER_DURATION: float = 0.05

@export_group("Polarity Display")
## Current recorded polarity shown by the lamp. This is a display value only;
## it is not read from, or written to, a real star-core bay.
@export var record_positive: bool = true:
	set(value):
		if record_positive == value:
			return
		record_positive = value
		_request_redraw()

## False before the first real record. The housing still marks the bay/stone
## relationship, but the lens is neutral and no gold/cyan polarity is implied.
@export var record_available: bool = true:
	set(value):
		if record_available == value:
			return
		record_available = value
		_request_redraw()

## Visual-only callers expect the lamp to change when the pulse arrives
## (default). Real bay gameplay sets this false and updates the lamp at store
## acceptance through set_record_display().
@export var update_record_on_delivery: bool = true

@export_range(0.05, 5.0, 0.01, "suffix:s") var transfer_duration: float = 0.75:
	set(value):
		transfer_duration = clampf(value, MIN_TRANSFER_DURATION, MAX_TRANSFER_DURATION)
		_request_redraw()

@export_group("Anchors")
## Optional Node2D path. When set and resolvable, it wins over source_position.
@export var source_path: NodePath:
	set(value):
		source_path = value
		_request_redraw()

## Optional Node2D path. When set and resolvable, it wins over target_position.
@export var target_path: NodePath:
	set(value):
		target_path = value
		_request_redraw()

## Local fallback used when source_path is empty or cannot be resolved.
@export var source_position: Vector2 = Vector2.ZERO:
	set(value):
		source_position = value
		_request_redraw()

## Local fallback used when target_path is empty or cannot be resolved.
@export var target_position: Vector2 = Vector2(160.0, 0.0):
	set(value):
		target_position = value
		_request_redraw()

## Offset from the source origin to the start of the guide line. The default
## starts one pixel outside the bay's right edge, not on the base PNG.
@export var link_source_offset: Vector2 = Vector2(17.0, 12.0):
	set(value):
		link_source_offset = value
		_request_redraw()

@export var link_target_offset: Vector2 = Vector2.ZERO:
	set(value):
		link_target_offset = value
		_request_redraw()

@export_group("Drawing")
@export var show_link_guide: bool = true:
	set(value):
		show_link_guide = value
		_request_redraw()

@export var show_record_lamp: bool = true:
	set(value):
		show_record_lamp = value
		_request_redraw()

## Top-left of the 7x9 lamp, relative to the resolved source origin.
@export var record_lamp_offset: Vector2 = DEFAULT_RECORD_LAMP_OFFSET:
	set(value):
		record_lamp_offset = value
		_request_redraw()

## Positive bows down, negative bows up. Zero is a straight quadratic line.
@export_range(-64.0, 64.0, 1.0, "suffix:px") var link_arc_height: float = -8.0:
	set(value):
		link_arc_height = clampf(value, -64.0, 64.0)
		_request_redraw()

var _transfer_active: bool = false
var _transfer_positive: bool = true
var _transfer_elapsed: float = 0.0
var _arrival_flash: float = 0.0
var _last_delivered_positive: bool = true
var _editor_geometry_key: String = ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_last_delivered_positive = record_positive
	_editor_geometry_key = _current_geometry_key()
	if Engine.is_editor_hint():
		set_process(true)
	else:
		set_process(_transfer_active or _arrival_flash > 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_tick()
		return
	if _transfer_active or _arrival_flash > 0.0:
		advance_transfer(delta)
	else:
		set_process(false)


## Advance the visual transfer by a fixed delta. Exposed for deterministic
## tests and captures; normal runtime uses _process. Tree pause always freezes
## this method, even if a caller set the node's process mode to ALWAYS.
func advance_transfer(delta: float) -> void:
	if delta <= 0.0:
		return
	if get_tree() != null and get_tree().paused:
		return

	if _arrival_flash > 0.0:
		_arrival_flash = maxf(0.0, _arrival_flash - delta)
		queue_redraw()

	if not _transfer_active:
		if _arrival_flash <= 0.0:
			set_process(false)
		return

	_transfer_elapsed += delta
	var duration: float = maxf(transfer_duration, MIN_TRANSFER_DURATION)
	if _transfer_elapsed >= duration:
		_transfer_elapsed = duration
		_complete_transfer()
	else:
		queue_redraw()


## Start (or restart) a transfer. Repeated calls are deliberately last-call-wins:
## the visual restarts at the source and the abandoned request never emits.
func play_transfer(positive: bool) -> void:
	_transfer_positive = positive
	_transfer_elapsed = 0.0
	_transfer_active = true
	_arrival_flash = 0.0
	set_process(true)
	queue_redraw()


## Directly set the lamp to a real record (or to neutral when available=false)
## without running a transfer. Gameplay calls this at store acceptance before
## starting the pulse. The pulse arrival does not overwrite it when
## update_record_on_delivery is false.
func set_record_display(positive: bool, available: bool = true) -> void:
	record_available = available
	if available and record_positive != positive:
		record_positive = positive
	_request_redraw()


## Abandon the current visual transfer without emitting a completion signal.
func stop_transfer() -> void:
	_transfer_active = false
	_transfer_elapsed = 0.0
	_arrival_flash = 0.0
	if not Engine.is_editor_hint():
		set_process(false)
	queue_redraw()


func is_transfer_active() -> bool:
	return _transfer_active


func get_transfer_progress() -> float:
	if _transfer_elapsed <= 0.0:
		return 0.0
	return clampf(_transfer_elapsed / maxf(transfer_duration, MIN_TRANSFER_DURATION), 0.0, 1.0)


func get_transfer_polarity() -> bool:
	return _transfer_positive


func get_last_delivered_positive() -> bool:
	return _last_delivered_positive


func is_arrival_flash_active() -> bool:
	return _arrival_flash > 0.0


func get_arrival_flash_alpha() -> float:
	return clampf(_arrival_flash / ARRIVAL_FLASH_DURATION, 0.0, 1.0)


func get_source_origin() -> Vector2:
	var node: Node2D = _resolve_node(source_path)
	if node != null:
		return to_local(node.global_position)
	return source_position


func get_target_origin() -> Vector2:
	var node: Node2D = _resolve_node(target_path)
	if node != null:
		return to_local(node.global_position)
	return target_position


func get_link_source_point() -> Vector2:
	return get_source_origin() + link_source_offset


func get_link_target_point() -> Vector2:
	return get_target_origin() + link_target_offset


func get_link_source_global() -> Vector2:
	return to_global(get_link_source_point())


func get_link_target_global() -> Vector2:
	return to_global(get_link_target_point())


func get_link_curve_point(t: float) -> Vector2:
	return _curve_point(get_link_source_point(), get_link_target_point(), clampf(t, 0.0, 1.0))


func get_pulse_position() -> Vector2:
	if not _transfer_active:
		return get_link_target_point()
	return get_link_curve_point(get_transfer_progress())


func get_pulse_global_position() -> Vector2:
	return to_global(get_pulse_position())


func get_pulse_color() -> Color:
	if _transfer_active or _arrival_flash > 0.0:
		return _accent_for(_transfer_positive)
	return _accent_for(record_positive)


func get_record_lamp_rect() -> Rect2:
	return Rect2(get_source_origin() + record_lamp_offset, RECORD_LAMP_SIZE)


func get_record_lamp_lens_rect() -> Rect2:
	var lamp: Rect2 = get_record_lamp_rect()
	return Rect2(lamp.position + RECORD_LAMP_LENS_RECT.position, RECORD_LAMP_LENS_RECT.size)


func get_record_lamp_bracket_rect() -> Rect2:
	var lamp: Rect2 = get_record_lamp_rect()
	return Rect2(lamp.position + RECORD_LAMP_BRACKET_RECT.position, RECORD_LAMP_BRACKET_RECT.size)


func get_record_lamp_center() -> Vector2:
	return get_record_lamp_rect().get_center()


func get_record_lamp_accent_color() -> Color:
	return _record_accent()


func get_record_symbol() -> StringName:
	if not record_available:
		return &"none"
	return &"plus" if record_positive else &"minus"


func is_record_available() -> bool:
	return record_available


func get_badge_color(positive: bool) -> Color:
	return _accent_for(positive)


## Refresh anchor drawing from the editor after either linked node moved.
func _editor_tick() -> void:
	var key: String = _current_geometry_key()
	if key == _editor_geometry_key:
		return
	_editor_geometry_key = key
	queue_redraw()


func _current_geometry_key() -> String:
	return "%s|%s|%s|%s|%s" % [
		str(get_link_source_point()),
		str(get_link_target_point()),
		str(get_record_lamp_rect()),
		str(record_positive),
		str(record_available),
	]


func _complete_transfer() -> void:
	var delivered: bool = _transfer_positive
	_transfer_active = false
	_arrival_flash = ARRIVAL_FLASH_DURATION
	_last_delivered_positive = delivered
	if update_record_on_delivery:
		record_available = true
		record_positive = delivered
	set_process(true)
	queue_redraw()
	# All state is settled before emitting. A listener may start another
	# transfer; this completion must not overwrite that newer request.
	visual_delivery_finished.emit(delivered)


func _resolve_node(path: NodePath) -> Node2D:
	if path.is_empty():
		return null
	var node: Node = get_node_or_null(path)
	if node == null or not is_instance_valid(node):
		return null
	return node as Node2D


func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()


func _accent_for(positive: bool) -> Color:
	return POSITIVE_COLOR if positive else NEGATIVE_COLOR


func _record_accent() -> Color:
	if not record_available:
		return NEUTRAL_COLOR
	return _accent_for(record_positive)


func _curve_point(a: Vector2, b: Vector2, t: float) -> Vector2:
	var control: Vector2 = (a + b) * 0.5 + Vector2(0.0, link_arc_height)
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _build_link_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(12, int(ceil(a.distance_to(b))))
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		points.append(_curve_point(a, b, t))
	return points


func _draw() -> void:
	var source: Vector2 = get_source_origin()
	var target: Vector2 = get_target_origin()
	var link_a: Vector2 = source + link_source_offset
	var link_b: Vector2 = target + link_target_offset

	if show_link_guide:
		_draw_link_guide(link_a, link_b)
	if show_record_lamp:
		_draw_record_lamp(source + record_lamp_offset)
	if _transfer_active:
		_draw_pulse(link_a, link_b)
	if _arrival_flash > 0.0:
		_draw_arrival_glint(link_b)


func _draw_link_guide(a: Vector2, b: Vector2) -> void:
	var points: PackedVector2Array = _build_link_points(a, b)
	if points.size() < 2:
		return
	var accent: Color = _record_accent()
	var underlay: Color = accent
	underlay.a = LINK_UNDERLAY_ALPHA
	var dash: Color = accent
	dash.a = LINK_DASH_ALPHA
	var tick: Color = accent
	tick.a = LINK_TICK_ALPHA

	for index: int in range(points.size()):
		_draw_pixel(points[index], underlay)
		if index % 4 >= 2:
			continue
		_draw_pixel(points[index], dash)
		if index > 12 and index % 52 < 2:
			var direction: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
			var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
			var center: Vector2 = _snap(points[index])
			_draw_pixel(center + perpendicular, tick)
			_draw_pixel(center - perpendicular, tick)


func _draw_record_lamp(top_left: Vector2) -> void:
	var origin: Vector2 = _snap(top_left)
	var x: float = origin.x
	var y: float = origin.y
	var accent: Color = _record_accent()

	# Small metal housing: cap, body, side highlight, foot, and a one-pixel
	# bracket toward (but not onto) the bay pedestal.
	draw_rect(Rect2(x + 1.0, y, 5.0, 1.0), LAMP_FRAME_MID)
	draw_rect(Rect2(x, y + 1.0, 7.0, 7.0), LAMP_FRAME_DARK)
	draw_rect(Rect2(x, y + 1.0, 1.0, 7.0), LAMP_FRAME_LIGHT)
	draw_rect(Rect2(x + 6.0, y + 1.0, 1.0, 7.0), LAMP_FRAME_MID)
	draw_rect(Rect2(x + 1.0, y + 8.0, 5.0, 1.0), LAMP_FRAME_MID)
	draw_rect(Rect2(x + 7.0, y + 3.0, 1.0, 3.0), LAMP_FRAME_MID)

	# Five-by-five lens in the recorded polarity colour. No purple is used here:
	# the purple gem remains the bay's separate LOCKED core. Before the first
	# real record the lens stays neutral instead of implying a gold default.
	if not record_available:
		draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 5.0), NEUTRAL_LENS)
		draw_rect(Rect2(x + 2.0, y + 4.0, 3.0, 1.0), LAMP_FRAME_MID)
		return
	draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 5.0), accent)
	draw_rect(Rect2(x + 1.0, y + 2.0, 1.0, 1.0), LAMP_GLINT)

	if record_positive:
		draw_rect(Rect2(x + 3.0, y + 3.0, 1.0, 3.0), LAMP_SYMBOL)
		draw_rect(Rect2(x + 2.0, y + 4.0, 3.0, 1.0), LAMP_SYMBOL)
	else:
		draw_rect(Rect2(x + 2.0, y + 4.0, 3.0, 1.0), LAMP_SYMBOL)


func _draw_pulse(a: Vector2, b: Vector2) -> void:
	var progress: float = get_transfer_progress()
	var accent: Color = _accent_for(_transfer_positive)
	var total_distance: float = maxf(a.distance_to(b), 1.0)

	# A short trail, sampled backwards along the same curve. No particles or
	# one-shot scene nodes are created, so repeated calls cannot accumulate.
	for index: int in range(1, 6):
		var back_t: float = clampf(progress - float(index * 2) / total_distance, 0.0, 1.0)
		var trail: Color = accent
		trail.a = maxf(0.12, 0.62 - float(index) * 0.10)
		_draw_pixel(_curve_point(a, b, back_t), trail)

	var head: Vector2 = _snap(_curve_point(a, b, progress))
	var halo: Color = accent
	halo.a = 0.95
	draw_rect(Rect2(head.x - 1.0, head.y, 3.0, 1.0), halo)
	draw_rect(Rect2(head.x, head.y - 1.0, 1.0, 3.0), halo)
	var core: Color = accent.lerp(PULSE_HEAD_COLOR, 0.55)
	draw_rect(Rect2(head, Vector2.ONE), core)


func _draw_arrival_glint(target: Vector2) -> void:
	var alpha: float = get_arrival_flash_alpha()
	var color: Color = _accent_for(_last_delivered_positive)
	color.a = alpha * 0.80
	var point: Vector2 = _snap(target)
	draw_rect(Rect2(point.x - 2.0, point.y, 5.0, 1.0), color)
	draw_rect(Rect2(point.x, point.y - 2.0, 1.0, 5.0), color)


func _draw_pixel(point: Vector2, color: Color) -> void:
	var snapped: Vector2 = _snap(point)
	draw_rect(Rect2(snapped, Vector2.ONE), color)


func _snap(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x), roundf(point.y))
