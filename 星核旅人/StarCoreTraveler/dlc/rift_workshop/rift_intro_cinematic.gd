class_name RiftIntroCinematic
extends Node2D

## DLC2 裂隙工坊 opening, 2026-11-27 rework.
##
## The film is not a painted screen: every frame is the live chapter.  A real
## Camera2D hangs in the mirror hall on the real RiftMirrorBoss (suspended,
## chains drawn, both face plates dark), the eye/plate-light/phase-wave are
## world-space overlays on that same boss and the real arena floor, and the
## camera then pulls left through the real rooms to the real L3Player standing
## at the chapter start.  Only the dark grade, vignette and skip footer are
## screen-space; they never draw the world.  The held mirror shot has a fixed
## centre and zoom; a pre-open pupil contraction, real 8 fps chain step, one
## rim-light sweep and one post-wave mirror lift carry the motion instead.
##
## Input: F (or the shared tutorial_next action) skips at once; holding Space
## for SKIP_HOLD skips too.  A skip snaps the camera to the player's gameplay
## view in the same frame, so no half-finished pan is left behind.  The chapter
## keeps the player locked and the HUD hidden until `finished` arrives.
##
## The film never starts or stops the chapter's boss BGM.  The chapter ambience
## is already playing and keeps running underneath.

signal finished(skipped: bool)

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const FLOOR_Y: float = 320.0
const ARENA_LEFT: float = 1240.0
const ARENA_RIGHT: float = 1880.0
## Approved window is 4.0-4.6 s.  The last 0.32 s is a settled player view so
## the HUD can begin its fade without a camera step.
##
## Jitter contract: the mirror shot has NO camera drift.  Centre and zoom stay
## bit-for-bit identical until the final pull; the eye, pupil, chain glints,
## rim sweep and mirror flash carry the life instead.  Chain sway and all
## sparkle positions use whole-pixel steps at a quantised clock rate.
const DURATION: float = 4.50
const SKIP_HOLD: float = 0.60
const BOSS_HOLD_END: float = 3.36
const PULL_END: float = 4.18
const EYE_OPEN_START: float = 1.18
const EYE_OPEN_END: float = 1.80
const PUPIL_PRE_START: float = 1.00
const PUPIL_PRE_PEAK: float = 1.09
const PUPIL_PRE_END: float = 1.20
const GOLD_LIT_START: float = 1.48
const CYAN_LIT_START: float = 1.70
const RIM_SWEEP_START: float = 1.68
const RIM_SWEEP_END: float = 2.10
const WAVE_START: float = 2.04
const WAVE_END: float = 2.56
const MIRROR_FLASH_START: float = 2.56
const MIRROR_FLASH_PEAK: float = 2.68
const MIRROR_FLASH_END: float = 2.96
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"
const AUDIO_POOL_SIZE: int = 6

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const INK: Color = Color(0.006, 0.014, 0.018, 1.0)
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DARK_GRADE: Color = Color(0.005, 0.014, 0.018, 1.0)

const EYE_CLOSE_COLOR: Color = Color(0.018, 0.034, 0.040, 1.0)
const SCLERA: Color = Color(0.030, 0.070, 0.080, 1.0)
const PUPIL: Color = Color(0.004, 0.008, 0.010, 1.0)


class EyeLayer:
	extends Node2D
	var host: RiftIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_eye(self)


class PlateLayer:
	extends Node2D
	var host: RiftIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_plate_glow(self)


class WaveLayer:
	extends Node2D
	var host: RiftIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_phase_wave(self)


var _boss: RiftMirrorBoss = null
var _player: L3Player = null
var _player_camera: Camera2D = null
var _hud: RiftWorkshopHUD = null

var _opening_camera: Camera2D = null
var _eye_layer: EyeLayer = null
var _plate_layer: PlateLayer = null
var _wave_layer: WaveLayer = null
var _grade_layer: CanvasLayer = null
var _grade: ColorRect = null
var _vignette: Control = null
var _ui_layer: CanvasLayer = null
var _footer: Control = null
var _hold_bg: ColorRect = null
var _hold_fill: ColorRect = null
var _font: Font = null

var _face_gold: Sprite2D = null
var _face_cyan: Sprite2D = null
var _face_gold_original: Color = Color.WHITE
var _face_cyan_original: Color = Color.WHITE
var _base_sprite: Sprite2D = null
var _base_original: Color = Color.WHITE
var _chain_sway_original: float = 0.0
var _chain_sway_saved: bool = false

var _chain_a: AudioStream = null
var _chain_b: AudioStream = null
var _eye_stream: AudioStream = null
var _heart_stream: AudioStream = null
var _gold_plate_stream: AudioStream = null
var _cyan_plate_stream: AudioStream = null
var _wave_stream: AudioStream = null

var _active: bool = false
var _finished: bool = false
var _finished_emitted: bool = false
var _skipped: bool = false
var _await_release: bool = false
var _skip_count: int = 0
var _time: float = 0.0
var _space_held: bool = false
var _space_time: float = 0.0
var _space_latched: bool = false
var _capture_mode: bool = false

var _gold_lit: float = 0.0
var _cyan_lit: float = 0.0
var _eye_open: float = 0.0
var _wave_progress: float = 0.0
var _rim_sweep: float = 0.0
var _mirror_flash: float = 0.0
var _grade_alpha: float = 1.0

var _played_cues: Dictionary = {}
var _cue_count: int = 0
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_cursor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera()
	_build_world_overlays()
	_build_grade()
	_build_film_ui()
	_set_film_layers_visible(false)
	set_process(false)
	set_process_unhandled_input(false)


func configure(
	boss: RiftMirrorBoss,
	player: L3Player,
	player_camera: Camera2D,
	hud: RiftWorkshopHUD
) -> void:
	_boss = boss
	_player = player
	_player_camera = player_camera
	_hud = hud
	if _player_camera == null and _player != null:
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _boss != null:
		_face_gold = _boss.get_face_sprite(true)
		_face_cyan = _boss.get_face_sprite(false)
		_base_sprite = _boss.get_node_or_null("MirrorBase") as Sprite2D
		if _face_gold != null:
			_face_gold_original = _face_gold.modulate
		if _face_cyan != null:
			_face_cyan_original = _face_cyan.modulate
		if _base_sprite != null:
			_base_original = _base_sprite.modulate


func _build_camera() -> void:
	_opening_camera = Camera2D.new()
	_opening_camera.name = "OpeningCamera2D"
	_opening_camera.enabled = false
	_opening_camera.position_smoothing_enabled = false
	_opening_camera.position_smoothing_speed = 0.0
	_opening_camera.limit_left = 0
	_opening_camera.limit_top = 0
	_opening_camera.limit_right = 1880
	_opening_camera.limit_bottom = 360
	_opening_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(_opening_camera)


func _build_world_overlays() -> void:
	# All three nodes live in world space and are positioned from the real boss
	# and real floor; none is a second copy of the mirror or the room.
	_wave_layer = WaveLayer.new()
	_wave_layer.name = "OpeningPhaseWave"
	_wave_layer.host = self
	_wave_layer.z_index = 4
	_wave_layer.visible = false
	add_child(_wave_layer)

	_plate_layer = PlateLayer.new()
	_plate_layer.name = "OpeningPlateGlow"
	_plate_layer.host = self
	_plate_layer.z_index = 6
	_plate_layer.visible = false
	add_child(_plate_layer)

	_eye_layer = EyeLayer.new()
	_eye_layer.name = "OpeningEye"
	_eye_layer.host = self
	_eye_layer.z_index = 7
	_eye_layer.visible = false
	add_child(_eye_layer)


func _build_grade() -> void:
	_grade_layer = CanvasLayer.new()
	_grade_layer.name = "OpeningGrade"
	_grade_layer.layer = 6
	_grade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_grade_layer)

	_grade = ColorRect.new()
	_grade.name = "DarkGrade"
	_grade.position = Vector2.ZERO
	_grade.size = VIEW_SIZE
	_grade.color = Color(DARK_GRADE, 1.0)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_layer.add_child(_grade)

	_vignette = Control.new()
	_vignette.name = "Vignette"
	_vignette.position = Vector2.ZERO
	_vignette.size = VIEW_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_layer.add_child(_vignette)
	for index: int in range(4):
		var width: float = 14.0 + float(index) * 10.0
		var alpha: float = 0.060 - float(index) * 0.012
		var edge: ColorRect = ColorRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = Color(0.0, 0.0, 0.0, alpha)
		match index:
			0:
				edge.position = Vector2.ZERO
				edge.size = Vector2(VIEW_SIZE.x, width)
			1:
				edge.position = Vector2(0.0, VIEW_SIZE.y - width)
				edge.size = Vector2(VIEW_SIZE.x, width)
			2:
				edge.position = Vector2.ZERO
				edge.size = Vector2(width, VIEW_SIZE.y)
			_:
				edge.position = Vector2(VIEW_SIZE.x - width, 0.0)
				edge.size = Vector2(width, VIEW_SIZE.y)
		_vignette.add_child(edge)


func _build_film_ui() -> void:
	_font = _load_font()
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "OpeningUI"
	_ui_layer.layer = 21
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_footer = Control.new()
	_footer.name = "SkipFooter"
	_footer.position = Vector2.ZERO
	_footer.size = VIEW_SIZE
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.visible = false
	_ui_layer.add_child(_footer)

	_hold_bg = ColorRect.new()
	_hold_bg.name = "HoldBarBG"
	_hold_bg.position = Vector2(420.0, 326.0)
	_hold_bg.size = Vector2(96.0, 4.0)
	_hold_bg.color = Color(0.02, 0.04, 0.05, 0.85)
	_hold_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_bg.visible = false
	_footer.add_child(_hold_bg)

	_hold_fill = ColorRect.new()
	_hold_fill.name = "HoldBarFill"
	_hold_fill.position = Vector2(421.0, 327.0)
	_hold_fill.size = Vector2(0.0, 2.0)
	_hold_fill.color = GOLD
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_fill.visible = false
	_footer.add_child(_hold_fill)

	_add_keycap("F", Rect2(420.0, 334.0, 16.0, 16.0), 12)
	_add_footer_text("跳过", Vector2(440.0, 334.0), 30.0)
	_add_footer_text("·", Vector2(466.0, 334.0), 10.0)
	_add_footer_text("长按", Vector2(478.0, 334.0), 30.0)
	_add_keycap("空格", Rect2(506.0, 334.0, 34.0, 16.0), 12)


func _load_font() -> Font:
	return UiFont.get_font()


func _add_footer_text(text_value: String, position_value: Vector2, width: float) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.position = position_value
	label.size = Vector2(width, 16.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(label)


func _add_keycap(text_value: String, rect: Rect2, font_size: int) -> void:
	var outer: ColorRect = ColorRect.new()
	outer.position = rect.position
	outer.size = rect.size
	outer.color = Color(0.018, 0.032, 0.038, 0.96)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(outer)

	var inner: ColorRect = ColorRect.new()
	inner.position = rect.position + Vector2(1.0, 1.0)
	inner.size = rect.size - Vector2(2.0, 2.0)
	inner.color = Color(0.10, 0.14, 0.15, 0.98)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(inner)

	var label: Label = Label.new()
	label.text = text_value
	label.position = rect.position + Vector2(1.0, 0.0)
	label.size = rect.size - Vector2(2.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(label)


# --- lifecycle --------------------------------------------------------------

func start() -> bool:
	if _active or _await_release or _finished:
		return false
	if _boss == null or not is_instance_valid(_boss):
		_fail_start()
		return false
	if _player == null or not is_instance_valid(_player):
		_fail_start()
		return false
	if _player_camera == null or not is_instance_valid(_player_camera):
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera == null or _opening_camera == null:
		_fail_start()
		return false

	_active = true
	_finished = false
	_finished_emitted = false
	_skipped = false
	_await_release = false
	_skip_count = 0
	_time = 0.0
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_capture_mode = false
	_played_cues.clear()
	_cue_count = 0
	_gold_lit = 0.0
	_cyan_lit = 0.0
	_eye_open = 0.0
	_wave_progress = 0.0
	_rim_sweep = 0.0
	_mirror_flash = 0.0

	if _face_gold == null and _boss != null:
		_face_gold = _boss.get_face_sprite(true)
	if _face_cyan == null and _boss != null:
		_face_cyan = _boss.get_face_sprite(false)
	if _base_sprite == null and _boss != null:
		_base_sprite = _boss.get_node_or_null("MirrorBase") as Sprite2D
		if _base_sprite != null:
			_base_original = _base_sprite.modulate
	if _boss != null and not _chain_sway_saved:
		_chain_sway_original = float(_boss.get("_sway_time"))
		_chain_sway_saved = true
	if _face_gold != null:
		_face_gold_original = Color.WHITE
		_face_gold.modulate = Color(0.18, 0.22, 0.22, 1.0)
	if _face_cyan != null:
		_face_cyan_original = Color.WHITE
		_face_cyan.modulate = Color(0.18, 0.22, 0.22, 1.0)

	# Hand the viewport to the real film camera.  The gameplay camera is disabled
	# rather than merely outranked, so no later smoothing tick can steal a frame.
	_player_camera.enabled = false
	_opening_camera.enabled = true
	_opening_camera.global_position = _boss_view_center()
	_opening_camera.reset_smoothing()
	_opening_camera.make_current()
	# The background is its own CanvasLayer with a camera-follow offset.  Sync it
	# in the same frame as the cut so the first visible frame cannot show the
	# start-room parallax behind the mirror hall.
	_sync_background_parallax(_boss_view_center().x)

	_set_film_layers_visible(true)
	_apply_time(0.0)
	set_process(true)
	set_process_unhandled_input(true)
	return true


func _fail_start() -> void:
	push_warning("RiftIntroCinematic: missing real boss/player/camera; skipping film")
	_finished = true
	_emit_finished.call_deferred()


func _process(delta: float) -> void:
	if _capture_mode or not _active:
		return
	if _await_release:
		_set_hold_bar(false, 0.0)
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_complete_await_release()
		return

	_time += delta
	if _space_held and not _space_latched:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_latched = true
			_request_skip()
			return
	_set_hold_bar(_space_held, clampf(_space_time / SKIP_HOLD, 0.0, 1.0))
	_apply_time(_time)
	_tick_cues()
	if _time >= DURATION:
		_finish_natural()


func _apply_time(value: float) -> void:
	_time = value
	var camera_center: Vector2 = _camera_center_at(value)
	if _opening_camera != null:
		# Snap to whole pixels: the project renders at 1x and the interior must
		# not shimmer while the camera crosses the room seams.
		_opening_camera.global_position = Vector2(
			roundf(camera_center.x), roundf(camera_center.y)
		)

	_eye_open = smoothstep(EYE_OPEN_START, EYE_OPEN_END, value)
	_gold_lit = smoothstep(GOLD_LIT_START, GOLD_LIT_START + 0.24, value)
	_cyan_lit = smoothstep(CYAN_LIT_START, CYAN_LIT_START + 0.26, value)
	_grade_alpha = _grade_alpha_at(value)
	_wave_progress = smoothstep(WAVE_START, WAVE_END, value)
	_rim_sweep = smoothstep(RIM_SWEEP_START, RIM_SWEEP_END, value)
	_mirror_flash = _mirror_flash_at(value)

	if _grade != null:
		_grade.color = Color(DARK_GRADE, _grade_alpha)
	if _vignette != null:
		_vignette.modulate.a = clampf(_grade_alpha * 1.35, 0.0, 1.0)

	if _face_gold != null and is_instance_valid(_face_gold):
		_face_gold.modulate = Color(0.18, 0.22, 0.22, 1.0).lerp(
			_face_gold_original, _gold_lit
		)
	if _face_cyan != null and is_instance_valid(_face_cyan):
		_face_cyan.modulate = Color(0.18, 0.22, 0.22, 1.0).lerp(
			_face_cyan_original, _cyan_lit
		)
	if _base_sprite != null and is_instance_valid(_base_sprite):
		# One subtle surface lift after the phase wave; it never changes the
		# sprite's frame, position or the boss state.
		_base_sprite.modulate = _base_original.lerp(
			Color(_base_original.r * 1.16, _base_original.g * 1.14,
				_base_original.b * 1.08, _base_original.a),
			_mirror_flash
		)
	if _boss != null and is_instance_valid(_boss) and _boss.is_suspended():
		# The boss's own `_draw_chains` uses `_sway_time`; feeding it an
		# 8 fps-quantised clock makes the REAL chain links step 1-2 px.  The
		# boss is suspended, so this cannot start an attack or a sprite orbit.
		_boss.set("_sway_time", floorf(value * 8.0) / 8.0)
		_boss.queue_redraw()

	if _eye_layer != null:
		_eye_layer.visible = _active or _capture_mode
		_eye_layer.queue_redraw()
	if _plate_layer != null:
		_plate_layer.visible = _active or _capture_mode
		_plate_layer.queue_redraw()
	if _wave_layer != null:
		_wave_layer.visible = (_active or _capture_mode) \
			and value >= WAVE_START and value < WAVE_END + 0.16
		_wave_layer.queue_redraw()

	if _footer != null:
		var footer_alpha: float = 0.0
		if value > 0.34 and not _finished:
			footer_alpha = clampf((value - 0.34) / 0.22, 0.0, 1.0)
		_footer.modulate.a = footer_alpha
		_footer.visible = footer_alpha > 0.0


func _camera_center_at(value: float) -> Vector2:
	var gameplay: Vector2 = _gameplay_camera_center()
	if _boss == null:
		return gameplay
	var boss_center: Vector2 = _boss_view_center()
	# Absolutely no drift while the mirror is held.  Any 1 px camera step at
	# this zoom reads as shimmer on the chain links and 1 px plate rings, so
	# the held shot stays fixed until the final pull.
	if value <= BOSS_HOLD_END:
		return boss_center
	var pull: float = smoothstep(BOSS_HOLD_END, PULL_END, value)
	return Vector2(
		lerpf(boss_center.x, gameplay.x, pull),
		lerpf(boss_center.y, gameplay.y, pull)
	)


func _boss_view_center() -> Vector2:
	if _boss == null:
		return Vector2(320.0, 180.0)
	return Vector2(
		clampf(_boss.global_position.x, 320.0, 1560.0),
		180.0
	)


## The exact center the real player camera would use for the current player.
func _gameplay_camera_center() -> Vector2:
	var half: Vector2 = VIEW_SIZE * 0.5
	if _player == null or _player_camera == null:
		return half
	var target: Vector2 = _player.global_position
	return Vector2(
		clampf(target.x, float(_player_camera.limit_left) + half.x,
			float(_player_camera.limit_right) - half.x),
		clampf(target.y, float(_player_camera.limit_top) + half.y,
			float(_player_camera.limit_bottom) - half.y)
	)


func _mirror_flash_at(value: float) -> float:
	if value < MIRROR_FLASH_START or value > MIRROR_FLASH_END:
		return 0.0
	if value < MIRROR_FLASH_PEAK:
		return smoothstep(MIRROR_FLASH_START, MIRROR_FLASH_PEAK, value)
	return 1.0 - smoothstep(
		MIRROR_FLASH_PEAK, MIRROR_FLASH_END, value
	)


func _grade_alpha_at(value: float) -> float:
	# The first beat is dark but never black: the stone wall, the two tall
	# windows and the chains stay readable behind the mirror from frame one.
	# 0.62 is only a grade, not a black backdrop; the camera cut is synced with
	# the background parallax above.
	if value < 0.30:
		return lerpf(0.62, 0.50, smoothstep(0.0, 0.30, value))
	if value < EYE_OPEN_START:
		return 0.50
	if value < WAVE_START:
		return lerpf(0.50, 0.24,
			smoothstep(EYE_OPEN_START, WAVE_START, value))
	if value < MIRROR_FLASH_END:
		return lerpf(0.24, 0.0,
			smoothstep(WAVE_START, MIRROR_FLASH_END, value))
	# Fully lit for the whole held shot: the grade itself must not change
	# between the two static comparison frames.
	return 0.0


func _finish_natural() -> void:
	if _finished:
		return
	_apply_time(DURATION)
	_ended_state()
	_emit_finished()


func _request_skip() -> void:
	if not _active or _finished:
		return
	_skipped = true
	_skip_count += 1
	_ended_state()
	# Even after the picture has snapped to the player, a held Space is not
	# allowed to become the first jump.  The chapter stays input-locked until
	# the release arrives.
	if _space_held or Input.is_physical_key_pressed(KEY_SPACE):
		_await_release = true
		_space_latched = true
		_footer.visible = false
		set_process_unhandled_input(true)
		return
	_emit_finished()


func _ended_state() -> void:
	_time = minf(_time, DURATION)
	_active = false
	_finished = true
	# Park on the exact gameplay view before the camera is disabled; capture
	# and tests can then read a truthful last film frame.
	if _opening_camera != null:
		_opening_camera.global_position = _gameplay_camera_center()
	if _grade != null:
		_grade.color = Color(DARK_GRADE, 0.0)
	if _vignette != null:
		_vignette.modulate.a = 0.0
	if _eye_layer != null:
		_eye_layer.visible = false
	if _plate_layer != null:
		_plate_layer.visible = false
	if _wave_layer != null:
		_wave_layer.visible = false
	if _footer != null:
		_footer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_boss_looks()
	_stop_audio()
	_restore_player_camera()


func _restore_boss_looks() -> void:
	if _face_gold != null and is_instance_valid(_face_gold):
		_face_gold.modulate = _face_gold_original
	if _face_cyan != null and is_instance_valid(_face_cyan):
		_face_cyan.modulate = _face_cyan_original
	if _base_sprite != null and is_instance_valid(_base_sprite):
		_base_sprite.modulate = _base_original
	if _boss != null and is_instance_valid(_boss) and _chain_sway_saved:
		_boss.set("_sway_time", _chain_sway_original)
		_boss.queue_redraw()
		_chain_sway_saved = false


func _restore_player_camera() -> void:
	if _opening_camera != null:
		_opening_camera.enabled = false
	if _player_camera != null and is_instance_valid(_player_camera) \
			and _player_camera.is_inside_tree():
		_player_camera.enabled = true
		_player_camera.make_current()
		_player_camera.reset_smoothing()
		_sync_background_parallax(_gameplay_camera_center().x)


func _sync_background_parallax(center_x: float) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var background: Node = parent.get_node_or_null("Background")
	if background == null or not background.has_method("_apply"):
		return
	var scroll: float = clampf(center_x - VIEW_SIZE.x * 0.5, 0.0, 1240.0)
	background.call("_apply", scroll)


func _complete_await_release() -> void:
	if not _await_release:
		return
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_emit_finished()


## Pause while the post-skip "wait for Space release" latch is held.  The
## player has already seen the gameplay view, so consume the latch and finish
## the hand-off now.  The chapter's three-tick input override owns the still
## held Space after resume, so it cannot become the first jump.
func handle_pause_opened() -> void:
	if not _await_release:
		return
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_set_hold_bar(false, 0.0)
	_complete_await_release()


## Safety net for a pause path that did not consume the latch on open; do not
## finish while Space is still physically held, or the release would be lost.
func handle_pause_resumed() -> void:
	if not _await_release:
		return
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_set_hold_bar(false, 0.0)
	if not Input.is_physical_key_pressed(KEY_SPACE):
		_complete_await_release()


func _emit_finished() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_active = false
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(_skipped)


func abort() -> void:
	if not _active and not _await_release and not _finished:
		return
	_active = false
	_finished = true
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_capture_mode = false
	_skipped = false
	if _grade != null:
		_grade.color = Color(DARK_GRADE, 0.0)
	if _footer != null:
		_footer.visible = false
	if _eye_layer != null:
		_eye_layer.visible = false
	if _plate_layer != null:
		_plate_layer.visible = false
	if _wave_layer != null:
		_wave_layer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_boss_looks()
	_stop_audio()
	_restore_player_camera()
	set_process(false)
	set_process_unhandled_input(false)


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _capture_mode or not (_active or _await_release):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var code: int = int(key_event.physical_keycode)
	if code == 0:
		code = int(key_event.keycode)

	if _await_release:
		if code == int(KEY_SPACE) and not key_event.pressed:
			_space_held = false
			_complete_await_release()
			get_viewport().set_input_as_handled()
		return

	if key_event.echo:
		get_viewport().set_input_as_handled()
		return

	if key_event.pressed and (
		code == int(KEY_F) or key_event.is_action_pressed(&"tutorial_next")
	):
		_request_skip()
		get_viewport().set_input_as_handled()
		return

	if code != int(KEY_SPACE):
		return
	if key_event.pressed:
		_space_held = true
		_space_time = 0.0
		_space_latched = false
		get_viewport().set_input_as_handled()
	else:
		_space_held = false
		_space_time = 0.0
		_space_latched = false
		_set_hold_bar(false, 0.0)
		get_viewport().set_input_as_handled()


# --- cue bank ---------------------------------------------------------------

func _setup_cues() -> void:
	if _chain_a != null:
		return
	_chain_a = DlcIntroSfx.chain_rustle(1)
	_chain_b = DlcIntroSfx.chain_rustle(4)
	_eye_stream = DlcIntroSfx.mirror_eye()
	_heart_stream = DlcIntroSfx.heartbeat()
	_gold_plate_stream = DlcIntroSfx.plate_on(false)
	_cyan_plate_stream = DlcIntroSfx.plate_on(true)
	_wave_stream = DlcIntroSfx.phase_sweep()


func _tick_cues() -> void:
	if _chain_a == null:
		_setup_cues()
	_play_cue("chain_a", 0.16, _chain_a, -12.0)
	_play_cue("chain_b", 0.62, _chain_b, -13.0)
	_play_cue("eye_open", EYE_OPEN_START + 0.02, _eye_stream, -9.0)
	_play_cue("heart_a", EYE_OPEN_START + 0.18, _heart_stream, -10.0)
	_play_cue("gold_plate", GOLD_LIT_START, _gold_plate_stream, -9.0)
	_play_cue("cyan_plate", CYAN_LIT_START, _cyan_plate_stream, -9.0)
	_play_cue("phase_wave", WAVE_START + 0.02, _wave_stream, -7.0)


func _play_cue(id: String, at_time: float, stream: AudioStream, volume_db: float) -> void:
	if _played_cues.has(id):
		return
	if _time < at_time:
		return
	_played_cues[id] = true
	_cue_count += 1
	if _capture_mode or stream == null:
		return
	_play_stream(stream, volume_db)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	_ensure_audio_pool()
	if _audio_pool.is_empty():
		return
	var player: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in _audio_pool:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _audio_pool[_audio_cursor % _audio_pool.size()]
		_audio_cursor += 1
		player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _ensure_audio_pool() -> void:
	if not _audio_pool.is_empty():
		return
	for index: int in range(AUDIO_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "IntroVoice%d" % (index + 1)
		player.bus = &"Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_audio_pool.append(player)


func _stop_audio() -> void:
	for player: AudioStreamPlayer in _audio_pool:
		if player == null:
			continue
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	_stop_audio()
	_audio_pool.clear()


# --- drawing (world overlays) ----------------------------------------------

func _draw_eye(canvas: Node2D) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var center: Vector2 = canvas.to_local(_boss.get_boss_center())
	var open: float = _eye_open
	if open < 0.02:
		# Closed lid: a dark almond over the real mirror's centre, with the warm
		# seam the boss keeps while asleep.  It is larger than the old thin bar
		# so the first beat reads as an eye, not as a dark slot.
		var closed_half: float = 22.0
		var closed_aperture: float = 8.0
		var closed_top: PackedVector2Array = PackedVector2Array()
		var closed_bottom: PackedVector2Array = PackedVector2Array()
		for index: int in range(17):
			var ratio: float = float(index) / 16.0
			var x: float = center.x - closed_half + ratio * closed_half * 2.0
			var arch: float = sin(ratio * PI)
			closed_top.append(Vector2(x, center.y - closed_aperture * arch))
			closed_bottom.append(Vector2(x, center.y + closed_aperture * arch))
		var closed_lens: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in closed_top:
			closed_lens.append(point)
		for index: int in range(closed_bottom.size() - 1, -1, -1):
			closed_lens.append(closed_bottom[index])
		canvas.draw_colored_polygon(closed_lens, EYE_CLOSE_COLOR)
		canvas.draw_polyline(closed_top, Color(0.12, 0.16, 0.16, 0.90), 1.0)
		canvas.draw_polyline(closed_bottom, Color(0.12, 0.16, 0.16, 0.90), 1.0)
		canvas.draw_line(
			Vector2(center.x - 18.0, center.y),
			Vector2(center.x + 18.0, center.y),
			Color(GOLD, 0.52), 1.0
		)
		canvas.draw_line(
			Vector2(center.x - 22.0, center.y - 5.0),
			Vector2(center.x - 17.0, center.y - 1.0),
			Color(CYAN, 0.28), 1.0
		)
		canvas.draw_line(
			Vector2(center.x + 22.0, center.y - 5.0),
			Vector2(center.x + 17.0, center.y - 1.0),
			Color(GOLD, 0.28), 1.0
		)
		# Pre-open contraction: the seam parts by 2 px and a slit pupil visibly
		# narrows before the lids actually open.  Whole-pixel rects only.
		var pre: float = _preopen_at(_time)
		if pre > 0.001:
			var slit: float = 1.5 + 2.0 * pre
			canvas.draw_rect(
				Rect2(center.x - 12.0, center.y - slit * 0.5 - 1.0,
					24.0, slit + 2.0),
				Color(0.008, 0.016, 0.018, 0.98)
			)
			canvas.draw_rect(
				Rect2(center.x - 10.0, center.y - slit * 0.5, 20.0, slit),
				Color(0.20, 0.34, 0.32, 0.96)
			)
			canvas.draw_rect(
				Rect2(center.x - 9.0, center.y - slit * 0.5, 18.0, 1.0),
				Color(0.46, 0.68, 0.62, 0.90)
			)
			var pupil_w: float = roundf(lerpf(11.0, 3.0, pre))
			canvas.draw_rect(
				Rect2(center.x - pupil_w * 0.5, center.y - slit * 0.5,
					pupil_w, maxf(slit - 1.0, 1.0)),
				Color(0.78, 0.62, 0.24, 0.96)
			)
			canvas.draw_rect(
				Rect2(center.x - 1.0, center.y - slit * 0.5,
					2.0, maxf(slit - 1.0, 1.0)),
				Color(PUPIL, 0.99)
			)
			canvas.draw_rect(
				Rect2(center.x - 12.0, center.y - slit * 0.5 - 1.0, 24.0, 1.0),
				Color(GOLD_PALE, 0.50 * pre)
			)
			canvas.draw_rect(
				Rect2(center.x - 12.0, center.y + slit * 0.5, 24.0, 1.0),
				Color(CYAN_PALE, 0.42 * pre)
			)
		return

	# A faint split gold/cyan halo marks the real mirror's centre as awake.
	canvas.draw_arc(
		center, 24.0, PI, TAU, 18, Color(GOLD, 0.22 * open), 1.0
	)
	canvas.draw_arc(
		center, 24.0, 0.0, PI, 18, Color(CYAN, 0.20 * open), 1.0
	)

	var half_width: float = 21.0
	var aperture: float = 14.0 * open
	var top_points: PackedVector2Array = PackedVector2Array()
	var bottom_points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for index: int in range(segments + 1):
		var ratio: float = float(index) / float(segments)
		var x: float = center.x - half_width + ratio * half_width * 2.0
		var arch: float = sin(ratio * PI)
		top_points.append(Vector2(x, center.y - aperture * arch))
		bottom_points.append(Vector2(x, center.y + aperture * 0.72 * arch))

	var lens: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in top_points:
		lens.append(point)
	for index: int in range(bottom_points.size() - 1, -1, -1):
		lens.append(bottom_points[index])
	canvas.draw_colored_polygon(lens, Color(0.004, 0.010, 0.012, 0.98))

	var sclera: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in top_points:
		sclera.append(center + (point - center) * 0.90)
	for index: int in range(bottom_points.size() - 1, -1, -1):
		sclera.append(center + (bottom_points[index] - center) * 0.90)
	canvas.draw_colored_polygon(sclera, Color(SCLERA, 0.98 * open))

	var iris_radius: float = 8.0 + 2.0 * open
	canvas.draw_circle(center, iris_radius + 1.5, Color(0.01, 0.02, 0.02, 0.96 * open))
	canvas.draw_circle(center, iris_radius, Color(0.87, 0.68, 0.28, 0.98 * open))
	canvas.draw_arc(
		center, iris_radius - 0.5, 0.0, TAU, 20, Color(CYAN, 0.65 * open), 1.0
	)
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0 + 0.12
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (iris_radius * 0.38)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (iris_radius * 0.90)
		canvas.draw_line(inner, outer, Color(0.33, 0.24, 0.09, 0.55 * open), 1.0)

	# The readable beat: as the lid parts the pupil first snaps down (focus),
	# then slowly dilates.  The contraction is the pre-open beat carried into
	# the open eye; it is a radius change only, never a position slide.
	var contract_t: float = smoothstep(1.22, 1.38, _time)
	var dilate_t: float = smoothstep(1.44, 1.96, _time)
	var pupil_radius: float = lerpf(
		lerpf(8.0, 4.0, contract_t), 7.0, dilate_t
	) * open
	canvas.draw_circle(center, pupil_radius, Color(PUPIL, 0.99 * open))
	canvas.draw_circle(
		center + Vector2(-1.5, -1.5), maxf(pupil_radius * 0.32, 0.5),
		Color(0.74, 0.90, 0.88, 0.30 * open)
	)
	canvas.draw_rect(
		Rect2(center.x + 2.0, center.y - 3.0, 1.0, 1.0),
		Color(1.0, 0.98, 0.90, 0.80 * open)
	)

	canvas.draw_polyline(top_points, Color(0.006, 0.014, 0.016, 0.98), 2.0)
	canvas.draw_polyline(bottom_points, Color(0.006, 0.014, 0.016, 0.98), 2.0)
	canvas.draw_polyline(top_points, Color(GOLD, 0.48 * open), 1.0)
	canvas.draw_polyline(bottom_points, Color(CYAN, 0.42 * open), 1.0)


## 0 at the closed lid, 1 at the widest pre-open slit, back to 0 just before
## the real lid-open beat.
func _preopen_at(value: float) -> float:
	if value < PUPIL_PRE_START or value >= PUPIL_PRE_END:
		return 0.0
	if value < PUPIL_PRE_PEAK:
		return smoothstep(PUPIL_PRE_START, PUPIL_PRE_PEAK, value)
	return 1.0 - smoothstep(PUPIL_PRE_PEAK + 0.05, PUPIL_PRE_END, value)


## Peak displacement of the REAL chain links at an 8 fps-quantised clock.
## The boss's `_draw_chains` uses `sin(_sway_time * 1.15 + y * 0.02) * 1.8`, so
## the links step in whole pixels and never exceed 2 px.
func _chain_sway_at(value: float) -> int:
	var step_t: float = floorf(value * 8.0) / 8.0
	return int(round(sin(step_t * 1.15) * 1.8))


func _draw_plate_glow(canvas: Node2D) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	_draw_rim_sweep(canvas)
	_draw_one_plate(canvas, true, _gold_lit, GOLD, GOLD_PALE)
	_draw_one_plate(canvas, false, _cyan_lit, CYAN, CYAN_PALE)
	_draw_mirror_flash(canvas)


func _draw_mirror_flash(canvas: Node2D) -> void:
	if _mirror_flash <= 0.001:
		return
	var center: Vector2 = canvas.to_local(_boss.get_boss_center())
	canvas.draw_arc(
		center, 63.0, 0.0, TAU, 40,
		Color(0.92, 0.96, 0.92, 0.26 * _mirror_flash), 1.0
	)
	canvas.draw_arc(
		center, 67.0, 0.0, TAU, 40,
		Color(GOLD_PALE, 0.12 * _mirror_flash), 1.0
	)


## One 0.42 s comet of light travels once around the real mirror rim while both
## plates come up.  It is an ellipse on the 128x112 silhouette, not a new ring.
func _draw_rim_sweep(canvas: Node2D) -> void:
	if _rim_sweep <= 0.001 or _rim_sweep >= 0.999:
		return
	var center: Vector2 = canvas.to_local(_boss.get_boss_center())
	var tail: float = 0.62
	var segments: int = 18
	var head: float = -PI * 0.5 + TAU * _rim_sweep
	for index: int in range(segments):
		var t0: float = float(index) / float(segments)
		var t1: float = float(index + 1) / float(segments)
		var a0: float = head - tail * t0
		var a1: float = head - tail * t1
		var p0: Vector2 = center + Vector2(cos(a0) * 66.0, sin(a0) * 60.0)
		var p1: Vector2 = center + Vector2(cos(a1) * 66.0, sin(a1) * 60.0)
		var fade: float = 1.0 - t0
		var color: Color = GOLD if sin((a0 + a1) * 0.5) < 0.0 else CYAN
		canvas.draw_line(p0, p1, Color(0.02, 0.03, 0.03, 0.55 * fade), 3.0)
		canvas.draw_line(p0, p1, Color(color, 0.88 * fade), 2.0)
	var lead: Vector2 = center + Vector2(cos(head) * 66.0, sin(head) * 60.0)
	canvas.draw_rect(
		Rect2(roundf(lead.x) - 1.0, roundf(lead.y) - 1.0, 3.0, 3.0),
		Color(0.98, 0.98, 0.90, 0.84)
	)
	canvas.draw_rect(
		Rect2(roundf(lead.x), roundf(lead.y), 1.0, 1.0),
		Color.WHITE
	)


func _draw_one_plate(
	canvas: Node2D,
	positive: bool,
	lit: float,
	color: Color,
	pale: Color
) -> void:
	if lit <= 0.001:
		return
	var center: Vector2 = canvas.to_local(_boss.get_face_center_global(positive))
	# The plate itself is still the boss's own Sprite2D; this is only the light
	# around it.  The two rings sit just outside the 48x48 plate so no pixel of
	# the real face is painted over.
	var step_t: float = floorf(_time * 12.0) / 12.0
	var pulse: float = 0.78 + 0.22 * sin(step_t * 14.0 + (0.0 if positive else 1.3))
	for layer: int in range(2):
		var radius: float = 27.0 + float(layer) * 2.0 + (1.0 - lit) * 8.0
		canvas.draw_arc(
			center, radius, 0.0, TAU, 28,
			Color(color, (0.42 - 0.14 * float(layer)) * lit * pulse), 1.0
		)
	# Four corner brackets make the "plate is awake" state readable at 1x.
	for corner: int in range(4):
		var angle: float = PI * 0.25 + float(corner) * PI * 0.5
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * 23.0
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (28.0 + 2.0 * pulse)
		canvas.draw_line(inner, outer, Color(pale, 0.78 * lit), 1.0)
	# A few short inward rays; they stop before the plate edge.
	for ray: int in range(6):
		var angle: float = TAU * float(ray) / 6.0 + step_t * 0.22
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * 31.0
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * (26.0 + 2.0 * lit)
		canvas.draw_line(start, end, Color(color, 0.33 * lit), 1.0)
	# Link line toward the mirror core: shows the plate feeding the eye.
	var core: Vector2 = canvas.to_local(_boss.get_boss_center())
	var direction: Vector2 = (core - center).normalized()
	var from: Vector2 = center + direction * 27.0
	var to: Vector2 = core - direction * 26.0
	canvas.draw_line(from, to, Color(color, 0.12 * lit), 1.0)
	for dot: int in range(2):
		var q: float = fposmod(step_t * 1.8 + float(dot) * 0.5, 1.0)
		var point: Vector2 = from.lerp(to, q)
		canvas.draw_rect(Rect2(roundf(point.x), roundf(point.y), 1.0, 1.0),
			Color(pale, 0.55 * lit))


func _draw_phase_wave(canvas: Node2D) -> void:
	if _wave_progress <= 0.0:
		return
	var center_x: float = _boss.global_position.x if _boss != null else 1540.0
	var half: float = 26.0 + 340.0 * _wave_progress
	var left: float = maxf(ARENA_LEFT, center_x - half)
	var right: float = minf(ARENA_RIGHT, center_x + half)
	if right <= left:
		return
	var y: float = FLOOR_Y - 1.0
	var fade: float = 1.0 - _wave_progress * 0.30
	canvas.draw_rect(Rect2(left, y, right - left, 2.0), Color(GOLD, 0.92 * fade))
	canvas.draw_rect(Rect2(left, y - 3.0, right - left, 1.0), Color(CYAN, 0.45 * fade))
	canvas.draw_rect(Rect2(left, y + 2.0, right - left, 1.0), Color(GOLD_PALE, 0.24 * fade))
	for index: int in range(26):
		var x: float = left + (right - left) * (float(index) + 0.5) / 26.0
		var rise: float = 3.0 + 5.0 * absf(sin(_wave_progress * PI + float(index) * 0.67))
		canvas.draw_rect(Rect2(x, y - rise, 1.0, rise),
			Color(GOLD if index % 2 == 0 else CYAN, 0.62 * fade))
	# Dust motes lift off the real floor in the wave's path.  The clock is
	# quantised and the positions are rounded so the 1 px dust cannot crawl.
	var step_t: float = floorf(_time * 12.0) / 12.0
	for index: int in range(16):
		var spread: float = (float(index) - 7.5) / 7.5
		var x: float = center_x + spread * (30.0 + 300.0 * _wave_progress)
		var lift: float = fposmod(step_t * 34.0 + float(index) * 17.0, 26.0)
		canvas.draw_rect(Rect2(roundf(x), roundf(y - 2.0 - lift), 1.0, 1.0),
			Color(0.78, 0.92, 0.88, (1.0 - _wave_progress) * 0.50))


# --- visibility / UI helpers ------------------------------------------------

func _set_film_layers_visible(value: bool) -> void:
	if _grade_layer != null:
		_grade_layer.visible = value
	if _ui_layer != null:
		_ui_layer.visible = value
	if not value:
		if _eye_layer != null:
			_eye_layer.visible = false
		if _plate_layer != null:
			_plate_layer.visible = false
		if _wave_layer != null:
			_wave_layer.visible = false


func _set_hold_bar(visible_value: bool, progress: float) -> void:
	if _hold_bg == null or _hold_fill == null:
		return
	_hold_bg.visible = visible_value
	_hold_fill.visible = visible_value
	_hold_fill.size.x = 94.0 * clampf(progress, 0.0, 1.0)


# --- capture helpers --------------------------------------------------------

## Freeze the live scene at an exact beat.  The capture harness owns the chapter
## and calls `finish_capture()` for the control-returned still; this never emits
## `finished` on its own.
func set_time_for_capture(value: float) -> void:
	if _boss == null or _player == null:
		return
	_capture_mode = true
	_active = true
	_finished = false
	_finished_emitted = false
	_skipped = false
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_time = clampf(value, 0.0, DURATION)
	if _face_gold != null:
		_face_gold_original = Color.WHITE
	if _face_cyan != null:
		_face_cyan_original = Color.WHITE
	if _player_camera != null:
		_player_camera.enabled = false
	if _opening_camera != null:
		_opening_camera.enabled = true
		_opening_camera.make_current()
	_set_film_layers_visible(true)
	_apply_time(_time)
	_footer.visible = _time > 0.34
	_footer.modulate.a = 1.0 if _footer.visible else 0.0
	_eye_layer.visible = true
	_plate_layer.visible = true
	_wave_layer.visible = _time >= WAVE_START and _time < WAVE_END + 0.16
	if _vignette != null:
		_vignette.modulate.a = 1.0


func finish_capture() -> void:
	if not _capture_mode:
		return
	_capture_mode = false
	_time = DURATION
	_apply_time(_time)
	_ended_state()
	_emit_finished()


func is_capture_mode() -> bool:
	return _capture_mode


# --- read API (chapter / tests / capture) -----------------------------------

func is_playing() -> bool:
	return _active and not _finished and not _await_release and not _capture_mode


func is_active() -> bool:
	return _active or _await_release


func is_finished() -> bool:
	return _finished


func is_skipped() -> bool:
	return _skipped


func is_awaiting_release() -> bool:
	return _await_release


func get_elapsed() -> float:
	return _time


func get_duration() -> float:
	return DURATION


func get_skip_count() -> int:
	return _skip_count


func get_cue_count() -> int:
	return _cue_count


func has_played_cue(id: String) -> bool:
	return _played_cues.has(id)


func get_space_hold_time() -> float:
	return _space_time


func is_skip_bar_visible() -> bool:
	return _hold_bg != null and _hold_bg.visible


func get_skip_progress() -> float:
	if _hold_fill == null:
		return 0.0
	return _hold_fill.size.x / 94.0


func get_stage_alpha() -> float:
	return 1.0 if _active else 0.0


func get_grade_alpha() -> float:
	return _grade_alpha


func get_eye_open_amount() -> float:
	return _eye_open


func get_gold_lit_amount() -> float:
	return _gold_lit


func get_cyan_lit_amount() -> float:
	return _cyan_lit


func get_wave_progress() -> float:
	return _wave_progress


func get_phase_name() -> String:
	if not _active and not _capture_mode:
		return "DONE"
	if _time < EYE_OPEN_START:
		return "MIRROR_HELD"
	if _time < RIM_SWEEP_START:
		return "EYE_OPEN"
	if _time < WAVE_END:
		return "PHASE_WAVE"
	if _time < PULL_END:
		return "PULL_BACK"
	return "PLAYER_VIEW"


func get_opening_camera() -> Camera2D:
	return _opening_camera


func get_player_camera() -> Camera2D:
	return _player_camera


func get_boss() -> RiftMirrorBoss:
	return _boss


func get_player() -> L3Player:
	return _player


func get_camera_center() -> Vector2:
	if _opening_camera == null:
		return Vector2.ZERO
	return _opening_camera.get_screen_center_position()


func get_camera_zoom() -> float:
	if _opening_camera == null:
		return 1.0
	return _opening_camera.zoom.x


func get_eye_world_position() -> Vector2:
	if _boss == null:
		return Vector2.ZERO
	return _boss.get_boss_center()


func get_face_world_position(positive: bool) -> Vector2:
	if _boss == null:
		return Vector2.ZERO
	return _boss.get_face_center_global(positive)


func get_wave_floor_y() -> float:
	return FLOOR_Y


func get_rim_sweep_amount() -> float:
	return _rim_sweep


func get_rim_sweep_at(value: float) -> float:
	return smoothstep(RIM_SWEEP_START, RIM_SWEEP_END, value)


func get_mirror_flash_amount() -> float:
	return _mirror_flash


func get_mirror_flash_at(value: float) -> float:
	return _mirror_flash_at(value)


func get_chain_sway_offset() -> int:
	return _chain_sway_at(_time)


func get_chain_sway_at(value: float) -> int:
	return _chain_sway_at(value)


func get_preopen_amount() -> float:
	return _preopen_at(_time)


func get_preopen_at(value: float) -> float:
	return _preopen_at(value)


func get_pupil_scale_at(value: float) -> float:
	var contract_t: float = smoothstep(1.22, 1.38, value)
	var dilate_t: float = smoothstep(1.44, 1.96, value)
	return lerpf(lerpf(8.0, 4.0, contract_t), 7.0, dilate_t)


func get_pupil_radius_at(value: float) -> float:
	var open: float = smoothstep(EYE_OPEN_START, EYE_OPEN_END, value)
	return get_pupil_scale_at(value) * open


func get_world_layer_positions() -> Dictionary:
	var result: Dictionary = {}
	if _eye_layer != null:
		result["eye_layer"] = _eye_layer.global_position
	if _plate_layer != null:
		result["plate_layer"] = _plate_layer.global_position
	if _wave_layer != null:
		result["wave_layer"] = _wave_layer.global_position
	if _boss != null:
		result["boss"] = _boss.global_position
		result["eye"] = _boss.get_boss_center()
		result["face_gold"] = _boss.get_face_center_global(true)
		result["face_cyan"] = _boss.get_face_center_global(false)
		result["chain_top_left"] = _boss.global_position + Vector2(-10.0, -254.0)
		result["chain_top_right"] = _boss.global_position + Vector2(10.0, -254.0)
	return result


## Rounded screen anchors for the eye/plates/chains.  The held shot must keep
## this array bit-for-bit identical for 10 consecutive frames.
func get_overlay_anchor_screen_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if _eye_layer == null or _boss == null:
		return points
	var world_points: Array[Vector2] = [
		_boss.get_boss_center(),
		_boss.get_face_center_global(true),
		_boss.get_face_center_global(false),
		_boss.global_position + Vector2(-10.0, -254.0),
		_boss.global_position + Vector2(10.0, -254.0),
		Vector2(_boss.global_position.x, FLOOR_Y),
	]
	var transform: Transform2D = _eye_layer.get_global_transform_with_canvas()
	for world_point: Vector2 in world_points:
		points.append((transform * world_point).round())
	return points


## (held_start, held_end): the camera is bit-for-bit static in this window.
func get_static_hold_span() -> Vector2:
	return Vector2(0.0, BOSS_HOLD_END)
