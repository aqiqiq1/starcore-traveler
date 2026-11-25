class_name PixelVolumeSlider
extends Control

## Small pixel-art volume slider for the level start menu.
##
## It is a real focusable Control: mouse press/drag, arrow keys, Home/End and
## PageUp/PageDown all change the value. It draws its own 1-bit track and handle
## in the menu palette, so it does not pull in the default rounded web-style
## grabber. It owns no audio state; the menu binds the value to the Master bus.

signal value_changed(value: float)

const GOLD: Color = Color("#cba45e")
const PALE_CYAN: Color = Color("#b6d6d2")
const IVORY: Color = Color("#f0f5ec")
const DARK: Color = Color("#0c2028")
const TRACK: Color = Color("#31545b")

@export_range(0.0, 100.0, 1.0) var value: float = 100.0:
	set(new_value):
		value = clampf(new_value, 0.0, 100.0)
		queue_redraw()
		if not _suppress_emit:
			value_changed.emit(value)

var _dragging: bool = false
var _hovered: bool = false
var _suppress_emit: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	custom_minimum_size = Vector2(212.0, 16.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func set_value_silent(new_value: float) -> void:
	_suppress_emit = true
	value = clampf(new_value, 0.0, 100.0)
	_suppress_emit = false


func get_value() -> float:
	return value


func is_dragging() -> bool:
	return _dragging


func cancel_drag() -> void:
	_dragging = false
	queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var border_rect: Rect2 = Rect2(0.0, 6.0, width, 4.0)
	draw_rect(border_rect, Color(IVORY, 0.55), false, 1.0)
	draw_rect(Rect2(1.0, 7.0, maxf(width - 2.0, 0.0), 2.0), Color(TRACK, 0.85))

	var ratio: float = clampf(value / 100.0, 0.0, 1.0)
	var fill_width: float = roundf(maxf(width - 2.0, 0.0) * ratio)
	if fill_width > 0.0:
		draw_rect(Rect2(1.0, 7.0, fill_width, 2.0), Color(GOLD, 0.9))

	var handle_x: float = roundf(maxf(width - 5.0, 0.0) * ratio)
	var handle_rect: Rect2 = Rect2(handle_x, 2.0, 5.0, 11.0)
	draw_rect(handle_rect, Color(IVORY, 1.0))
	draw_rect(Rect2(handle_x + 1.0, 3.0, 3.0, 9.0), Color(DARK, 0.95))
	var handle_inner: Color = GOLD if (_hovered or _dragging or has_focus()) else PALE_CYAN
	draw_rect(Rect2(handle_x + 2.0, 4.0, 1.0, 7.0), Color(handle_inner, 0.95))

	if has_focus():
		draw_rect(Rect2(0.0, 0.0, width, size.y), Color(PALE_CYAN, 0.55), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				grab_focus()
				_dragging = true
				_apply_from_local_x(mouse.position.x)
				accept_event()
			elif _dragging:
				_dragging = false
				queue_redraw()
				accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_from_local_x(motion.position.x)
		accept_event()
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return
		var changed: bool = true
		match key.keycode:
			KEY_LEFT, KEY_DOWN:
				value = value - 5.0
			KEY_RIGHT, KEY_UP:
				value = value + 5.0
			KEY_HOME:
				value = 0.0
			KEY_END:
				value = 100.0
			KEY_PAGEUP:
				value = value + 10.0
			KEY_PAGEDOWN:
				value = value - 10.0
			_:
				changed = false
		if changed:
			accept_event()


# While the mouse is captured by a drag, keep receiving motion even when the
# pointer leaves the 16 px control. Focus loss is handled by the menu, which
# calls cancel_drag() so a lost window cannot leave the slider latched.
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_apply_from_local_x(get_viewport().get_mouse_position().x - get_global_rect().position.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			_dragging = false
			queue_redraw()
			get_viewport().set_input_as_handled()


func _apply_from_local_x(local_x: float) -> void:
	var usable: float = maxf(size.x - 5.0, 1.0)
	var ratio: float = clampf((local_x - 2.5) / usable, 0.0, 1.0)
	value = roundf(ratio * 100.0)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()
