class_name MirrorRiftGate
extends HiddenRouteGate

## Optional 裂隙工坊 entrance in DLC3 星核织机, standing in the hall between
## the recorded checkpoint and the boss arena trigger.
##
## The entrance is now the boss itself, in miniature: a 40x64 free-standing
## double-faced mirror built from the chapter's approved boss art.  The gold
## and cyan 48x48 face plates are pasted 1:1 (outer 20x46 px of each) into a
## dark iron frame, with one large gold/cyan eye at the centre.  No new PNG is
## drawn for the entrance.
##
## Behaviour:
##   - inside 56 px the base class shows the one-shot approach line;
##   - E starts a 0.35 s walk into the mirror centre with an elliptical ripple;
##   - the screen fades to black over 0.8 s;
##   - only at full black does the real scene change happen, and the side
##     chapter opens with its own black cover on the first frame.
##
## The gate owns no collision and never blocks the route.  When idle it stays
## behind the checkpoint marker (z=1); only during the 1.15 s entry does it
## rise above the player so the body really disappears into the glass.

const ART = preload("res://dlc/shared/side_route/mirror_face_art.gd")

const WALK_TIME: float = 0.35
const FADE_TIME: float = 0.80
const RIPPLE_TIME: float = 0.35
const COVER_COLOR: Color = Color(0.003, 0.008, 0.010, 1.0)
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
## 40 x 64 footprint: x -20..20, y -64..0 at the floor.
const HEAD_CENTER: Vector2 = Vector2(0.0, -38.0)
const HEAD_SIZE: Vector2 = Vector2(32.0, 48.0)
const PLATE_CENTER_Y: float = -38.0
const EYE_SIZE: Vector2 = Vector2(18.0, 12.0)
const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const PALE: Color = Color("#bcffff")
const IRON: Color = Color("#343c40")
const IRON_DARK: Color = Color("#161e22")
const INK: Color = Color("#0a1218")

var _time: float = 0.0
var _ripple: float = -1.0
var _cover_layer: CanvasLayer = null
var _cover: ColorRect = null
var _walk_tween: Tween = null
var _fade_tween: Tween = null
var _walk_start: Vector2 = Vector2.ZERO
var _walk_target: Vector2 = Vector2.ZERO
var depth_strength: float = 0.0
var _player_physics_was_on: bool = false
var _saved_z: int = 1
var _walk_anim_driven: bool = false


func _build_visual() -> void:
	# Art is drawn directly by this node; no child sprites means the plates,
	# eye and ripple keep one deterministic paint order.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	super._ready()
	z_index = 1
	_saved_z = z_index
	_build_cover()


func _build_cover() -> void:
	_cover_layer = CanvasLayer.new()
	_cover_layer.name = "MirrorEntryCover"
	_cover_layer.layer = 100
	add_child(_cover_layer)
	_cover = ColorRect.new()
	_cover.name = "Black"
	_cover.position = Vector2.ZERO
	_cover.size = VIEW_SIZE
	_cover.color = Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, 0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.visible = false
	_cover_layer.add_child(_cover)


func _process(delta: float) -> void:
	if get_tree() != null and get_tree().paused and not _entering:
		return
	_time += delta
	# The player's own _physics_process is off for the scripted move, so drive
	# its walk cycle here instead of sliding an idle pose into the glass.
	if _walk_anim_driven and _player != null and is_instance_valid(_player) \
			and _player.visible and _player.has_method("_update_animation"):
		_player.call("_update_animation", delta)
	if _ripple >= 0.0:
		_ripple = minf(_ripple + delta / RIPPLE_TIME, 1.0)
		if _ripple >= 1.0:
			_ripple = -1.0
	queue_redraw()


func set_depth_strength(value: float) -> void:
	depth_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func get_depth_strength() -> float:
	return depth_strength


func get_walk_time() -> float:
	return WALK_TIME


func get_fade_time() -> float:
	return FADE_TIME


## Footprint of the free-standing mirror: 40 px wide, 64 px tall from the floor.
func get_mirror_size() -> Vector2:
	return Vector2(
		ART.PLATE_REGION_SIZE.x * 2.0,
		HEAD_SIZE.y + 16.0
	)


func get_cover_alpha() -> float:
	if _cover == null or not _cover.visible:
		return 0.0
	return _cover.color.a


## Called by the origin chapter when the player returns from the side route:
## the checkpoint they reappear on is right beside the mirror, so the same
## elliptical ripple runs once as a "stepping out of the glass" beat.
func play_emerge_ripple() -> void:
	_ripple = 0.0
	queue_redraw()


func is_ripple_active() -> bool:
	return _ripple >= 0.0


## Test/capture hook: the entry is one world-local walk, not a screen shove.
func get_walk_target() -> Vector2:
	return _walk_target


func is_entry_transition_active() -> bool:
	return _entering and (_walk_tween != null or _fade_tween != null)


func _start_enter_presentation() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	_saved_z = z_index
	z_index = 7
	# Keep the ripple and the scripted walk alive even if Esc pauses the tree;
	# the real scene change unpauses it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ripple = 0.0
	_walk_start = _player.global_position
	_walk_target = Vector2(global_position.x, _player.global_position.y)
	_player_physics_was_on = _player.is_physics_processing()
	_player.set_physics_process(false)
	if _player.has_method("clear_input_buffers"):
		_player.call("clear_input_buffers")
	if _player.has_method("clear_external_force"):
		_player.call("clear_external_force")
	if _player.has_method("face_direction"):
		_player.call("face_direction", 1 if global_position.x >= _walk_start.x else -1)
	if _player.has_method("_apply_animation"):
		_player.call("_apply_animation", &"walk", true)
		_walk_anim_driven = true
	if _player.has_method("set_velocity"):
		_player.call("set_velocity", Vector2.ZERO)
	else:
		_player.set("velocity", Vector2.ZERO)
	_walk_tween = create_tween()
	_walk_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_walk_tween.tween_property(
		_player, "global_position", _walk_target, WALK_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.tween_callback(_on_walk_finished)
	return true


func _on_walk_finished() -> void:
	_walk_anim_driven = false
	if _player != null and is_instance_valid(_player):
		# The body is inside the glass now; hiding it also removes the
		# polarity badge that would otherwise sit above the raised mirror.
		_player.visible = false
	_start_fade()


func _start_fade() -> void:
	if _cover == null:
		_commit_route()
		return
	_cover.visible = true
	_cover.color = Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, 0.0)
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(
		_cover, "color:a", 1.0, FADE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(_on_fade_finished)


func _on_fade_finished() -> void:
	if _cover != null:
		_cover.color.a = 1.0
	# The destination must open under black on its very first rendered frame.
	SIDE_ROUTE.mark_black_entry(target_id)
	if not _commit_route():
		SIDE_ROUTE.clear_black_entry()
		_restore_after_failed_entry()


## The base class calls this once the real scene change has been accepted.
func _on_route_committed() -> void:
	if _cover != null:
		_cover.visible = true
		_cover.color.a = 1.0


func _restore_after_failed_entry() -> void:
	_walk_anim_driven = false
	if _player != null and is_instance_valid(_player):
		_player.visible = true
		_player.set_physics_process(_player_physics_was_on)
		_player.global_position = _walk_start
		if _player.has_method("_apply_animation"):
			_player.call("_apply_animation", &"idle", true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = _saved_z
	_ripple = -1.0
	if _cover != null:
		_cover.visible = false
		_cover.color.a = 0.0
	_walk_tween = null
	_fade_tween = null


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.6)
	# Floor contact and stand.  The mirror is a free-standing object; the low
	# shadow and two-step foot keep it on the hall floor at y=0.
	draw_rect(Rect2(-18.0, -1.0, 36.0, 1.0), Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(Rect2(-3.0, -14.0, 6.0, 7.0), IRON_DARK)
	draw_rect(Rect2(-2.0, -14.0, 4.0, 6.0), IRON)
	draw_rect(Rect2(-10.0, -8.0, 20.0, 3.0), IRON_DARK)
	draw_rect(Rect2(-9.0, -8.0, 18.0, 1.0), Color(IRON, 1.0).lightened(0.12))
	draw_rect(Rect2(-14.0, -5.0, 28.0, 5.0), IRON_DARK)
	draw_rect(Rect2(-13.0, -5.0, 26.0, 4.0), IRON)
	draw_rect(Rect2(-13.0, -5.0, 26.0, 1.0), Color(IRON, 1.0).lightened(0.18))
	draw_rect(Rect2(-11.0, -2.0, 22.0, 1.0), Color(INK, 0.65))
	# Small crown plate above the ring so the 40x64 silhouette has a top end.
	draw_rect(Rect2(-4.0, -64.0, 8.0, 2.0), IRON_DARK)
	draw_rect(Rect2(-3.0, -64.0, 6.0, 1.0), Color(IRON, 1.0).lightened(0.16))

	# Frame: dark outer edge, cold iron ring, then the dark glass backing that
	# the two approved face plates sit on.
	ART.ellipse(self, HEAD_CENTER, HEAD_SIZE + Vector2(4.0, 4.0), IRON_DARK)
	ART.ellipse(self, HEAD_CENTER, HEAD_SIZE + Vector2(2.0, 2.0), IRON)
	ART.ellipse(self, HEAD_CENTER, HEAD_SIZE, Color("#0d1a1e"))
	# One 1 px cool highlight along the upper-left of the frame and a cut
	# shadow lower-right, the same bevel reading as the Rondo wall mirror.
	ART.ellipse_arc(
		self, HEAD_CENTER, HEAD_SIZE + Vector2(3.0, 3.0), 0.95,
		Color(0.72, 0.82, 0.84, 0.34), -PI * 0.92, -PI * 0.10
	)
	ART.ellipse_arc(
		self, HEAD_CENTER, HEAD_SIZE + Vector2(3.0, 3.0), 0.55,
		Color(0.0, 0.0, 0.0, 0.42), PI * 0.06, PI * 0.94
	)

	# Gold left, cyan right: the outer 20x46 px of each approved 48x48 face,
	# drawn 1:1.  Their inner contours leave the centre for the eye.
	draw_texture_rect_region(
		ART.GOLD_FACE,
		Rect2(-ART.PLATE_REGION_SIZE.x, PLATE_CENTER_Y - ART.PLATE_REGION_SIZE.y * 0.5,
			ART.PLATE_REGION_SIZE.x, ART.PLATE_REGION_SIZE.y),
		ART.GOLD_PLATE_REGION
	)
	draw_texture_rect_region(
		ART.CYAN_FACE,
		Rect2(0.0, PLATE_CENTER_Y - ART.PLATE_REGION_SIZE.y * 0.5,
			ART.PLATE_REGION_SIZE.x, ART.PLATE_REGION_SIZE.y),
		ART.CYAN_PLATE_REGION
	)
	# 1 px seam between the faces, then the inner light ring over the plates.
	draw_rect(
		Rect2(-0.5, PLATE_CENTER_Y - ART.PLATE_REGION_SIZE.y * 0.5 + 2.0,
			1.0, ART.PLATE_REGION_SIZE.y - 4.0),
		Color(INK, 0.55)
	)
	ART.ellipse_arc(
		self, HEAD_CENTER, HEAD_SIZE - Vector2(1.0, 1.0), 0.66,
		Color(PALE, 0.26 + 0.10 * pulse), 0.0, PI
	)

	# The eye: gold/cyan iris split on the same centre line as the plates.
	ART.draw_eye(self, HEAD_CENTER, EYE_SIZE)
	# A pair of static glass glints, clear of the eye.
	draw_rect(Rect2(-13.0, -56.0, 3.0, 1.0), Color(PALE, 0.30))
	draw_rect(Rect2(-12.0, -55.0, 1.0, 1.0), Color(PALE, 0.16))

	# Elliptical ripple from the mirror centre while the body walks in.
	if _ripple >= 0.0:
		_draw_ripple()

	if Engine.is_editor_hint():
		draw_rect(Rect2(-20.0, -64.0, 40.0, 64.0), Color(CYAN, 0.06), true)


func _draw_ripple() -> void:
	for index: int in range(3):
		var progress: float = clampf(_ripple - float(index) * 0.14, 0.0, 1.0)
		if progress <= 0.0 or progress >= 1.0:
			continue
		var fade: float = pow(1.0 - progress, 1.35)
		var rx: float = 17.0 + 15.0 * progress
		var ry: float = 21.0 + 17.0 * progress
		var color: Color = Color(PALE, 0.72 * fade) if index == 0 else Color(
			GOLD if index % 2 == 0 else CYAN, 0.46 * fade
		)
		var segments: int = 44
		for step: int in range(segments):
			var angle: float = TAU * float(step) / float(segments)
			var point: Vector2 = Vector2(
				round(HEAD_CENTER.x + cos(angle) * rx),
				round(HEAD_CENTER.y + sin(angle) * ry)
			)
			draw_rect(Rect2(point, Vector2.ONE), color)
	# A short central flare at the beginning of the ripple.
	if _ripple < 0.45:
		var flare: float = 1.0 - _ripple / 0.45
		ART.ellipse(
			self, HEAD_CENTER, Vector2(10.0, 8.0) * (0.4 + 0.6 * flare),
			Color(PALE, 0.42 * flare)
		)
