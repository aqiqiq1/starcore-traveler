class_name MirrorBlackCover
extends CanvasLayer

## One-shot full-screen black cover used when a scene is entered through the
## double mirror.  It is added during the destination's _ready, so the first
## rendered frame is exactly black (matching the title's 开始游戏 hand-off),
## then it fades away over 0.55 s and frees itself.
##
## It owns no gameplay state and never pauses the tree.

const COVER_COLOR: Color = Color(0.003, 0.008, 0.010, 1.0)
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
## Short opaque hold: the destination's first rendered frames are black
## even when a slow scene load skips a couple of ticks.
const DEFAULT_HOLD: float = 0.22
const DEFAULT_FADE: float = 0.55
const LAYER: int = 20

var _cover: ColorRect = null
var _hold: float = DEFAULT_HOLD
var _fade: float = DEFAULT_FADE


static func attach(parent: Node, hold: float = DEFAULT_HOLD,
		fade: float = DEFAULT_FADE) -> MirrorBlackCover:
	if parent == null:
		return null
	var cover: MirrorBlackCover = MirrorBlackCover.new()
	cover.name = "MirrorBlackCover"
	cover._hold = maxf(hold, 0.0)
	cover._fade = maxf(fade, 0.01)
	parent.add_child(cover)
	return cover


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.name = "Black"
	_cover.position = Vector2.ZERO
	_cover.size = VIEW_SIZE
	_cover.color = COVER_COLOR
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _hold > 0.0:
		tween.tween_interval(_hold)
	tween.tween_property(_cover, "color:a", 0.0, _fade).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func get_alpha() -> float:
	if _cover == null:
		return 0.0
	return _cover.color.a


func is_covering() -> bool:
	return _cover != null and _cover.color.a > 0.999


func get_fade_time() -> float:
	return _fade
