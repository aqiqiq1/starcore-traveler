@tool
class_name StarCoreBayLockMark
extends Node2D

## Tiny code-drawn lock mark for the star-core bay pedestal.
##
## This is a separate child node at z=1, after Base (also z=1) and below Core
## (z=2) / Glass (z=3). Keeping it separate lets Base stay at a non-negative z
## so it is never hidden behind a preview/UI Control's background, while the
## mark still draws on top of the pedestal. It is intentionally not baked into
## any PNG: the empty bay has no lock.

const MARK_RECT: Rect2 = Rect2(4.0, 11.0, 4.0, 3.0)
const LOCK_GOLD: Color = Color("#e2bd6a")
const LOCK_LIGHT: Color = Color("#f7e3a2")
const LOCK_DARK: Color = Color("#6b7f8b")


func get_marker_rect() -> Rect2:
	return MARK_RECT


func _draw() -> void:
	# 4x3 shape: shackle, body, keyhole. Same pixels as the previous root draw.
	draw_rect(Rect2(5.0, 11.0, 2.0, 1.0), LOCK_LIGHT)
	draw_rect(Rect2(4.0, 12.0, 4.0, 2.0), LOCK_GOLD)
	draw_rect(Rect2(4.0, 12.0, 1.0, 1.0), LOCK_DARK)
	draw_rect(Rect2(7.0, 12.0, 1.0, 2.0), LOCK_DARK)
	draw_rect(Rect2(5.0, 12.0, 1.0, 1.0), LOCK_LIGHT)
	draw_rect(Rect2(5.0, 13.0, 2.0, 1.0), LOCK_DARK)
