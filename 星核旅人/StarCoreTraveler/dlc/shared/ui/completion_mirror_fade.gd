class_name CompletionMirrorFade
extends CanvasLayer

## 0.5 s settlement hand-off shared by all six completion pages.
##
## The panel's own 32x32 mirror emblem ripples (three elliptical rings) while
## the whole screen fades to black; the caller's real scene change runs only
## after the last frame is fully black.  This mirrors the entrance language:
## the mirror eats the frame, never a hard cut.
##
## The helper owns no gameplay state.  It is a child of the HUD CanvasLayer and
## removes itself with the HUD on the scene change; if the destination is
## missing, a 1.5 s fallback reveal avoids a permanently black screen.

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const DURATION: float = 0.5
const LAYER_OFFSET: int = 30
const FALLBACK_REVEAL: float = 1.5
const COVER_COLOR: Color = Color(0.003, 0.008, 0.010, 1.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PALE: Color = Color("#bcffff")

var _cover: ColorRect = null
var _ripple: Node2D = null
var _progress: float = 0.0
var _emblem_center: Vector2 = Vector2(492.0, 103.0)
var _callback: Callable = Callable()
var _fired: bool = false
var _tween: Tween = null


class RippleLayer:
	extends Node2D
	var progress: float = 0.0
	var center: Vector2 = Vector2.ZERO

	func _draw() -> void:
		if progress <= 0.0:
			return
		# The emblem is 32 px; rings start at its rim and expand to 3.5x.
		for index: int in range(3):
			var local: float = clampf(progress - float(index) * 0.16, 0.0, 1.0)
			if local <= 0.0 or local >= 1.0:
				continue
			var fade: float = pow(1.0 - local, 1.25)
			var radius: float = 15.0 + 40.0 * local
			var color: Color = Color(PALE, 0.62 * fade) if index == 0 else Color(
				GOLD if index % 2 == 0 else CYAN, 0.42 * fade
			)
			var segments: int = 56
			for step: int in range(segments):
				var angle: float = TAU * float(step) / float(segments)
				var point: Vector2 = center + Vector2(
					round(cos(angle) * radius), round(sin(angle) * radius * 0.92)
				)
				draw_rect(Rect2(point, Vector2.ONE), color)
		# A short inner flare keeps the first 0.12 s from reading as an empty
		# black fade.
		if progress < 0.34:
			var flare: float = 1.0 - progress / 0.34
			draw_rect(
				Rect2(center - Vector2(10.0, 8.0) * flare,
					Vector2(20.0, 16.0) * flare),
				Color(PALE, 0.26 * flare)
			)


## Starts the hand-off.  Returns false when another fade already owns this HUD
## (double click / held Enter); the caller then does nothing.
static func play(hud: CanvasLayer, on_black: Callable) -> bool:
	if hud == null or not is_instance_valid(hud):
		return false
	if hud.get_node_or_null("CompletionMirrorFade") != null:
		return false
	var fade: CompletionMirrorFade = CompletionMirrorFade.new()
	fade.name = "CompletionMirrorFade"
	fade._callback = on_black
	hud.add_child(fade)
	return true


func _ready() -> void:
	var host: CanvasLayer = get_parent() as CanvasLayer
	layer = (host.layer if host != null else 10) + LAYER_OFFSET
	process_mode = Node.PROCESS_MODE_ALWAYS
	_emblem_center = _resolve_emblem_center(host)
	_cover = ColorRect.new()
	_cover.name = "Black"
	_cover.position = Vector2.ZERO
	_cover.size = VIEW_SIZE
	_cover.color = Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, 0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	_ripple = RippleLayer.new()
	_ripple.name = "Ripple"
	(_ripple as RippleLayer).center = _emblem_center
	add_child(_ripple)
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_progress, 0.0, 1.0, DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_on_reached_black)
	# Missing destination fallback: reveal the old page instead of freezing on
	# black.  A real scene change frees this node long before it runs.
	_tween.tween_interval(FALLBACK_REVEAL)
	_tween.tween_callback(_fallback_reveal)


func _resolve_emblem_center(host: CanvasLayer) -> Vector2:
	if host == null:
		return _emblem_center
	var emblem: Control = host.find_child("CompletionEmblem", true, false) as Control
	if emblem == null:
		return _emblem_center
	return emblem.get_global_rect().get_center()


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _cover != null:
		# Most of the fade happens early, so the ripple stays readable on the
		# darkening panel instead of being swallowed at once.
		_cover.color.a = pow(_progress, 1.35)
	if _ripple != null:
		(_ripple as RippleLayer).progress = _progress
		_ripple.queue_redraw()


func _on_reached_black() -> void:
	if _fired:
		return
	_fired = true
	if _cover != null:
		_cover.color.a = 1.0
	if _callback.is_valid():
		_callback.call()


func _fallback_reveal() -> void:
	if not is_inside_tree():
		return
	var reveal: Tween = create_tween()
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(_cover, "color:a", 0.0, 0.25)
	reveal.tween_callback(queue_free)


func get_progress() -> float:
	return _progress


func get_cover_alpha() -> float:
	return _cover.color.a if _cover != null else 0.0


func get_emblem_center() -> Vector2:
	return _emblem_center


func has_fired() -> bool:
	return _fired
