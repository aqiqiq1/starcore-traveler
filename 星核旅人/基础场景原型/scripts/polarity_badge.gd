class_name PolarityBadge
extends Node2D

## A small code-drawn polarity glyph above the head. This node is a child of
## Player (not VisualRoot), so it does not mirror when the character turns.

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const SHADOW: Color = Color(0.015, 0.025, 0.03, 0.95)

var _positive: bool = true


func set_positive(value: bool) -> void:
	if _positive == value:
		return
	_positive = value
	queue_redraw()


func _draw() -> void:
	var color: Color = GOLD if _positive else CYAN
	if _positive:
		# Plus: 3 px thick with a 1 px dark outline.
		draw_rect(Rect2(-2.5, -10.5, 5.0, 21.0), SHADOW)
		draw_rect(Rect2(-10.5, -2.5, 21.0, 5.0), SHADOW)
		draw_rect(Rect2(-1.5, -9.5, 3.0, 19.0), color)
		draw_rect(Rect2(-9.5, -1.5, 19.0, 3.0), color)
	else:
		# Minus.
		draw_rect(Rect2(-10.5, -2.5, 21.0, 5.0), SHADOW)
		draw_rect(Rect2(-9.5, -1.5, 19.0, 3.0), color)
