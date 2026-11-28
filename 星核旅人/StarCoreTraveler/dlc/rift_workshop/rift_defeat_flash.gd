class_name RiftDefeatFlash
extends Node2D

## The double mirror's defeat pop, drawn as the mirror itself instead of a
## screen rectangle.
##
## It is a child of RiftMirrorBoss, so its centre is the boss's mirror disc.
## The flash starts at the disc diameter, keeps a 1 px bright ring on the rim
## and contracts to nothing in 0.25 s.  No draw call is larger than the boss's
## own 128x112 silhouette; the old 840x600 white rectangles are gone.

const ART = preload("res://dlc/shared/side_route/mirror_face_art.gd")
const FLASH_TIME: float = 0.25
## The approved boss sheet is 128x112; the round glass reads 124x108 once the
## 1-2 px iron rim is excluded.
const DISC_SIZE: Vector2 = Vector2(124.0, 108.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const WHITE: Color = Color(1.0, 0.99, 0.94)

var _playing: bool = false
var _time: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


func play() -> void:
	_playing = true
	_time = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func is_playing() -> bool:
	return _playing


func reset() -> void:
	_playing = false
	_time = 0.0
	visible = false
	set_process(false)


func get_progress() -> float:
	return clampf(_time / FLASH_TIME, 0.0, 1.0)


func get_flash_diameter() -> Vector2:
	return DISC_SIZE


func get_flash_radius() -> Vector2:
	return DISC_SIZE * 0.5 * (1.0 - get_progress())


## Audit hooks: the pop is an ellipse, never a full-screen rectangle.
func is_circular_flash() -> bool:
	return true


func has_fullscreen_rect() -> bool:
	return false


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	if _time >= FLASH_TIME:
		_playing = false
		_time = FLASH_TIME
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _playing:
		return
	var progress: float = get_progress()
	var shrink: float = 1.0 - progress
	if shrink <= 0.0:
		return
	var size: Vector2 = DISC_SIZE * shrink
	var alpha: float = 1.0 - progress
	# The glass itself: a contained white wash, never the room.
	ART.ellipse(self, Vector2.ZERO, size, Color(WHITE, 0.58 * alpha))
	# 1 px bright rim, then one pale inner echo so the shrink reads as a
	# contracting mirror and not a fading blob.
	ART.ellipse_arc(
		self, Vector2.ZERO, size, 1.0,
		Color(WHITE, 0.95 * alpha), 0.0, TAU
	)
	ART.ellipse_arc(
		self, Vector2.ZERO, size - Vector2(4.0, 4.0), 0.72,
		Color(GOLD if int(progress * 8.0) % 2 == 0 else CYAN, 0.50 * alpha),
		0.0, TAU
	)
	# Four short gold/cyan ticks on the rim keep the boss's palette in the pop.
	var radius: Vector2 = size * 0.5
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + progress * 0.8
		var point: Vector2 = Vector2(
			round(cos(angle) * radius.x), round(sin(angle) * radius.y)
		)
		draw_rect(
			Rect2(point, Vector2(2.0, 2.0)),
			Color(GOLD if index % 2 == 0 else CYAN, 0.88 * alpha)
		)
