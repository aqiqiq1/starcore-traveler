class_name EchoAmuletProjection
extends Node2D

## Level-03 cinematic only: the echo is projected out of the player's real chest
## talisman instead of glowing at the feet.
##
## Approved spec (docs/INTERACTION_PROJECTION_20261117.md, 工程C):
##   - origin = `VisualRoot/Talisman` Sprite2D global transform * get_rect()
##     centre, so facing mirror and every animation anchor are included;
##   - if that node (or its rect) is missing, push an explicit error and abort
##     this effect. There is deliberately no feet/offset fallback;
##   - 0.90 s beat: 0-0.10 talisman glint, 0.10-0.26 one-pixel stepped beam to
##     the imaging area, 0.26-0.38 thin rim + low-alpha original echo,
##     0.38-0.70 bottom-up scan with four limited alpha levels, 0.70-0.90 hold;
##   - DIALOGUE keeps a low-alpha link and the talisman node keeps pulsing;
##   - everything is drawn at integer pixels with the existing low-saturation
##     cyan. No large halo, no full-screen flash, no new audio, and no shader or
##     material is introduced, so `stop()` leaves nothing behind.
##
## The node draws in world space (child of the cinematic) so the beam stays on
## the real chest while the film camera moves. Frame animation of the echo keeps
## running under L3Cinematic; this module only reads its role sprite.

const BEAT_GLINT_END: float = 0.10
const BEAT_BEAM_END: float = 0.26
const BEAT_OUTLINE_END: float = 0.38
const BEAT_SCAN_END: float = 0.70
const BEAT_HOLD_END: float = 0.90

## Imaging area, measured from the chest centre: forward of the body (mirrored
## with facing) and above it, so the 48x64 echo keeps >=4 px from the torso and
## the bubble still fits above it.
const SIDE_OFFSET: float = 36.0
const LIFT: float = 30.0

const BEAM_COLOR: Color = Color(0.46, 0.78, 0.80)
const RIM_COLOR: Color = Color(0.46, 0.78, 0.80)
const GLINT_CYAN: Color = Color(0.37, 0.88, 0.90)
const GLINT_GOLD: Color = Color(0.96, 0.80, 0.39)
const ECHO_LOW_ALPHA: float = 0.22
const ECHO_FULL_ALPHA: float = 0.86

enum Beat { IDLE, GLINT, BEAM, OUTLINE, SCAN, HOLD, LINK, FAILED }

var _player: Node2D = null
var _echo: Sprite2D = null
var _talisman: Sprite2D = null
var _beat: Beat = Beat.IDLE
var _t: float = 0.0
var _link_time: float = 0.0
var _echo_visible: bool = false
var _echo_alpha: float = 0.0
var _failed: bool = false
var _art_local: Rect2 = Rect2()
var _art_ready: bool = false
var _beam_points: int = 0


func _ready() -> void:
	# The film clock is driven by L3Cinematic (pausable process); this node only
	# redraws when asked, so a paused tree freezes it with no timer of its own.
	set_process(false)
	visible = false


func setup(player: Node2D, echo: Sprite2D) -> void:
	_player = player
	_echo = echo
	_art_ready = false
	_art_local = Rect2()


## Resolve the real talisman and start the beat clock. Returns false when the
## effect had to be aborted because the chest origin does not exist.
func start() -> bool:
	_failed = false
	_t = 0.0
	_link_time = 0.0
	_echo_visible = false
	_echo_alpha = 0.0
	_beam_points = 0
	_talisman = null
	if _player != null and is_instance_valid(_player):
		_talisman = _player.get_node_or_null("VisualRoot/Talisman") as Sprite2D
	if _talisman == null:
		return _fail("node VisualRoot/Talisman not found")
	if _talisman.get_rect().size == Vector2.ZERO:
		return _fail("VisualRoot/Talisman has an empty rect")
	_beat = Beat.GLINT
	visible = true
	_compute_echo_art_local()
	queue_redraw()
	return true


func _fail(reason: String) -> bool:
	_beat = Beat.FAILED
	_failed = true
	_echo_visible = false
	_echo_alpha = 0.0
	visible = false
	queue_redraw()
	push_error(
		"EchoAmuletProjection: %s; chest projection aborted (no foot fallback)." % reason
	)
	return false


func stop() -> void:
	_t = 0.0
	_link_time = 0.0
	_beat = Beat.IDLE
	_echo_visible = false
	_echo_alpha = 0.0
	_beam_points = 0
	visible = false
	if _echo != null and is_instance_valid(_echo):
		_echo.modulate = Color.WHITE
	queue_redraw()


func has_origin() -> bool:
	return _talisman != null and is_instance_valid(_talisman)


func is_failed() -> bool:
	return _failed


func get_origin_world() -> Vector2:
	if not has_origin():
		return Vector2.ZERO
	return _talisman.get_global_transform() * _talisman.get_rect().get_center()


func get_origin_screen() -> Vector2:
	if not has_origin():
		return Vector2.ZERO
	return _talisman.get_global_transform_with_canvas() * _talisman.get_rect().get_center()


## The real 5x5 talisman rect in world/screen space (the glint is drawn exactly
## over these pixels, not on a rounded copy of the centre).
func get_talisman_world_rect() -> Rect2:
	if not has_origin():
		return Rect2()
	return _talisman.get_global_transform() * _talisman.get_rect()


func get_talisman_screen_rect() -> Rect2:
	if not has_origin() or not _talisman.is_inside_tree():
		return Rect2()
	return _talisman.get_global_transform_with_canvas() * _talisman.get_rect()


## Move the echo so its visible art is centred forward/above the real chest.
## Called by the cinematic after any camera or body change.
func place_echo() -> void:
	if _echo == null or not is_instance_valid(_echo):
		return
	if not has_origin():
		_echo.visible = false
		return
	if not _art_ready:
		_compute_echo_art_local()
	var facing: int = 1
	if _player != null and _player.has_method("get_facing"):
		facing = int(_player.call("get_facing"))
		if facing == 0:
			facing = 1
	var art_center: Vector2 = get_origin_world() + Vector2(float(facing) * SIDE_OFFSET, -LIFT)
	_echo.global_position = art_center - _art_local.get_center()
	# The inherited transform is a pure translation (added under the cinematic),
	# so the art centre above is exact for this sprite.


func is_echo_visible() -> bool:
	return _echo_visible and not _failed


func get_echo_alpha() -> float:
	return _echo_alpha


func has_art() -> bool:
	return _art_ready and _echo != null and is_instance_valid(_echo)


## Visible echo pixels in viewport coordinates (the sprite's real alpha bounding
## box, not the 48x64 frame with its transparent margins). The bubble avoids
## this rect so it cannot sit on the sprite.
func get_echo_art_screen_rect() -> Rect2:
	if not has_art() or not _echo.is_inside_tree():
		return Rect2()
	return _echo.get_global_transform_with_canvas() * _art_local


func get_echo_art_world_rect() -> Rect2:
	if not has_art():
		return Rect2()
	return _echo.get_global_transform() * _art_local


func set_time(t: float) -> void:
	if _failed:
		return
	_t = clampf(t, 0.0, BEAT_HOLD_END)
	_beat = _beat_at(_t)
	_echo_visible = not _failed and _t >= BEAT_BEAM_END
	_echo_alpha = _alpha_at(_t)
	queue_redraw()


## DIALOGUE: keep only the low-alpha link and the quiet talisman node.
func enter_link() -> void:
	if _failed or not has_origin():
		return
	_beat = Beat.LINK
	_t = BEAT_HOLD_END
	_link_time = 0.0
	_echo_visible = true
	_echo_alpha = ECHO_FULL_ALPHA
	visible = true
	queue_redraw()


func set_link_time(t: float) -> void:
	_link_time = t
	if _beat == Beat.LINK:
		queue_redraw()


func get_beat_name() -> String:
	match _beat:
		Beat.GLINT:
			return "GLINT"
		Beat.BEAM:
			return "BEAM"
		Beat.OUTLINE:
			return "OUTLINE"
		Beat.SCAN:
			return "SCAN"
		Beat.HOLD:
			return "HOLD"
		Beat.LINK:
			return "LINK"
		Beat.FAILED:
			return "FAILED"
		_:
			return "IDLE"


func get_beam_point_count() -> int:
	return _beam_points


func get_debug_state() -> Dictionary:
	return {
		"beat": get_beat_name(),
		"time": _t,
		"origin_world": get_origin_world(),
		"origin_screen": get_origin_screen(),
		"echo_art_world": get_echo_art_world_rect(),
		"echo_alpha": _echo_alpha,
		"echo_visible": _echo_visible,
		"beam_px": _beam_points,
		"failed": _failed,
		"echo_has_material": _echo != null and _echo.material != null,
	}


func _beat_at(t: float) -> Beat:
	if t < BEAT_GLINT_END:
		return Beat.GLINT
	if t < BEAT_BEAM_END:
		return Beat.BEAM
	if t < BEAT_OUTLINE_END:
		return Beat.OUTLINE
	if t < BEAT_SCAN_END:
		return Beat.SCAN
	return Beat.HOLD


func _alpha_at(t: float) -> float:
	if t < BEAT_BEAM_END:
		return 0.0
	if t < BEAT_OUTLINE_END:
		return ECHO_LOW_ALPHA
	if t < BEAT_SCAN_END:
		# Four limited levels as the scan passes, not a smooth generic fade.
		var p: float = (t - BEAT_OUTLINE_END) / (BEAT_SCAN_END - BEAT_OUTLINE_END)
		var level: int = clampi(int(ceil(p * 4.0)), 1, 4)
		return lerpf(ECHO_LOW_ALPHA, ECHO_FULL_ALPHA, float(level) / 4.0)
	return ECHO_FULL_ALPHA


func _node_color() -> Color:
	if _player != null and _player.has_method("is_positive") and bool(_player.call("is_positive")):
		return GLINT_GOLD
	return GLINT_CYAN


func _facing() -> int:
	if _player != null and _player.has_method("get_facing"):
		var facing: int = int(_player.call("get_facing"))
		if facing != 0:
			return facing
	return 1


## Per-frame art bounding box of the echo sheet (union of all frames), cached.
## The 288x64 sheet is 6 frames of 48x64 with transparent margins; the visible
## pixels are what the rim, the beam target and the bubble must use.
func _compute_echo_art_local() -> void:
	_art_ready = false
	if _echo == null or not is_instance_valid(_echo):
		return
	var frame_rect: Rect2 = _echo.get_rect()
	_art_local = frame_rect
	_art_ready = true
	var texture: Texture2D = _echo.texture
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	var hframes: int = maxi(_echo.hframes, 1)
	var vframes: int = maxi(_echo.vframes, 1)
	var frame_w: int = maxi(int(texture.get_width()) / hframes, 1)
	var frame_h: int = maxi(int(texture.get_height()) / vframes, 1)
	var min_x: int = frame_w
	var min_y: int = frame_h
	var max_x: int = -1
	var max_y: int = -1
	for fy: int in range(vframes):
		for fx: int in range(hframes):
			var base: Vector2i = Vector2i(fx * frame_w, fy * frame_h)
			for y: int in range(frame_h):
				for x: int in range(frame_w):
					if image.get_pixel(base.x + x, base.y + y).a > 0.0:
						min_x = mini(min_x, x)
						min_y = mini(min_y, y)
						max_x = maxi(max_x, x)
						max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return
	_art_local = Rect2(
		frame_rect.position + Vector2(float(min_x), float(min_y)),
		Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1))
	)


func _draw() -> void:
	_beam_points = 0
	if _failed or _beat == Beat.IDLE or not has_origin():
		return
	var chest: Vector2 = get_origin_world()
	var t: float = _t
	match _beat:
		Beat.GLINT:
			var grow: float = clampf(t / BEAT_GLINT_END, 0.0, 1.0)
			_draw_glint(grow)
		Beat.BEAM:
			_draw_glint(1.0)
			var p: float = clampf(
				(t - BEAT_GLINT_END) / (BEAT_BEAM_END - BEAT_GLINT_END), 0.0, 1.0
			)
			_draw_beam(chest, p, BEAM_COLOR, 0.75)
		Beat.OUTLINE:
			_draw_glint(0.8)
			_draw_beam(chest, 1.0, BEAM_COLOR, 0.52)
			_draw_rim(0.30)
		Beat.SCAN:
			_draw_glint(0.72)
			_draw_beam(chest, 1.0, BEAM_COLOR, 0.46)
			_draw_rim(0.34)
			var p: float = clampf(
				(t - BEAT_OUTLINE_END) / (BEAT_SCAN_END - BEAT_OUTLINE_END), 0.0, 1.0
			)
			_draw_scan_line(p)
		Beat.HOLD:
			_draw_glint(0.58)
			_draw_beam(chest, 1.0, BEAM_COLOR, 0.30)
			_draw_rim(0.18)
		Beat.LINK:
			var pulse: float = 0.42 + 0.18 * (0.5 + 0.5 * sin(_link_time * TAU))
			_draw_glint(pulse)
			_draw_beam(chest, 1.0, BEAM_COLOR, 0.20)


func _draw_glint(intensity: float) -> void:
	var tint: Color = _node_color()
	var art: Rect2 = get_talisman_world_rect()
	if art.size == Vector2.ZERO:
		# No rect means start() already aborted; never draw at a guessed point.
		return
	# Snap to the real sprite pixels so the 5x5 gem itself is what lights up.
	var x: int = roundi(art.position.x)
	var y: int = roundi(art.position.y)
	var w: int = maxi(roundi(art.size.x), 1)
	var h: int = maxi(roundi(art.size.y), 1)
	draw_rect(Rect2(x, y, w, h), Color(tint.r, tint.g, tint.b, 0.34 * intensity))
	var cx: int = x + w / 2
	var cy: int = y + h / 2
	draw_rect(Rect2(x + 1, cy, w - 2, 1), Color(tint.r, tint.g, tint.b, 0.70 * intensity))
	draw_rect(Rect2(cx, y + 1, 1, h - 2), Color(tint.r, tint.g, tint.b, 0.70 * intensity))
	draw_rect(Rect2(cx, cy, 1, 1), Color(0.96, 1.0, 1.0, 0.86 * intensity))


func _draw_beam(chest: Vector2, progress: float, color: Color, alpha: float) -> void:
	var art: Rect2 = get_echo_art_world_rect()
	if art.size == Vector2.ZERO:
		return
	var facing: int = _facing()
	var inner_x: float = art.position.x + 2.0 if facing > 0 else art.end.x - 2.0
	var target: Vector2 = Vector2(inner_x, art.end.y - 4.0)
	var points: Array[Vector2i] = _line_pixels(chest, target)
	_beam_points = points.size() if progress >= 0.999 else int(ceil(float(points.size()) * progress))
	var shown: int = clampi(_beam_points, 0, points.size())
	var color_use: Color = Color(color.r, color.g, color.b, alpha)
	for i: int in range(shown):
		var p: Vector2i = points[i]
		draw_rect(Rect2(p.x, p.y, 1, 1), color_use)


func _draw_rim(alpha: float) -> void:
	var art: Rect2 = get_echo_art_world_rect()
	if art.size == Vector2.ZERO:
		return
	var x: int = roundi(art.position.x)
	var y: int = roundi(art.position.y)
	var w: int = maxi(roundi(art.size.x), 1)
	var h: int = maxi(roundi(art.size.y), 1)
	var color: Color = Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, alpha)
	draw_rect(Rect2(x, y, w, 1), color)
	draw_rect(Rect2(x, y + h - 1, w, 1), color)
	draw_rect(Rect2(x, y, 1, h), color)
	draw_rect(Rect2(x + w - 1, y, 1, h), color)


## The scan band travels bottom to top inside the real art rect, one pixel.
func _draw_scan_line(progress: float) -> void:
	var art: Rect2 = get_echo_art_world_rect()
	if art.size == Vector2.ZERO:
		return
	var x: int = roundi(art.position.x)
	var w: int = maxi(roundi(art.size.x), 1)
	var top: int = roundi(art.position.y)
	var bottom: int = top + maxi(roundi(art.size.y), 1) - 1
	var y: int = bottom - int(round(float(bottom - top) * clampf(progress, 0.0, 1.0)))
	draw_rect(Rect2(x, y, w, 1), Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, 0.55))
	if y - 1 >= top:
		draw_rect(Rect2(x, y - 1, w, 1), Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, 0.18))


## Integer-pixel Bresenham line: a 1 px thick staircase between the real chest
## centre and the imaging area, never an anti-aliased diagonal.
func _line_pixels(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var x0: int = roundi(from.x)
	var y0: int = roundi(from.y)
	var x1: int = roundi(to.x)
	var y1: int = roundi(to.y)
	var points: Array[Vector2i] = []
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points
