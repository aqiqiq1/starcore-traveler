class_name PixelMenuButton
extends Control

## Small pixel-art menu control for the display settings.
##
## It deliberately avoids the default rounded Button theme: the face, border,
## chamfered corners and text are drawn as integer rectangles with the project
## Fusion Pixel font.  Mouse click, Enter/Space, Tab and directional focus all
## work through the normal Control focus system.

signal pressed

enum Variant { OPTION = 0, STONE = 1 }

const IVORY: Color = Color("#f0f5ec")
const IVORY_SOFT: Color = Color("#deecdf")
const PALE_CYAN: Color = Color("#b6d6d2")
const GOLD: Color = Color("#cba45e")
const DARK_TEAL: Color = Color("#14343e")
const TEXT_MUTED: Color = Color("#728889")

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()

@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

@export var disabled: bool = false:
	set(value):
		disabled = value
		focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
		if disabled:
			_hovered = false
			_pressed_inside = false
		queue_redraw()

@export var variant: int = Variant.OPTION:
	set(value):
		variant = value
		queue_redraw()

var font: Font = null
var font_size: int = 12

var _hovered: bool = false
var _pressed_inside: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			grab_focus()
			_pressed_inside = true
			queue_redraw()
			accept_event()
		elif _pressed_inside:
			_pressed_inside = false
			queue_redraw()
			if Rect2(Vector2.ZERO, size).has_point(mouse.position):
				pressed.emit()
			accept_event()
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			pressed.emit()
			accept_event()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var focused: bool = has_focus()
	var hovered: bool = _hovered and not disabled
	var border: Color = IVORY
	var face: Color = DARK_TEAL
	var text_color: Color = IVORY_SOFT
	var cut: int = 3 if variant == Variant.OPTION else 4
	if disabled:
		border = Color(IVORY, 0.20)
		face = Color(DARK_TEAL.darkened(0.18), 0.68)
		text_color = Color(TEXT_MUTED, 0.62)
	elif selected:
		border = GOLD
		face = Color(0.078, 0.196, 0.220, 0.96)
		text_color = GOLD
	elif hovered:
		border = Color(PALE_CYAN, 0.95)
		text_color = IVORY
	if focused and not disabled:
		border = PALE_CYAN
		text_color = IVORY if not selected else GOLD
	if _pressed_inside and not disabled:
		face = face.lightened(0.08)

	_draw_chamfer(Rect2(0.0, 0.0, size.x, size.y), border, cut)
	_draw_chamfer(
		Rect2(1.0, 1.0, maxf(size.x - 2.0, 1.0), maxf(size.y - 2.0, 1.0)),
		face,
		maxi(cut - 1, 0)
	)
	if variant == Variant.STONE and not disabled:
		_draw_ring_1px(
			Rect2(4.0, 4.0, maxf(size.x - 8.0, 2.0), maxf(size.y - 8.0, 2.0)),
			Color(GOLD, 0.62 if not focused else 0.95),
			maxi(cut - 2, 1)
		)
	if selected and not disabled:
		draw_rect(Rect2(4.0, 3.0, 3.0, 2.0), Color(GOLD, 0.95))
	if focused and not disabled:
		var caret_y: float = round((size.y - 7.0) * 0.5)
		draw_rect(Rect2(3.0, caret_y, 2.0, 7.0), PALE_CYAN)
	if font != null:
		var baseline: float = round((size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size))
		draw_string(
			font,
			Vector2(0.0, baseline + 1.0),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			font_size,
			Color(0.004, 0.012, 0.016, 0.85)
		)
		draw_string(
			font,
			Vector2(0.0, baseline),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			font_size,
			text_color
		)


func _draw_chamfer(rect: Rect2, color: Color, cut: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var c: float = clampf(float(cut), 0.0, floor(minf(rect.size.x, rect.size.y) * 0.5))
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(rect.position.x + c, rect.position.y),
		Vector2(rect.position.x + rect.size.x - c, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + c),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - c),
		Vector2(rect.position.x + rect.size.x - c, rect.position.y + rect.size.y),
		Vector2(rect.position.x + c, rect.position.y + rect.size.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y - c),
		Vector2(rect.position.x, rect.position.y + c),
	])
	draw_colored_polygon(points, color)


func _draw_ring_1px(rect: Rect2, color: Color, cut: int) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var c: float = clampf(float(cut), 0.0, floor(minf(rect.size.x, rect.size.y) * 0.5))
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.position.x + rect.size.x - 1.0
	var bottom: float = rect.position.y + rect.size.y - 1.0
	draw_rect(Rect2(left + c, top, maxf(rect.size.x - c * 2.0, 1.0), 1.0), color)
	draw_rect(Rect2(left + c, bottom, maxf(rect.size.x - c * 2.0, 1.0), 1.0), color)
	draw_rect(Rect2(left, top + c, 1.0, maxf(rect.size.y - c * 2.0, 1.0)), color)
	draw_rect(Rect2(right, top + c, 1.0, maxf(rect.size.y - c * 2.0, 1.0)), color)
	draw_rect(Rect2(left + 1.0, top + 1.0, c, 1.0), color)
	draw_rect(Rect2(left + 1.0, top + 2.0, 1.0, c), color)
	draw_rect(Rect2(right - 1.0, top + 1.0, c, 1.0), color)
	draw_rect(Rect2(right - 1.0, top + 2.0, 1.0, c), color)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed_inside = false
	queue_redraw()
