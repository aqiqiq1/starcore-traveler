class_name SkipHoldBar
extends Control

## Hold-to-skip feedback shared by the level-01 opening and the level-03
## cinematic.
##
## Presentation only: this node never reads input and never changes the skip
## timer, the await-release boundary or input handling. Each cinematic creates
## one inside its own CanvasLayer UI and drives it from its existing hold state.
##
## Geometry is the approved 2026-11-19 spec: bottom-right of the 640x360
## logical viewport, 96x6 track at (528, 336), 12 px "跳过" label to its left.
## Colors follow the approved pause panel: near-black track, 1 px cyan-grey
## (#739e9f) border and gold (#f4cd63) fill. No texture, no corner radius, no
## shadow, no anti-aliasing.
##
## A tap shorter than REVEAL_DELAY never shows the bar, so a short Space press
## produces no flash. Once shown, progress is held_seconds / hold_duration.

const BAR_POSITION: Vector2 = Vector2(528.0, 336.0)
const BAR_SIZE: Vector2 = Vector2(96.0, 6.0)
const BORDER: float = 1.0
const INNER_SIZE: Vector2 = Vector2(94.0, 4.0)
const REVEAL_DELAY: float = 0.10
const LABEL_TEXT: String = "跳过"
const LABEL_FONT_SIZE: int = 12
const LABEL_SIZE: Vector2 = Vector2(24.0, 16.0)
const LABEL_GAP: float = 6.0
const LABEL_COLOR: Color = Color("#a4b3be")
const TRACK_BG: Color = Color(0.014, 0.032, 0.040, 0.96)
const TRACK_BORDER: Color = Color("#739e9f")
const FILL_COLOR: Color = Color("#f4cd63")
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

var _panel: Panel = null
var _fill: ColorRect = null
var _label: Label = null
var _style: StyleBoxFlat = null
var _progress: float = 0.0


func _ready() -> void:
	name = "SkipHoldBar"
	position = BAR_POSITION
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = Panel.new()
	_panel.name = "Track"
	_panel.position = Vector2.ZERO
	_panel.size = BAR_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = TRACK_BG
	_style.border_width_left = int(BORDER)
	_style.border_width_top = int(BORDER)
	_style.border_width_right = int(BORDER)
	_style.border_width_bottom = int(BORDER)
	_style.border_color = TRACK_BORDER
	_style.set_corner_radius_all(0)
	_style.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)

	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.position = Vector2(BORDER, BORDER)
	_fill.size = Vector2(0.0, INNER_SIZE.y)
	_fill.color = FILL_COLOR
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_fill)

	_label = Label.new()
	_label.name = "SkipLabel"
	_label.text = LABEL_TEXT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _load_font())
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	add_child(_label)
	# Size after the theme overrides so the box uses the 12 px font's real
	# minimum, then pin the box 6 px left of the track and centre it on the bar.
	var minimum: Vector2 = _label.get_minimum_size()
	_label.size = Vector2(maxf(LABEL_SIZE.x, minimum.x), maxf(LABEL_SIZE.y, minimum.y))
	_label.position = Vector2(
		-_label.size.x - LABEL_GAP,
		(BAR_SIZE.y - _label.size.y) * 0.5
	)


func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		return ThemeDB.fallback_font
	var copy: FontFile = base.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		return copy
	return base


## Called every frame by the owning cinematic while it is running.
## `held` must already exclude the await-release / outro states.
func update_hold(held: bool, held_seconds: float, hold_duration: float) -> void:
	if not held or hold_duration <= 0.0 or held_seconds < REVEAL_DELAY:
		hide_progress()
		return
	set_progress(held_seconds / hold_duration)
	visible = true


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _fill != null:
		_fill.size.x = roundf(INNER_SIZE.x * _progress)


func hide_progress() -> void:
	visible = false
	_progress = 0.0
	if _fill != null:
		_fill.size.x = 0.0


func get_progress() -> float:
	return _progress


func get_fill_width() -> float:
	return _fill.size.x if _fill != null else 0.0


func get_bar_rect() -> Rect2:
	return Rect2(position, size)


func get_label_rect() -> Rect2:
	if _label == null:
		return Rect2()
	return Rect2(_label.position, _label.size)


func get_label_text() -> String:
	return _label.text if _label != null else ""


func get_label_font_size() -> int:
	if _label == null:
		return 0
	return _label.get_theme_font_size("font_size")


func get_style() -> StyleBoxFlat:
	return _style
