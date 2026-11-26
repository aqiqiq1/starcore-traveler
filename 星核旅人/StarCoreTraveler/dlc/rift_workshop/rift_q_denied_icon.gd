class_name RiftQDeniedIcon
extends Control

## Screen-space "Q is locked" icon shown above the player's head for 0.8 s.
## It follows the real player transform like the small heart row; it is not a
## gameplay node and never changes polarity.  Everything is drawn from pixels.
##
## Read order: dark keycap with a bright Q, then a clear 2 px red X.  The X is
## wider than the letter so the refusal reads even at 1x.

const SIZE: Vector2 = Vector2(28.0, 28.0)
const INK: Color = Color(0.006, 0.014, 0.018, 0.96)
const BORDER: Color = Color(0.98, 0.80, 0.36, 0.95)
const PAPER: Color = Color(0.99, 0.96, 0.86, 1.0)
const DENIED: Color = Color(0.98, 0.24, 0.20, 1.0)

var _target: Node2D = null
var _left: float = 0.0
var _flash_count: int = 0


func _ready() -> void:
	name = "QDeniedIcon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	visible = false


func flash(target: Node2D, seconds: float = 0.8) -> void:
	_target = target
	_left = maxf(seconds, 0.15)
	_flash_count += 1
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _left <= 0.0:
		if visible:
			visible = false
		return
	if get_tree() != null and get_tree().paused:
		visible = false
		return
	_left = maxf(_left - delta, 0.0)
	if _target == null or not is_instance_valid(_target):
		visible = false
		return
	var screen: Vector2 = _target.get_global_transform_with_canvas().origin
	var x: float = clampf(
		screen.x - SIZE.x * 0.5, 6.0, 640.0 - SIZE.x - 6.0
	)
	var y: float = clampf(
		screen.y - 64.0, 6.0, 360.0 - SIZE.y - 6.0
	)
	position = Vector2(round(x), round(y))
	visible = true
	queue_redraw()


func is_showing() -> bool:
	return visible and _left > 0.0


func get_flash_count() -> int:
	return _flash_count


func get_icon_rect() -> Rect2:
	return Rect2(position, SIZE)


func _draw() -> void:
	# Dark keycap, gold rim.  No solid red block: the red is the X only.
	draw_rect(Rect2(1.0, 1.0, 26.0, 26.0), INK)
	draw_rect(Rect2(1.0, 1.0, 26.0, 1.0), BORDER)
	draw_rect(Rect2(1.0, 26.0, 26.0, 1.0), BORDER)
	draw_rect(Rect2(1.0, 2.0, 1.0, 24.0), BORDER)
	draw_rect(Rect2(26.0, 2.0, 1.0, 24.0), BORDER)

	# Uppercase Q, 12 x 14, 2 px strokes.
	var q_x: float = 8.0
	var q_y: float = 7.0
	draw_rect(Rect2(q_x, q_y, 12.0, 2.0), PAPER)
	draw_rect(Rect2(q_x, q_y + 11.0, 12.0, 2.0), PAPER)
	draw_rect(Rect2(q_x, q_y + 2.0, 2.0, 9.0), PAPER)
	draw_rect(Rect2(q_x + 10.0, q_y + 2.0, 2.0, 9.0), PAPER)
	draw_rect(Rect2(q_x + 7.0, q_y + 8.0, 3.0, 2.0), PAPER)
	draw_rect(Rect2(q_x + 10.0, q_y + 11.0, 3.0, 2.0), PAPER)

	# Clear red X over the Q.
	draw_line(Vector2(2.0, 2.0), Vector2(25.0, 25.0), DENIED, 2.0)
	draw_line(Vector2(25.0, 2.0), Vector2(2.0, 25.0), DENIED, 2.0)
