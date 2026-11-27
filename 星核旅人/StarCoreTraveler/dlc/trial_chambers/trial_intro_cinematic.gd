class_name TrialIntroCinematic
extends Node2D

## DLC1 星核试炼场 opening, 2026-11-27 rework.
##
## The film is not a painted screen: every frame is the live trial.  A real
## Camera2D hangs in front of the real `GateGold` (the same PolarityGate node
## the player meets), the real gold `PhaseCrystal` and the real sealed cyan twin
## flank it, and the warm seam light is drawn over the gate's own 8 px curtain
## and the real terrain floor.  The camera then pulls back to the real L3Player
## at the entrance.  Only the dark grade, vignette and skip footer are
## screen-space; they never draw the world.
##
## The gate's sun plate, padlock, curtain and collision are untouched.  The film
## only dims/restores the real node's modulate and adds light rings anchored to
## the real emblem plate.  The chapter's phase rule therefore stays exactly as
## approved: the player starts 澜相, the gold gate is locked until the real gold
## crystal flips the body, and the cyan gate still needs the player's own Q.
##
## Input: F (or the shared `tutorial_next` action) skips at once; holding Space
## for SKIP_HOLD also skips.  A skip snaps the camera to the player's gameplay
## view in the same frame.  The chapter keeps the player locked and the HUD
## hidden until `finished` arrives; a held Space does not become the first jump.
##
## The film never starts or stops the chapter ambience.  The chapter music is
## already playing and keeps running underneath.

signal finished(skipped: bool)

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const VIEW_CENTER: Vector2 = Vector2(320.0, 180.0)
## The approved window is 3.0-3.6 s.  The last 0.15 s is a settled player view
## so the HUD can begin its fade without a camera step.
const DURATION: float = 3.40
const SKIP_HOLD: float = 0.60
const GATE_FOCUS: Vector2 = Vector2(280.0, 245.0)
const GATE_ZOOM: float = 1.60
## The level's left limit is x=0 and the viewport is 640 wide, so the gameplay
## camera (player x=40) and the gate view (x=280) both clamp to centre x=320.
## A literal left pan would show empty sky left of the level, so the pull is a
## real 1.6 -> 1.0 zoom-out with a 40 px centre settle; the player at the far
## left enters the frame exactly as the gate slides left.
const PULL_START: float = 2.55
const PULL_END: float = 3.25
const LIGHT_FADE_START: float = 3.00
const LIGHT_FADE_END: float = 3.32
const FONT_PATH: String = "res://assets/fonts/tutorial_zh.ttf"

const GOLD: Color = Color("#f4cd63")
const CYAN: Color = Color("#5fe1e6")
const GOLD_PALE: Color = Color("#ffe796")
const CYAN_PALE: Color = Color("#bcffff")
const WARM: Color = Color(1.0, 0.84, 0.54, 1.0)
const WARM_PALE: Color = Color(1.0, 0.96, 0.84, 1.0)
const INK: Color = Color(0.004, 0.010, 0.014, 1.0)
const TEXT: Color = Color("#e7eceb")
const MUTED: Color = Color("#a4b3be")
const DARK_GRADE: Color = Color(0.004, 0.010, 0.014, 1.0)

const GATE_DIM: Color = Color(0.36, 0.38, 0.38, 1.0)
const CRYSTAL_DIM: Color = Color(0.30, 0.33, 0.34, 1.0)
const RELIC_DIM: Color = Color(0.28, 0.33, 0.35, 1.0)

const AUDIO_POOL_SIZE: int = 6


class WorldLightLayer:
	extends Node2D
	var host: TrialIntroCinematic = null

	func _draw() -> void:
		if host != null:
			host._draw_world_light(self)


var _gate: PolarityGate = null
var _crystal: TrialPhaseCrystal = null
var _relic: TrialSealedCrystal = null
var _player: L3Player = null
var _player_camera: Camera2D = null
var _hud: TrialHUD = null

var _opening_camera: Camera2D = null
var _world_layer: WorldLightLayer = null
var _grade_layer: CanvasLayer = null
var _grade: ColorRect = null
var _vignette: Control = null
var _ui_layer: CanvasLayer = null
var _footer: Control = null
var _hold_bg: ColorRect = null
var _hold_fill: ColorRect = null
var _font: Font = null

var _gate_original: Color = Color.WHITE
var _crystal_original: Color = Color.WHITE
var _relic_original: Color = Color.WHITE

var _gold_stream: AudioStream = null
var _cyan_stream: AudioStream = null
var _lock_stream: AudioStream = null
var _light_stream: AudioStream = null

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
var _gate_wake: float = 0.0
var _lock_turn: float = 0.0
var _seam: float = 0.0
var _pool: float = 0.0
var _light_fade: float = 1.0
var _grade_alpha: float = 0.0

var _played_cues: Dictionary = {}
var _cue_count: int = 0
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_cursor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera()
	_build_world_layer()
	_build_grade()
	_build_film_ui()
	_set_film_layers_visible(false)
	set_process(false)
	set_process_unhandled_input(false)
	_setup_cues()


func configure(
	gate: PolarityGate,
	crystal: TrialPhaseCrystal,
	relic: TrialSealedCrystal,
	player: L3Player,
	player_camera: Camera2D,
	hud: TrialHUD
) -> void:
	_gate = gate
	_crystal = crystal
	_relic = relic
	_player = player
	_player_camera = player_camera
	_hud = hud
	if _player_camera == null and _player != null:
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _gate != null:
		_gate_original = _gate.modulate
	if _crystal != null:
		_crystal_original = _crystal.modulate
	if _relic != null:
		_relic_original = _relic.modulate
	if _player_camera != null and _opening_camera != null:
		_opening_camera.limit_left = _player_camera.limit_left
		_opening_camera.limit_top = _player_camera.limit_top
		_opening_camera.limit_right = _player_camera.limit_right
		_opening_camera.limit_bottom = _player_camera.limit_bottom


func _build_camera() -> void:
	_opening_camera = Camera2D.new()
	_opening_camera.name = "OpeningCamera2D"
	_opening_camera.enabled = false
	_opening_camera.position_smoothing_enabled = false
	_opening_camera.position_smoothing_speed = 0.0
	_opening_camera.limit_left = 0
	_opening_camera.limit_top = 0
	_opening_camera.limit_right = 1280
	_opening_camera.limit_bottom = 360
	_opening_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(_opening_camera)


func _build_world_layer() -> void:
	# All light lives in world space, anchored to the real gate, real crystals
	# and real floor.  None of it is a second gate or a painted room.
	_world_layer = WorldLightLayer.new()
	_world_layer.name = "OpeningWorldLight"
	_world_layer.host = self
	_world_layer.z_index = 5
	_world_layer.visible = false
	add_child(_world_layer)


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
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var base: FontFile = ResourceLoader.load(FONT_PATH) as FontFile
	if base == null:
		return ThemeDB.fallback_font
	var copy: FontFile = base.duplicate() as FontFile
	if copy != null:
		copy.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		copy.hinting = TextServer.HINTING_NONE
		copy.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		copy.allow_system_fallback = false
		return copy
	return base


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
	if _gate == null or not is_instance_valid(_gate):
		_fail_start("gate")
		return false
	if _crystal == null or not is_instance_valid(_crystal):
		_fail_start("gold crystal")
		return false
	if _player == null or not is_instance_valid(_player):
		_fail_start("player")
		return false
	if _player_camera == null or not is_instance_valid(_player_camera):
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _player_camera == null or _opening_camera == null:
		_fail_start("camera")
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
	_gate_wake = 0.0
	_lock_turn = 0.0
	_seam = 0.0
	_pool = 0.0
	_light_fade = 1.0
	_grade_alpha = 0.0

	# Keep the real node's own idle look to restore after the film.
	_gate_original = _gate.modulate
	if _crystal != null:
		_crystal_original = _crystal.modulate
	if _relic != null:
		_relic_original = _relic.modulate
	_gate.modulate = GATE_DIM
	if _crystal != null:
		_crystal.modulate = CRYSTAL_DIM
	if _relic != null:
		_relic.modulate = RELIC_DIM

	# Hand the viewport to the real film camera.  The gameplay camera is
	# disabled rather than merely outranked, so no later smoothing tick can
	# steal a frame.
	_player_camera.enabled = false
	_opening_camera.enabled = true
	var state: Vector3 = _camera_state_at(0.0)
	_opening_camera.zoom = Vector2(state.z, state.z)
	_opening_camera.global_position = Vector2(roundf(state.x), roundf(state.y))
	_opening_camera.reset_smoothing()
	_opening_camera.make_current()

	_set_film_layers_visible(true)
	_apply_time(0.0)
	set_process(true)
	set_process_unhandled_input(true)
	return true


func _fail_start(reason: String) -> void:
	push_warning("TrialIntroCinematic: missing real " + reason + "; skipping film")
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
	var state: Vector3 = _camera_state_at(value)
	if _opening_camera != null:
		_opening_camera.zoom = Vector2(state.z, state.z)
		# Snap to whole pixels: the project renders at 1x and the gate must not
		# shimmer while the camera settles.
		_opening_camera.global_position = Vector2(
			roundf(state.x), roundf(state.y)
		)

	_gold_lit = smoothstep(0.98, 1.24, value)
	_cyan_lit = smoothstep(1.24, 1.50, value)
	_gate_wake = smoothstep(0.82, 1.55, value)
	_lock_turn = smoothstep(1.02, 1.95, value)
	_seam = smoothstep(1.30, 2.10, value)
	_pool = smoothstep(1.92, 2.45, value)
	_light_fade = 1.0 - smoothstep(LIGHT_FADE_START, LIGHT_FADE_END, value)
	_grade_alpha = _grade_alpha_at(value)

	if _gate != null and is_instance_valid(_gate):
		_gate.modulate = GATE_DIM.lerp(_gate_original, _gate_wake)
	if _crystal != null and is_instance_valid(_crystal):
		_crystal.modulate = CRYSTAL_DIM.lerp(_crystal_original, _gold_lit)
	if _relic != null and is_instance_valid(_relic):
		_relic.modulate = RELIC_DIM.lerp(_relic_original, _cyan_lit)

	if _grade != null:
		_grade.color = Color(DARK_GRADE, _grade_alpha)
	if _vignette != null:
		_vignette.modulate.a = clampf(_grade_alpha * 1.35, 0.0, 1.0)

	if _world_layer != null:
		_world_layer.visible = _active or _capture_mode
		_world_layer.queue_redraw()

	if _footer != null:
		var footer_alpha: float = 0.0
		if value > 0.34 and not _finished:
			footer_alpha = clampf((value - 0.34) / 0.22, 0.0, 1.0)
		_footer.modulate.a = footer_alpha
		_footer.visible = footer_alpha > 0.0


func _camera_state_at(value: float) -> Vector3:
	var gameplay: Vector2 = _gameplay_camera_center()
	var pull: float = smoothstep(PULL_START, PULL_END, value)
	var center: Vector2 = GATE_FOCUS.lerp(gameplay, pull)
	return Vector3(center.x, center.y, lerpf(GATE_ZOOM, 1.0, pull))


## The exact centre the real player camera would use for the current player.
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


func _grade_alpha_at(value: float) -> float:
	# The first beat is dark but never black: the real stone gate, its sun plate
	# and the two crystals stay readable behind the grade from frame one.
	if value < 0.95:
		return lerpf(0.50, 0.44, smoothstep(0.0, 0.95, value))
	if value < 1.90:
		return lerpf(0.42, 0.27, smoothstep(0.95, 1.90, value))
	if value < 2.60:
		return lerpf(0.27, 0.10, smoothstep(1.90, 2.60, value))
	if value < 3.10:
		return lerpf(0.10, 0.0, smoothstep(2.60, 3.10, value))
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
		_opening_camera.zoom = Vector2.ONE
		_opening_camera.global_position = _gameplay_camera_center()
	if _grade != null:
		_grade.color = Color(DARK_GRADE, 0.0)
	if _vignette != null:
		_vignette.modulate.a = 0.0
	if _world_layer != null:
		_world_layer.visible = false
	if _footer != null:
		_footer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_gate_looks()
	_stop_audio()
	_restore_player_camera()


func _restore_gate_looks() -> void:
	if _gate != null and is_instance_valid(_gate):
		_gate.modulate = _gate_original
	if _crystal != null and is_instance_valid(_crystal):
		_crystal.modulate = _crystal_original
	if _relic != null and is_instance_valid(_relic):
		_relic.modulate = _relic_original


func _restore_player_camera() -> void:
	if _opening_camera != null:
		_opening_camera.enabled = false
	if _player_camera != null and is_instance_valid(_player_camera) \
			and _player_camera.is_inside_tree():
		_player_camera.enabled = true
		_player_camera.make_current()
		_player_camera.reset_smoothing()


func _complete_await_release() -> void:
	if not _await_release:
		return
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_latched = false
	_emit_finished()


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
	if _world_layer != null:
		_world_layer.visible = false
	_set_hold_bar(false, 0.0)
	_restore_gate_looks()
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
	if _gold_stream != null:
		return
	_gold_stream = DlcIntroSfx.crystal_pulse(880.0)
	_cyan_stream = DlcIntroSfx.crystal_pulse(659.25)
	_lock_stream = DlcIntroSfx.lock_turn()
	_light_stream = DlcIntroSfx.door_light()


func _tick_cues() -> void:
	if _gold_stream == null:
		_setup_cues()
	_play_cue("gold_crystal", 1.00, _gold_stream, -9.0)
	_play_cue("lock_turn", 1.10, _lock_stream, -8.0)
	_play_cue("cyan_crystal", 1.26, _cyan_stream, -9.0)
	_play_cue("door_light", 1.94, _light_stream, -10.0)


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


# --- world-space light (real gate / crystals / floor) ------------------------

func _draw_world_light(canvas: Node2D) -> void:
	if _gate == null or not is_instance_valid(_gate):
		return
	_draw_floor_pool(canvas)
	_draw_seam_light(canvas)
	_draw_lock_rings(canvas)
	_draw_crystal_halo(canvas, _crystal, _gold_lit, GOLD, GOLD_PALE)
	_draw_crystal_halo(canvas, _relic, _cyan_lit, CYAN, CYAN_PALE)
	_draw_dust(canvas)


## Warm light landing on the real terrain top and spilling down its face.
func _draw_floor_pool(canvas: Node2D) -> void:
	var f: float = _pool * _light_fade
	if f <= 0.001:
		return
	var base: Vector2 = canvas.to_local(_gate.global_position)
	for layer: int in range(3):
		var radius_x: float = 24.0 + float(layer) * 18.0
		var radius_y: float = 2.4 + float(layer) * 1.8
		var alpha: float = (0.30 - float(layer) * 0.085) * f
		canvas.draw_colored_polygon(
			_ellipse_points(base + Vector2(0.0, 2.5), radius_x, radius_y, 20),
			Color(WARM, alpha)
		)
	canvas.draw_rect(
		Rect2(base.x - 12.0, base.y + 1.0, 24.0, 1.0),
		Color(WARM_PALE, 0.78 * f)
	)
	canvas.draw_rect(
		Rect2(base.x - 5.0, base.y + 2.0, 10.0, 1.0),
		Color(1.0, 0.99, 0.93, 0.62 * f)
	)
	# A few 1 px fingers of light on the ground's vertical face.
	for index: int in range(5):
		var x: float = base.x - 16.0 + float(index) * 8.0
		var length: float = 3.0 + float(index % 3) * 3.0
		canvas.draw_rect(
			Rect2(x, base.y + 2.0, 1.0, length),
			Color(WARM, 0.15 * f)
		)


## The real 8 px curtain stays visible underneath; the film adds the warm seam
## light that the storyboard asks for only after the lock has turned.
func _draw_seam_light(canvas: Node2D) -> void:
	var f: float = _seam * _light_fade
	if f <= 0.001:
		return
	var rect: Rect2 = _gate.get_gate_rect()
	var half: float = rect.size.x * 0.5
	var cx: float = rect.position.x + half
	var top: float = rect.position.y + 7.0
	var bottom: float = rect.end.y - 7.0
	var height: float = maxf(bottom - top, 1.0)
	for layer: int in range(3):
		var extra: float = 8.0 + float(layer) * 8.0
		var alpha: float = (0.065 - float(layer) * 0.016) * f
		canvas.draw_rect(
			Rect2(cx - half - extra, top, rect.size.x + extra * 2.0, height),
			Color(WARM, alpha)
		)
	# One 1 px column per real curtain pixel, brighter toward the centre.
	for index: int in range(int(rect.size.x)):
		var column_x: float = cx - half + float(index)
		var edge: float = absf(float(index) + 0.5 - half) / maxf(half, 1.0)
		var alpha: float = (0.72 - 0.38 * edge) * f
		canvas.draw_rect(
			Rect2(column_x, top, 1.0, height),
			Color(WARM_PALE, alpha)
		)
	canvas.draw_rect(
		Rect2(cx - 1.0, top, 2.0, height),
		Color(1.0, 0.98, 0.92, 0.52 * f)
	)
	# Two long 1 px rays leave the seam at the height of the lock.
	for side: float in [-1.0, 1.0]:
		var ray_y: float = top + height * 0.42
		var ray_x: float = cx + side * (half + 2.0)
		if side < 0.0:
			ray_x -= 10.0
		canvas.draw_rect(
			Rect2(ray_x, ray_y, 10.0, 1.0),
			Color(WARM, 0.30 * f)
		)


## Light rings hung on the real 34x34 emblem plate.  The real sun emblem and
## padlock are still drawn by PolarityGate underneath; these rings only rotate
## and glow around them.
func _draw_lock_rings(canvas: Node2D) -> void:
	var f: float = _gate_wake * _light_fade
	if f <= 0.001:
		return
	var center: Vector2 = canvas.to_local(_gate.get_emblem_center_global())
	var pulse: float = 0.82 + 0.18 * sin(_time * 9.0)
	# Soft halo behind the plate, in the chapter's gold/cyan split.
	for layer: int in range(2):
		var radius: float = 25.0 + float(layer) * 5.0
		canvas.draw_colored_polygon(
			_diamond_points(center, radius * 0.78, radius),
			Color(GOLD if layer == 0 else CYAN, (0.055 - float(layer) * 0.02) * f * pulse)
		)
	# Sun ring: eight gold teeth on an outer radius.
	var gold_angle: float = _lock_turn * 2.25
	for index: int in range(8):
		var angle: float = gold_angle + TAU * float(index) / 8.0
		var from: Vector2 = center + Vector2(cos(angle), sin(angle)) * 18.5
		var to: Vector2 = center + Vector2(cos(angle), sin(angle)) * (23.0 + 1.5 * pulse)
		canvas.draw_line(from, to, Color(GOLD, 0.66 * f * pulse), 1.0)
	canvas.draw_arc(
		center, 20.0, gold_angle, gold_angle + TAU, 28,
		Color(GOLD, 0.30 * f * pulse), 1.0
	)
	# Moon ring: two cyan arcs counter-rotating inside the sun ring.
	var cyan_angle: float = -_lock_turn * 1.70
	canvas.draw_arc(
		center, 16.5, cyan_angle, cyan_angle + PI * 1.45, 20,
		Color(CYAN, 0.58 * f * pulse), 1.0
	)
	canvas.draw_arc(
		center, 16.5, cyan_angle + PI, cyan_angle + TAU, 20,
		Color(CYAN, 0.34 * f * pulse), 1.0
	)
	for index: int in range(3):
		var angle: float = cyan_angle + TAU * float(index) / 3.0
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * 16.5
		canvas.draw_rect(Rect2(roundf(point.x), roundf(point.y), 1.0, 1.0),
			Color(CYAN_PALE, 0.70 * f))
	# A single bright tick at the top of the lock: the "it has answered" mark.
	canvas.draw_rect(
		Rect2(center.x, center.y - 24.0, 1.0, 2.0),
		Color(WARM_PALE, 0.75 * f)
	)


func _draw_crystal_halo(
	canvas: Node2D,
	node: Node2D,
	amount: float,
	color: Color,
	pale: Color
) -> void:
	if node == null or not is_instance_valid(node) or amount <= 0.001:
		return
	var center: Vector2 = canvas.to_local(node.call("get_shard_center_global") as Vector2)
	var f: float = amount * _light_fade
	# Layered diamonds keep the light pixel-shaped at 1x.
	for layer: int in range(3):
		var inflate: float = 4.0 + float(layer) * 5.0
		canvas.draw_colored_polygon(
			_diamond_points(center, 8.0 + inflate * 0.62, 13.0 + inflate),
			Color(color, (0.15 - float(layer) * 0.035) * f)
		)
	canvas.draw_polyline(
		PackedVector2Array([
			center + Vector2(0.0, -22.0),
			center + Vector2(11.0, 0.0),
			center + Vector2(0.0, 22.0),
			center + Vector2(-11.0, 0.0),
			center + Vector2(0.0, -22.0),
		]),
		Color(pale, 0.60 * f),
		1.0
	)
	# Three orbit sparks, the same language as the live crystal's own glow.
	for index: int in range(3):
		var angle: float = _time * (1.15 + float(index) * 0.18) + TAU * float(index) / 3.0
		var radius: float = 13.0 + float(index) * 3.0
		var spark: Vector2 = center + Vector2(
			roundf(cos(angle) * radius), roundf(sin(angle) * radius * 0.55)
		)
		var alpha: float = (0.45 + 0.35 * sin(_time * 3.0 + float(index))) * f
		canvas.draw_rect(Rect2(spark, Vector2.ONE), Color(pale, alpha))
	# A 1 px stain on the floor under the shard.
	canvas.draw_rect(
		Rect2(center.x - 7.0, node.global_position.y + 1.0, 14.0, 1.0),
		Color(color, 0.18 * f)
	)


func _draw_dust(canvas: Node2D) -> void:
	var f: float = _seam * _light_fade
	if f <= 0.001:
		return
	var base: Vector2 = canvas.to_local(_gate.global_position)
	var base_x: float = base.x
	var base_y: float = base.y
	for index: int in range(18):
		var x: float = base_x - 24.0 + fmod(float(index) * 13.0, 48.0)
		var rise: float = fmod(_time * 24.0 + float(index) * 31.0, 84.0)
		var y: float = base_y - 4.0 - rise
		var alpha: float = (1.0 - rise / 84.0) * 0.50 * f
		canvas.draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0),
			Color(WARM_PALE, alpha))


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _diamond_points(center: Vector2, half_x: float, half_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -half_y),
		center + Vector2(half_x, 0.0),
		center + Vector2(0.0, half_y),
		center + Vector2(-half_x, 0.0),
	])


# --- visibility / UI helpers ------------------------------------------------

func _set_film_layers_visible(value: bool) -> void:
	if _grade_layer != null:
		_grade_layer.visible = value
	if _ui_layer != null:
		_ui_layer.visible = value
	if not value and _world_layer != null:
		_world_layer.visible = false


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
	if _gate == null or _player == null:
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
	if _gate != null:
		_gate_original = Color.WHITE
	if _crystal != null:
		_crystal_original = Color.WHITE
	if _relic != null:
		_relic_original = Color.WHITE
	if _player_camera != null:
		_player_camera.enabled = false
	if _opening_camera != null:
		_opening_camera.enabled = true
		_opening_camera.make_current()
	_set_film_layers_visible(true)
	_apply_time(_time)
	_footer.visible = _time > 0.34
	_footer.modulate.a = 1.0 if _footer.visible else 0.0
	if _vignette != null:
		_vignette.modulate.a = clampf(_grade_alpha * 1.35, 0.0, 1.0)
	if _world_layer != null:
		_world_layer.visible = true
		_world_layer.queue_redraw()


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


func get_gold_lit_amount() -> float:
	return _gold_lit


func get_cyan_lit_amount() -> float:
	return _cyan_lit


func get_lock_turn_amount() -> float:
	return _lock_turn


func get_seam_amount() -> float:
	return _seam


func get_pool_amount() -> float:
	return _pool


func get_phase_name() -> String:
	if not _active and not _capture_mode:
		return "DONE"
	if _time < 1.00:
		return "GATE_HELD"
	if _time < 1.95:
		return "LOCKS_WAKE"
	if _time < 2.55:
		return "SEAM_LIGHT"
	if _time < PULL_END:
		return "PULL_BACK"
	return "PLAYER_VIEW"


func get_opening_camera() -> Camera2D:
	return _opening_camera


func get_player_camera() -> Camera2D:
	return _player_camera


func get_gate() -> PolarityGate:
	return _gate


func get_crystal() -> TrialPhaseCrystal:
	return _crystal


func get_relic() -> TrialSealedCrystal:
	return _relic


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


func get_gate_emblem_world_position() -> Vector2:
	if _gate == null:
		return Vector2.ZERO
	return _gate.get_emblem_center_global()


func get_crystal_world_position() -> Vector2:
	if _crystal == null:
		return Vector2.ZERO
	return _crystal.get_shard_center_global()


func get_relic_world_position() -> Vector2:
	if _relic == null:
		return Vector2.ZERO
	return _relic.get_shard_center_global()
