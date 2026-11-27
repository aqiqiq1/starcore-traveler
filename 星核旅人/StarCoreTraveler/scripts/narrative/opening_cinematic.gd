class_name OpeningCinematic
extends Node

## Level-01 opening film "地震 · 石碑 · 残响" (2026-11-27 rework).
##
## The film is played in the real level-01 scene. The player is the real
## PrototypePlayer walking under its existing input-override rules; the stele
## and echo are the real GuideEcho node's carrier stone / projection; the bridge
## is the real terrain and the shared CloudRuinsDS03 background. This controller
## only owns a camera, light, dust, a star-core presentation sprite and the page
## timing.
##
## Timeline (20.4 s):
##   0.0-2.5  black, dust first, low rumble + debris, camera shake <= 2 px
##   2.5-5.0  fade-in to the wide bridge courtyard, cold sky, clouds running
##   5.0-8.0  player staggers in from the right edge, stops, looks around
##   8.0-9.25 camera frames the stele; 9.25 touch, grooves light, quake stops
##   10.0-17.2 echo: whisper first, then a translucent projection and 3 pages
##   17.2-19.0 first star core travels from the stele to the player's chest
##   19.0-20.4 camera returns to gameplay, HUD fades in, control returns
##
## Input: F (or the shared tutorial_next action) skips the whole film at once.
## Holding Space for 0.6 s also skips. A short Space tap is inert. If the skip
## happens with Space still held, the film keeps the movement lock until that
## key is released, so the same press cannot become a jump. The film is
## PAUSABLE and never pauses or stops the level music.

signal finished(skipped: bool)
signal aborted

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const VIEW_CENTER: Vector2 = Vector2(320.0, 180.0)
const DURATION: float = 20.4

const BLACK_END: float = 2.5
const FADE_END: float = 4.5
const ENTER_START: float = 5.0
const ENTER_END: float = 8.0
const TOUCH_TIME: float = 9.25
const TOUCH_POSE_END: float = 9.55
## The sound arrives before the form. The player backs away, looks left/right
## and gets one question mark while the projection is still invisible; the echo
## only forms at 10.35, then the player turns back to the stele.
const ECHO_SOUND_TIME: float = 9.40
const ECHO_FORM_START: float = 10.0
const ECHO_FORM_END: float = 10.35
const DOUBT_STEP_START: float = 9.55
const DOUBT_STEP_END: float = 9.85
const DOUBT_LOOK_LEFT_END: float = 10.10
const DOUBT_LOOK_RIGHT_END: float = 10.35
const DOUBT_RETURN_END: float = 10.65
const QUESTION_START: float = 9.65
const QUESTION_END: float = 10.45
const PAGES_START: float = 10.70
const CORE_TIME: float = 17.2
const CORE_HANDOFF_TIME: float = 18.42
const ZOOM_OUT_END: float = 19.02
const RETURN_TIME: float = 19.0
const HUD_RETURN_TIME: float = 19.05
const HANDOFF_TIME: float = 20.4

const ENTRY_POSITION: Vector2 = Vector2(656.0, 300.0)
const HANDOFF_X: float = 286.0
const PAGE_HOLD: float = 1.15
const DIALOGUE_RETRY: float = 1.0
const SKIP_HOLD: float = 0.6
const LETTERBOX_HEIGHT: float = 44.0

const WIDE_CAMERA: Vector2 = Vector2(320.0, 180.0)
## 1.7x close framing keeps the stele (x 237-263), the projection beside it
## (x 200-248) and the player (x ~284) in one shot. The 1.7x view is 376x212 px,
## so y=248 is needed to keep the ground/feet in frame.
const CLOSE_CAMERA: Vector2 = Vector2(270.0, 248.0)
const CLOSE_ZOOM: float = 1.7

const PROMPT_FOOTER_SCRIPT = preload("res://scripts/ui/prompt_footer.gd")
const SFX = preload("res://scripts/narrative/opening_l1_sfx.gd")
const CORE_TEXTURE: Texture2D = preload("res://assets/star_core/star_core_positive_12f.png")
const CORE_GLOW_TEXTURE: Texture2D = preload("res://assets/talisman/glow_gold_4f.png")
const QUESTION_TEXTURE: Texture2D = preload("res://assets/level03_prototype/emote_question.png")
const CORE_FRAME_COUNT: int = 12
const CORE_GLOW_FRAME_COUNT: int = 4

const BLACK: Color = Color(0.003, 0.008, 0.010, 1.0)
const GOLD: Color = Color(1.0, 0.82, 0.38, 1.0)
const CYAN: Color = Color(0.37, 0.88, 0.90, 1.0)
const DUST_COLOR: Color = Color(0.72, 0.78, 0.74, 1.0)

enum Phase { IDLE, BLACK, FADE_IN, ENTER, TOUCH, DIALOGUE, CORE, RETURN, AWAIT_RELEASE }


class DustLayer:
	extends Node2D
	var host: Node = null

	func _draw() -> void:
		if host != null:
			host.call("_draw_dust", self)


class VignetteLayer:
	extends Node2D
	var host: Node = null

	func _draw() -> void:
		if host != null:
			host.call("_draw_vignette", self)


class SparkLayer:
	extends Node2D
	var host: Node = null

	func _draw() -> void:
		if host != null:
			host.call("_draw_touch_spark", self)


var _level: Node = null
var _player: PrototypePlayer = null
var _echo: GuideEcho = null
var _hud: Level01HUD = null
var _world: Node2D = null

var _ui: CanvasLayer = null
var _root: Control = null
var _fade: ColorRect = null
var _dust: DustLayer = null
var _vignette: VignetteLayer = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _letterbox_height: float = LETTERBOX_HEIGHT
var _skip_bar: SkipHoldBar = null
var _prompt_footer: Control = null

var _player_camera: Camera2D = null
var _opening_camera: Camera2D = null
var _echo_projection_node: Node2D = null
var _echo_projection: CanvasItem = null
var _background: Node2D = null
var _stele_glow: OpeningSteleGlow = null
var _core: Sprite2D = null
var _core_glow: Sprite2D = null
var _touch_spark: SparkLayer = null
var _question: Sprite2D = null

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor: int = 0
var _wind_player: AudioStreamPlayer = null
var _rumble_player: AudioStreamPlayer = null
var _wind_target_db: float = -27.0
var _wind_current_db: float = -27.0

var _phase: Phase = Phase.IDLE
var _active: bool = false
var _await_release: bool = false
var _space_held: bool = false
var _space_time: float = 0.0
var _space_action_done: bool = false
var _skipped: bool = false
var _skip_count: int = 0
var _elapsed: float = 0.0
var _play_count: int = 0

var _page_index: int = -1
var _page_hold: float = 0.0
var _dialogue_started: bool = false
var _dialogue_attempt_time: float = 0.0
var _dialogue_warned: bool = false

var _core_started: bool = false
var _core_landed: bool = false
var _core_handoff_count: int = 0
var _stele_touched: bool = false
var _touch_pose_started: bool = false
var _touch_pose_done: bool = false
var _doubt_start_x: float = 0.0
var _doubt_peak_offset: float = 0.0
var _doubt_done: bool = false
var _question_seen: bool = false
var _page_pulse: float = 0.0
var _hud_returned: bool = false
var _return_started: bool = false
var _return_played: bool = false

var _pre_player_position: Vector2 = Vector2.ZERO
var _pre_facing: int = 1
var _shake_amplitude: float = 0.0
var _played_cues: Dictionary = {}
var _cue_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -20
	_build_ui()
	_prepare_audio_streams()
	set_process(false)
	set_process_unhandled_input(false)
	set_physics_process(false)
	_ui.visible = false


func setup(level: Node, player: PrototypePlayer, echo: GuideEcho, hud: Level01HUD) -> void:
	_level = level
	_player = player
	_echo = echo
	_hud = hud
	if _level != null:
		_world = _level.get_node_or_null("World") as Node2D
		_opening_camera = _level.call("get_opening_camera") as Camera2D
		_background = _level.get_node_or_null(
			"Background/CloudRuinsDS03"
		) as Node2D
	if _player != null:
		_player_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if _echo != null:
		_echo_projection_node = _echo.get_node_or_null("EchoProjection") as Node2D
		_echo_projection = _echo_projection_node as CanvasItem
		_stele_glow = _echo.get_node_or_null("SteleGlow") as OpeningSteleGlow
	_ensure_world_fx()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "OpeningCinematicUI"
	_ui.layer = 12
	_ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_ui)
	_root = Control.new()
	_root.name = "OpeningCinematicRoot"
	_root.size = VIEW_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)

	_fade = ColorRect.new()
	_fade.name = "Black"
	_fade.position = Vector2.ZERO
	_fade.size = VIEW_SIZE
	_fade.color = BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_vignette = VignetteLayer.new()
	_vignette.name = "Vignette"
	_vignette.host = self
	_root.add_child(_vignette)

	_dust = DustLayer.new()
	_dust.name = "Dust"
	_dust.host = self
	_root.add_child(_dust)

	# 44 px L3-style letterbox. Added after the dust so the bars cover any
	# shaking specks; added before the footer/skip controls so the text stays
	# above the bars and never shakes.
	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(VIEW_SIZE.x, LETTERBOX_HEIGHT)
	_top_bar.color = Color(0.008, 0.014, 0.018, 0.98)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.position = Vector2(0.0, VIEW_SIZE.y - LETTERBOX_HEIGHT)
	_bottom_bar.size = Vector2(VIEW_SIZE.x, LETTERBOX_HEIGHT)
	_bottom_bar.color = Color(0.008, 0.014, 0.018, 0.98)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom_bar)

	_skip_bar = SkipHoldBar.new()
	_skip_bar.name = "SkipHoldBar"
	_root.add_child(_skip_bar)

	_prompt_footer = PROMPT_FOOTER_SCRIPT.new()
	_prompt_footer.name = "PromptFooter"
	_root.add_child(_prompt_footer)


func _apply_letterbox(height: float) -> void:
	_letterbox_height = clampf(height, 0.0, LETTERBOX_HEIGHT)
	if _top_bar != null:
		_top_bar.position = Vector2.ZERO
		_top_bar.size = Vector2(VIEW_SIZE.x, _letterbox_height)
	if _bottom_bar != null:
		_bottom_bar.position = Vector2(0.0, VIEW_SIZE.y - _letterbox_height)
		_bottom_bar.size = Vector2(VIEW_SIZE.x, _letterbox_height)


func _ensure_world_fx() -> void:
	if _world == null:
		return
	if _touch_spark == null:
		_touch_spark = SparkLayer.new()
		_touch_spark.name = "OpeningTouchSpark"
		_touch_spark.host = self
		_touch_spark.z_index = 9
		_touch_spark.visible = false
		_world.add_child(_touch_spark)
	if _core == null:
		_core = Sprite2D.new()
		_core.name = "OpeningStarCore"
		_core.texture = CORE_TEXTURE
		_core.hframes = CORE_FRAME_COUNT
		_core.vframes = 1
		_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_core.z_index = 7
		_core.visible = false
		_world.add_child(_core)
	if _core_glow == null:
		_core_glow = Sprite2D.new()
		_core_glow.name = "OpeningStarCoreGlow"
		_core_glow.texture = CORE_GLOW_TEXTURE
		_core_glow.hframes = CORE_GLOW_FRAME_COUNT
		_core_glow.vframes = 1
		_core_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_core_glow.scale = Vector2(1.0, 1.0)
		_core_glow.z_index = 6
		_core_glow.visible = false
		_world.add_child(_core_glow)
	if _question == null:
		_question = Sprite2D.new()
		_question.name = "OpeningQuestionMark"
		_question.texture = QUESTION_TEXTURE
		_question.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_question.z_index = 20
		_question.visible = false
		_world.add_child(_question)


# --- lifecycle --------------------------------------------------------------


func start() -> bool:
	if _active or _await_release:
		return false
	if _player == null or _echo == null or _hud == null:
		return false
	if _opening_camera == null or _player_camera == null:
		return false
	if _echo.get_page_count() <= 0:
		return false

	_play_count += 1
	_active = true
	_await_release = false
	_skipped = false
	_skip_count = 0
	_elapsed = 0.0
	_phase = Phase.BLACK
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_page_index = -1
	_page_hold = 0.0
	_dialogue_started = false
	_dialogue_attempt_time = 0.0
	_dialogue_warned = false
	_core_started = false
	_core_landed = false
	_core_handoff_count = 0
	_stele_touched = false
	_touch_pose_started = false
	_touch_pose_done = false
	_doubt_start_x = 0.0
	_doubt_peak_offset = 0.0
	_doubt_done = false
	_question_seen = false
	_page_pulse = 0.0
	_hud_returned = false
	_return_started = false
	_return_played = false
	_played_cues.clear()
	_cue_count = 0
	_wind_target_db = -27.0
	_wind_current_db = -27.0

	_pre_player_position = _player.global_position
	_pre_facing = _player.get_facing()
	_player.global_position = ENTRY_POSITION
	_player.velocity = Vector2.ZERO
	_player.clear_external_force()
	_player.set_physics_process(true)
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	_player.set_facing_direction(-1)
	_player.clear_input_buffers()
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)

	if _touch_spark != null:
		_touch_spark.visible = false
	if _core != null:
		_core.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	if _question != null:
		_question.visible = false
	if _echo_projection_node != null:
		_echo_projection_node.position = Vector2(-26.0, -18.0)
	if _echo_projection != null:
		_echo_projection.modulate.a = 0.0
	if _background != null:
		_background.scale = Vector2.ONE
		_background.position = Vector2.ZERO
	if _stele_glow != null:
		_stele_glow.set_state(0.0, 0.0)
	_echo.force_close()
	_echo.set_suspended(false)
	_echo.set_cinematic_owned(true)

	# Camera hand-off: the real player Camera2D is disabled, the authored
	# OpeningCamera becomes current for the whole film.
	_player_camera.enabled = false
	_opening_camera.enabled = true
	_opening_camera.make_current()
	_opening_camera.position = WIDE_CAMERA
	_opening_camera.zoom = Vector2.ONE
	_opening_camera.reset_smoothing()

	_hud.visible = true
	_hud.set_polarity(true)
	_hud.show_completion(false)
	_hud.set_pause_visible(false)
	_hud.set_opening_active(true)
	_hud.show_toast("", 0.0)

	_fade.color = BLACK
	_fade.visible = true
	_dust.position = Vector2.ZERO
	_vignette.visible = true
	_apply_letterbox(LETTERBOX_HEIGHT)
	_top_bar.visible = true
	_bottom_bar.visible = true
	_skip_bar.hide_progress()
	_prompt_footer.call("hide_footer")
	_ui.visible = true
	_start_audio()

	set_process(true)
	set_process_unhandled_input(true)
	set_physics_process(true)
	return true


func _process(delta: float) -> void:
	if _await_release:
		_hide_prompt_footer()
		if _skip_bar != null:
			_skip_bar.hide_progress()
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_complete_handoff()
		return
	if not _active:
		_hide_prompt_footer()
		return
	if get_tree() != null and get_tree().paused:
		_hide_prompt_footer()
		return

	_elapsed += delta
	if _space_held and not _space_action_done:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_action_done = true
			_request_skip()
			return
	_update_skip_bar()

	var time: float = _elapsed
	_update_phase(time)
	_tick_cues(time)
	_update_visuals(time, delta)
	_tick_pages(time, delta)
	_update_core(time)
	_update_return(time)
	_update_prompt_footer()

	if time >= HANDOFF_TIME:
		_complete_finish()


## The real player is driven by the same input-override path as gameplay. This
## tick runs before the player's physics tick (priority -20), so the scripted
## axis is the one the player reads this frame.
func _physics_process(_delta: float) -> void:
	if not _active or _await_release:
		return
	_drive_player(_elapsed)


func _drive_player(time: float) -> void:
	if _player == null:
		return
	if time < ENTER_START:
		_player.set_input_override_axis(0.0, false)
		return
	if time < 5.90:
		_player.set_input_override_axis(-1.0, true)
		return
	if time < 6.10:
		_player.set_input_override_axis(0.0, false)
		return
	if time < 7.00:
		_player.set_input_override_axis(-1.0, true)
		return
	if time < 7.20:
		_player.set_input_override_axis(0.0, false)
		return
	if time < 7.55:
		_player.set_input_override_axis(0.0, false)
		# Two short beats: look right, then back toward the stele.
		_player.set_facing_direction(1 if time < 7.38 else -1)
		return
	if time < 8.0:
		if _player.global_position.x > HANDOFF_X + 12.0:
			_player.set_input_override_axis(-1.0, true)
		else:
			_player.set_input_override_axis(0.0, false)
		return
	if time < 8.65:
		if _player.global_position.x > HANDOFF_X + 2.0:
			_player.set_input_override_axis(-1.0, false)
		else:
			_player.set_input_override_axis(0.0, false)
		return
	if time >= TOUCH_TIME:
		if not _stele_touched:
			_stele_touched = true
			_doubt_start_x = _player.global_position.x
		if is_zero_approx(_doubt_start_x):
			_doubt_start_x = _player.global_position.x
		if time < DOUBT_STEP_START:
			_player.set_input_override_axis(0.0, false)
			return
		if time < DOUBT_STEP_END:
			if _player.global_position.x < _doubt_start_x + 4.0:
				_player.set_input_override_axis(1.0, false)
			else:
				_player.set_input_override_axis(0.0, false)
			# Safety cap for low frame rates: the half-step is authored as 6-8 px
			# and must never exceed 10 px or change the landing.
			if _player.global_position.x > _doubt_start_x + 8.0:
				_player.global_position.x = _doubt_start_x + 8.0
				_player.velocity.x = 0.0
			_doubt_peak_offset = maxf(
				_doubt_peak_offset,
				absf(_player.global_position.x - _doubt_start_x)
			)
			return
		if time < ECHO_FORM_END:
			_player.set_input_override_axis(0.0, false)
			_doubt_peak_offset = maxf(
				_doubt_peak_offset,
				absf(_player.global_position.x - _doubt_start_x)
			)
			return
		if time < DOUBT_RETURN_END:
			if _player.global_position.x > _doubt_start_x + 4.0:
				_player.set_input_override_axis(-1.0, false)
			else:
				_player.set_input_override_axis(0.0, false)
			if _player.global_position.x < _doubt_start_x:
				_player.global_position.x = _doubt_start_x
				_player.velocity.x = 0.0
			_doubt_peak_offset = maxf(
				_doubt_peak_offset,
				absf(_player.global_position.x - _doubt_start_x)
			)
			return
		_player.set_input_override_axis(0.0, false)
		if not _doubt_done:
			_doubt_done = true
			var offset: float = _player.global_position.x - _doubt_start_x
			if absf(offset) <= 1.5:
				_player.global_position.x = _doubt_start_x
		return
	_player.set_input_override_axis(0.0, false)


func _update_phase(time: float) -> void:
	if time < BLACK_END:
		_phase = Phase.BLACK
	elif time < ENTER_START:
		_phase = Phase.FADE_IN
	elif time < ENTER_END:
		_phase = Phase.ENTER
	elif time < PAGES_START:
		_phase = Phase.TOUCH
	elif time < CORE_TIME:
		_phase = Phase.DIALOGUE
	elif time < RETURN_TIME:
		_phase = Phase.CORE
	else:
		_phase = Phase.RETURN


# --- pages ------------------------------------------------------------------


func _tick_pages(time: float, delta: float) -> void:
	if time < PAGES_START:
		return
	if not _dialogue_started:
		if _echo == null:
			_begin_core(time)
			return
		if _echo.open_dialogue():
			_dialogue_started = true
			_dialogue_attempt_time = 0.0
			_page_index = _echo.get_page_index()
			_page_hold = 0.0
		else:
			_dialogue_attempt_time += delta
			if _dialogue_attempt_time >= DIALOGUE_RETRY:
				if not _dialogue_warned:
					push_warning("OpeningCinematic: echo page did not open")
					_dialogue_warned = true
				_begin_core(time)
			return
	if not _echo.is_dialogue_open():
		if _dialogue_started:
			_begin_core(time)
		return
	var index: int = _echo.get_page_index()
	if index != _page_index:
		_page_index = index
		_page_hold = 0.0
		_page_pulse = 1.0
	var full: String = _echo.get_full_page_text()
	if full.is_empty():
		return
	if _echo.get_revealed_count() < full.length():
		_page_hold = 0.0
		return
	_page_hold += delta
	if _page_hold < PAGE_HOLD:
		return
	if index + 1 < _echo.get_page_count():
		_echo.advance_page()
		_page_hold = 0.0
	else:
		_echo.force_close()
		_begin_core(time)


func _begin_core(time: float) -> void:
	if _core_started:
		return
	_core_started = true
	_page_hold = 0.0
	_hide_prompt_footer()
	if _echo != null:
		_echo.force_close()
	if _stele_glow != null:
		_stele_glow.set_state(1.0, 1.0)
	if _core != null:
		_core.visible = true
		_core.modulate.a = 1.0
		_core.position = Vector2(250.0, 274.0)
		_core.frame = 0
	if _core_glow != null:
		_core_glow.visible = true
		_core_glow.modulate.a = 0.85
		_core_glow.position = Vector2(250.0, 274.0)
	_play_cue("core_emerge", time, -10.0)


func _update_core(time: float) -> void:
	if not _core_started:
		return
	if _core == null or _core_glow == null:
		return
	var rise: float = clampf((time - CORE_TIME) / 0.45, 0.0, 1.0)
	var fly: float = smoothstep(0.0, 1.0, clampf((time - CORE_TIME - 0.35) / 0.85, 0.0, 1.0))
	var start: Vector2 = Vector2(250.0, 274.0)
	var raised: Vector2 = Vector2(250.0, 252.0)
	var target: Vector2 = _player_chest()
	var position: Vector2 = start.lerp(raised, smoothstep(0.0, 1.0, rise))
	if fly > 0.0:
		position = raised.lerp(target, fly) + Vector2(0.0, -13.0 * sin(fly * PI))
	_core.position = position.round()
	_core_glow.position = position.round()
	# The sheet's 12 frames include a collapse-to-a-line pulse. Keep the four
	# full-orb frames for the handoff so the first core always reads as an orb
	# in front of the chest, never as a one-pixel line at the key beat.
	_core.frame = int(maxf(0.0, time - CORE_TIME) * 8.0) % 4
	_core_glow.frame = int(maxf(0.0, time) * 8.0) % CORE_GLOW_FRAME_COUNT
	if not _core_landed and time >= CORE_TIME + 1.22:
		_core_landed = true
		_core_handoff_count += 1
		_play_cue("core_handoff", time, -9.0)
	if _core_landed:
		var fade: float = clampf((time - (CORE_TIME + 1.22)) / 0.38, 0.0, 1.0)
		_core.modulate.a = 1.0 - fade
		_core_glow.modulate.a = 0.85 * (1.0 - fade)
		if fade >= 1.0:
			_core.visible = false
			_core_glow.visible = false
		if _stele_glow != null:
			_stele_glow.set_state(1.0, lerpf(1.0, 0.40, fade))


func _player_chest() -> Vector2:
	if _player == null:
		return Vector2(286.0, 278.0)
	return _player.get_chest_anchor_global()


# --- visuals ----------------------------------------------------------------


func _update_visuals(time: float, delta: float) -> void:
	if time >= TOUCH_TIME:
		if not _stele_touched:
			_stele_touched = true
			if _player != null:
				_doubt_start_x = _player.global_position.x
		if not _touch_pose_started and not _touch_pose_done and _player != null:
			# One real walk frame (hand forward) is held as the reach; no new
			# character art or fake arm is introduced.
			_touch_pose_started = true
			_player.velocity = Vector2.ZERO
			_player.show_showcase(&"walk", 4, -1, true, -1)
	if _touch_pose_started and time >= TOUCH_POSE_END and _player != null:
		_touch_pose_started = false
		_touch_pose_done = true
		_player.end_showcase()
	if _player != null:
		if time >= DOUBT_STEP_END and time < DOUBT_LOOK_LEFT_END:
			_player.set_facing_direction(-1)
		elif time >= DOUBT_LOOK_LEFT_END and time < DOUBT_LOOK_RIGHT_END:
			_player.set_facing_direction(1)
		elif time >= DOUBT_LOOK_RIGHT_END and time < DOUBT_RETURN_END:
			_player.set_facing_direction(-1)
	var question_visible: bool = time >= QUESTION_START and time < QUESTION_END
	if _question != null:
		_question.visible = question_visible
		if question_visible and _player != null:
			_question_seen = true
			var bob: int = 0 if fmod(time, 0.56) < 0.30 else -1
			_question.position = (_player.global_position + Vector2(0.0, -54.0 + float(bob))).round()
	var fade_alpha: float = 1.0
	if time >= BLACK_END:
		fade_alpha = 1.0 - smoothstep(BLACK_END, FADE_END, time)
	_fade.color = Color(BLACK, clampf(fade_alpha, 0.0, 1.0))
	_fade.visible = fade_alpha > 0.001

	var dust_alpha: float = 0.0
	if time < 0.8:
		dust_alpha = clampf(time / 0.8, 0.0, 1.0)
	elif time < 4.0:
		dust_alpha = 1.0
	elif time < 5.2:
		dust_alpha = 1.0 - smoothstep(4.0, 5.2, time)
	_dust.visible = dust_alpha > 0.001
	_dust.queue_redraw()

	_vignette.visible = time < 8.0
	_vignette.queue_redraw()

	var shake: float = 0.0
	if time < BLACK_END:
		shake = 1.9
	elif time < TOUCH_TIME:
		shake = 0.75
	_shake_amplitude = shake
	var shake_x: float = roundf(sin(time * 37.0) * shake)
	var shake_y: float = roundf(sin(time * 53.0 + 1.2) * shake * 0.7)
	_dust.position = Vector2(shake_x, shake_y)

	_page_pulse = maxf(0.0, _page_pulse - delta * 3.0)
	var base: Vector2 = WIDE_CAMERA
	var zoom: float = 1.0
	if time >= ENTER_END:
		var p: float = smoothstep(ENTER_END, TOUCH_TIME, time)
		base = WIDE_CAMERA.lerp(CLOSE_CAMERA, p)
		zoom = lerpf(1.0, CLOSE_ZOOM, p)
	if time >= CORE_HANDOFF_TIME:
		var q: float = smoothstep(CORE_HANDOFF_TIME, ZOOM_OUT_END, time)
		base = CLOSE_CAMERA.lerp(_gameplay_camera_center(), q)
		zoom = lerpf(CLOSE_ZOOM, 1.0, q)
	if _opening_camera != null:
		_opening_camera.zoom = Vector2(zoom, zoom)
		_opening_camera.position = (base + Vector2(shake_x, shake_y)).round()

	# The DS03 background is a screen-fixed CanvasLayer. Scale it by the same
	# camera zoom around the screen centre so the whole picture reads as one
	# optical push, not only the foreground. The shake offset is added here too,
	# but never to the letterbox or footer.
	if _background != null:
		_background.scale = Vector2(zoom, zoom)
		_background.position = Vector2(
			VIEW_SIZE.x * 0.5 * (1.0 - zoom),
			VIEW_SIZE.y * 0.5 * (1.0 - zoom)
		) + Vector2(float(shake_x), float(shake_y))

	var bar_height: float = LETTERBOX_HEIGHT
	if time >= CORE_HANDOFF_TIME:
		bar_height = LETTERBOX_HEIGHT * (
			1.0 - smoothstep(CORE_HANDOFF_TIME, ZOOM_OUT_END, time)
		)
	_apply_letterbox(bar_height)

	if time >= ECHO_FORM_START:
		var echo_alpha: float = smoothstep(ECHO_FORM_START, ECHO_FORM_END, time) * 0.78
		echo_alpha *= 1.0 - 0.18 * _page_pulse
		if time >= CORE_TIME:
			echo_alpha *= 1.0 - smoothstep(CORE_TIME + 0.15, CORE_TIME + 1.30, time)
		if _echo_projection != null:
			_echo_projection.modulate.a = clampf(echo_alpha, 0.0, 0.78)

	if _stele_glow != null:
		if time < TOUCH_TIME:
			_stele_glow.set_state(0.0, 0.0)
		elif not _core_started:
			var reveal: float = smoothstep(TOUCH_TIME, TOUCH_TIME + 0.75, time)
			var page_intensity: float = 1.0 if time < ECHO_FORM_START else 0.62
			_stele_glow.set_state(reveal, page_intensity)
		elif not _core_landed:
			_stele_glow.set_state(1.0, 1.0)
		else:
			# _update_core owns the settled value after the core lands.
			pass

	_update_touch_spark(time)


func _update_touch_spark(time: float) -> void:
	if _touch_spark == null:
		return
	var show: bool = time >= TOUCH_TIME and time < TOUCH_TIME + 0.55
	_touch_spark.visible = show
	if show:
		_touch_spark.queue_redraw()


func _draw_dust(canvas: CanvasItem) -> void:
	if _dust == null or not _dust.visible:
		return
	var total: int = 72
	for index: int in range(total):
		var speed: float = 2.0 + float(index % 5) * 1.1
		var x: float = fmod(float(index) * 53.0 + _elapsed * speed, VIEW_SIZE.x + 20.0) - 10.0
		var y: float = fmod(float(index) * 31.0 + _elapsed * (0.7 + float(index % 3) * 0.35), VIEW_SIZE.y + 12.0) - 6.0
		var alpha: float = (0.20 + 0.24 * absf(sin(_elapsed * 0.9 + float(index)))) * 0.80
		var color: Color = Color(DUST_COLOR, alpha)
		if index % 4 == 0:
			canvas.draw_rect(Rect2(floorf(x), floorf(y), 2.0, 1.0), color)
		elif index % 9 == 0:
			canvas.draw_rect(Rect2(floorf(x), floorf(y), 1.0, 2.0), color)
		else:
			canvas.draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), color)


func _draw_vignette(canvas: CanvasItem) -> void:
	if _vignette == null or not _vignette.visible:
		return
	for index: int in range(4):
		var thickness: float = 10.0 + float(index) * 9.0
		var alpha: float = 0.055 - float(index) * 0.011
		canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, thickness), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(
			Rect2(0.0, VIEW_SIZE.y - thickness, VIEW_SIZE.x, thickness),
			Color(0.0, 0.0, 0.0, alpha)
		)
		canvas.draw_rect(Rect2(0.0, 0.0, thickness, VIEW_SIZE.y), Color(0.0, 0.0, 0.0, alpha))
		canvas.draw_rect(
			Rect2(VIEW_SIZE.x - thickness, 0.0, thickness, VIEW_SIZE.y),
			Color(0.0, 0.0, 0.0, alpha)
		)


func _draw_touch_spark(canvas: CanvasItem) -> void:
	if _touch_spark == null or not _touch_spark.visible or _player == null:
		return
	var time: float = clampf((_elapsed - TOUCH_TIME) / 0.85, 0.0, 1.0)
	var alpha: float = (1.0 - time) * 1.0
	var hand: Vector2 = _player.global_position + Vector2(-12.0, -21.0)
	var contact: Vector2 = Vector2(264.0, 274.0)
	canvas.draw_line(hand, contact, Color(1.0, 0.95, 0.70, alpha), 2.0)
	canvas.draw_rect(
		Rect2(contact - Vector2(2.0, 2.0), Vector2(4.0, 4.0)),
		Color(1.0, 0.99, 0.88, alpha)
	)
	canvas.draw_rect(
		Rect2(contact - Vector2(1.0, 3.0), Vector2(2.0, 6.0)),
		Color(1.0, 0.88, 0.48, alpha * 0.9)
	)
	for index: int in range(6):
		var direction: Vector2 = Vector2(
			cos(float(index) * TAU / 6.0 + 0.25),
			sin(float(index) * TAU / 6.0 + 0.25)
		)
		canvas.draw_line(
			contact + direction * 3.0,
			contact + direction * (5.0 + time * 7.0),
			Color(GOLD, alpha * 0.85),
			1.0
		)


func _gameplay_camera_center() -> Vector2:
	if _player == null or _player_camera == null:
		return VIEW_CENTER
	var half: Vector2 = VIEW_SIZE * 0.5
	var zoom: Vector2 = _player_camera.zoom
	if zoom.x != 0.0:
		half.x /= zoom.x
	if zoom.y != 0.0:
		half.y /= zoom.y
	var target: Vector2 = _player.global_position
	return Vector2(
		clampf(target.x, float(_player_camera.limit_left) + half.x, float(_player_camera.limit_right) - half.x),
		clampf(target.y, float(_player_camera.limit_top) + half.y, float(_player_camera.limit_bottom) - half.y)
	)


# --- return / finish / skip -------------------------------------------------


func _update_return(time: float) -> void:
	if time >= RETURN_TIME and not _return_started:
		_return_started = true
		_play_cue("return", time, -14.0)
	if time >= HUD_RETURN_TIME and not _hud_returned:
		_hud_returned = true
		_hud.set_opening_active(false)
	if time >= ZOOM_OUT_END:
		_return_played = true


func _request_skip() -> void:
	if not _active:
		return
	_skipped = true
	_skip_count += 1
	_space_action_done = true
	_hide_prompt_footer()
	if _skip_bar != null:
		_skip_bar.hide_progress()
	if _echo != null:
		_echo.force_close()
	if _core != null:
		_core.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	if _touch_spark != null:
		_touch_spark.visible = false
	if _question != null:
		_question.visible = false
	_stele_touched = _elapsed >= TOUCH_TIME
	if _stele_glow != null:
		_stele_glow.set_state(1.0 if _stele_touched else 0.0, 0.40 if _stele_touched else 0.0)
	if _player != null:
		_player.global_position = Vector2(HANDOFF_X, 300.0)
		_player.velocity = Vector2.ZERO
		_player.set_input_override_axis(0.0, false)
	_update_visuals(HANDOFF_TIME, 0.0)
	_finish_now(true)


func _complete_finish() -> void:
	if not _active:
		return
	_finish_now(_skipped)


func _finish_now(skipped: bool) -> void:
	if not _active and not _await_release:
		return
	_active = false
	_phase = Phase.IDLE
	_skipped = skipped
	_hide_prompt_footer()
	if _skip_bar != null:
		_skip_bar.hide_progress()
	if _echo != null:
		_echo.force_close()
		_echo.set_cinematic_owned(true)
	if _echo_projection != null:
		_echo_projection.modulate.a = 0.0
	if _core != null:
		_core.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	if _touch_spark != null:
		_touch_spark.visible = false
	if _question != null:
		_question.visible = false
	if _stele_glow != null:
		if _stele_touched:
			_stele_glow.set_state(1.0, 0.65)
		else:
			_stele_glow.set_state(0.0, 0.0)
	_hud.set_opening_active(false)
	_hud.visible = true

	_opening_camera.enabled = false
	_opening_camera.zoom = Vector2.ONE
	_player_camera.enabled = true
	_player_camera.make_current()
	_player_camera.reset_smoothing()
	_opening_camera.position = _gameplay_camera_center()
	if _background != null:
		_background.scale = Vector2.ONE
		_background.position = Vector2.ZERO
	if _echo_projection_node != null:
		_echo_projection_node.position = Vector2(0.0, -18.0)
	_apply_letterbox(0.0)
	if _top_bar != null:
		_top_bar.visible = false
	if _bottom_bar != null:
		_bottom_bar.visible = false

	_ui.visible = false
	_fade.visible = false
	_dust.visible = false
	_vignette.visible = false
	_stop_audio()

	if _touch_pose_started and _player != null:
		_touch_pose_started = false
		_touch_pose_done = true
		_player.end_showcase()

	if _space_held or Input.is_physical_key_pressed(KEY_SPACE):
		_await_release = true
		_phase = Phase.AWAIT_RELEASE
		set_process(true)
		set_process_unhandled_input(true)
		set_physics_process(false)
		return
	_await_release = false
	if _player != null:
		_player.end_input_override()
	set_physics_process(false)
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(_skipped)


func _complete_handoff() -> void:
	if not _await_release:
		return
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	if _player != null:
		_player.set_input_override_axis(0.0, false)
		_player.end_input_override()
	set_process(false)
	set_process_unhandled_input(false)
	set_physics_process(false)
	finished.emit(_skipped)


func abort() -> void:
	if not _active and not _await_release:
		return
	var was_active: bool = _active or _await_release
	_active = false
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_skipped = false
	_hide_prompt_footer()
	if _skip_bar != null:
		_skip_bar.hide_progress()
	if _echo != null:
		_echo.force_close()
		_echo.set_cinematic_owned(true)
	if _echo_projection != null:
		_echo_projection.modulate.a = 0.0
	if _core != null:
		_core.visible = false
	if _core_glow != null:
		_core_glow.visible = false
	if _touch_spark != null:
		_touch_spark.visible = false
	if _question != null:
		_question.visible = false
	if _stele_glow != null:
		_stele_glow.set_state(0.0, 0.0)
	if _player != null:
		if _touch_pose_started:
			_touch_pose_started = false
			_touch_pose_done = true
			_player.end_showcase()
		_player.global_position = _pre_player_position
		_player.velocity = Vector2.ZERO
		_player.set_facing_direction(_pre_facing)
		_player.set_input_override_axis(0.0, false)
		_player.end_input_override()
	if _opening_camera != null:
		_opening_camera.enabled = false
		_opening_camera.zoom = Vector2.ONE
	if _background != null:
		_background.scale = Vector2.ONE
		_background.position = Vector2.ZERO
	if _echo_projection_node != null:
		_echo_projection_node.position = Vector2(0.0, -18.0)
	_apply_letterbox(0.0)
	if _top_bar != null:
		_top_bar.visible = false
	if _bottom_bar != null:
		_bottom_bar.visible = false
	if _player_camera != null:
		_player_camera.enabled = true
		_player_camera.make_current()
		_player_camera.reset_smoothing()
	if _hud != null:
		_hud.set_opening_active(false)
		_hud.visible = true
	_ui.visible = false
	_fade.visible = false
	_dust.visible = false
	_vignette.visible = false
	_stop_audio()
	set_process(false)
	set_process_unhandled_input(false)
	set_physics_process(false)
	if was_active:
		aborted.emit()


func handle_pause_opened() -> void:
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_hide_prompt_footer()
	_set_audio_paused(true)
	if _active or _await_release:
		if _player != null:
			_player.begin_input_override()
			_player.set_input_override_axis(0.0, false)


func handle_pause_resumed() -> void:
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	if _skip_bar != null:
		_skip_bar.hide_progress()
	_set_audio_paused(false)
	if not (_active or _await_release) or _player == null:
		return
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)
	if _await_release and not Input.is_physical_key_pressed(KEY_SPACE):
		_complete_handoff()


func handle_focus_lost() -> void:
	abort()


# --- input ------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not (_active or _await_release):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.echo:
		return
	var physical: int = int(key_event.physical_keycode)
	if physical == 0:
		physical = int(key_event.keycode)

	if physical == int(KEY_F) or key_event.is_action_pressed(&"tutorial_next"):
		if key_event.pressed and not _await_release:
			_request_skip()
		get_viewport().set_input_as_handled()
		return

	if physical != int(KEY_SPACE):
		return
	if _await_release:
		if not key_event.pressed:
			_space_held = false
			if not Input.is_physical_key_pressed(KEY_SPACE):
				_complete_handoff()
			get_viewport().set_input_as_handled()
		return
	if key_event.pressed:
		_space_held = true
		_space_time = 0.0
		_space_action_done = false
		get_viewport().set_input_as_handled()
	else:
		_space_held = false
		_space_time = 0.0
		if _skip_bar != null:
			_skip_bar.hide_progress()
		get_viewport().set_input_as_handled()


# --- page footer ------------------------------------------------------------


func _update_skip_bar() -> void:
	if _skip_bar == null:
		return
	if not _active or _space_action_done or _await_release:
		_skip_bar.hide_progress()
		return
	_skip_bar.update_hold(_space_held, _space_time, SKIP_HOLD)


func _update_prompt_footer() -> void:
	if _prompt_footer == null:
		return
	var waiting: bool = (
		_active
		and _phase == Phase.DIALOGUE
		and _dialogue_started
		and _echo != null
		and _echo.is_dialogue_open()
		and _echo.get_page_count() > 0
		and not (_skip_bar != null and _skip_bar.visible)
	)
	if waiting:
		var index: int = _echo.get_page_index()
		var full: String = _echo.get_full_page_text()
		if index < 0 or full.is_empty() or _echo.get_revealed_count() < full.length():
			waiting = false
		else:
			var text: String = (
				PROMPT_FOOTER_SCRIPT.PAGE_FOOTER
				if index + 1 < _echo.get_page_count()
				else PROMPT_FOOTER_SCRIPT.SINGLE_FOOTER
			)
			_prompt_footer.call("show_footer", text)
	if not waiting:
		_prompt_footer.call("hide_footer")


func _hide_prompt_footer() -> void:
	if _prompt_footer != null:
		_prompt_footer.call("hide_footer")


# --- audio ------------------------------------------------------------------


func _prepare_audio_streams() -> void:
	_streams = {
		"rumble": SFX.low_rumble(),
		"wind": SFX.wind_loop(),
		"debris_a": SFX.debris(0),
		"debris_b": SFX.debris(1),
		"touch": SFX.stele_touch(),
		"whisper": SFX.echo_whisper(),
		"core_emerge": SFX.core_emerge(),
		"core_handoff": SFX.core_handoff(),
		"return": SFX.return_whoosh(),
	}


func _ensure_audio_players() -> void:
	if _voices.is_empty():
		for index: int in range(7):
			var voice: AudioStreamPlayer = AudioStreamPlayer.new()
			voice.name = "OpeningVoice%d" % (index + 1)
			voice.bus = &"Master"
			voice.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(voice)
			_voices.append(voice)
	if _wind_player == null:
		_wind_player = AudioStreamPlayer.new()
		_wind_player.name = "OpeningWind"
		_wind_player.bus = &"Master"
		_wind_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		_wind_player.stream = _streams.get("wind") as AudioStream
		_wind_player.volume_db = _wind_target_db
		add_child(_wind_player)
	if _rumble_player == null:
		_rumble_player = AudioStreamPlayer.new()
		_rumble_player.name = "OpeningRumble"
		_rumble_player.bus = &"Master"
		_rumble_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		_rumble_player.stream = _streams.get("rumble") as AudioStream
		_rumble_player.volume_db = -8.0
		add_child(_rumble_player)


func _start_audio() -> void:
	_ensure_audio_players()
	if _rumble_player != null and not _rumble_player.playing:
		_rumble_player.play()
	if _wind_player != null and not _wind_player.playing:
		_wind_player.volume_db = _wind_target_db
		_wind_player.play()
	_wind_current_db = _wind_target_db


func _tick_cues(time: float) -> void:
	if time >= 0.62:
		_play_cue("debris_a", time, -15.0)
	if time >= 1.52:
		_play_cue("debris_b", time, -16.0)
	if time >= TOUCH_TIME:
		_play_cue("touch", time, -7.0)
		if _rumble_player != null and _rumble_player.playing:
			_rumble_player.stop()
	if time >= ECHO_SOUND_TIME:
		_play_cue("whisper", time, -12.0)
	if time >= CORE_TIME:
		_play_cue("core_emerge", time, -10.0)
	if time >= CORE_TIME + 1.22:
		_play_cue("core_handoff", time, -9.0)
	if time >= RETURN_TIME:
		_play_cue("return", time, -14.0)
	var duck: bool = time >= TOUCH_TIME and time < CORE_TIME
	_wind_target_db = -38.0 if duck else -27.0
	_wind_current_db = move_toward(_wind_current_db, _wind_target_db, 10.0 * get_process_delta_time())
	if _wind_player != null:
		_wind_player.volume_db = _wind_current_db


func _play_cue(id: String, at_time: float, volume_db: float) -> void:
	if _played_cues.has(id) or _elapsed < at_time:
		return
	_played_cues[id] = true
	_cue_count += 1
	_play_stream(_streams.get(id) as AudioStream, volume_db)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	_ensure_audio_players()
	if _voices.is_empty():
		return
	var voice: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = _voices[_voice_cursor % _voices.size()]
		_voice_cursor += 1
		voice.stop()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


func _set_audio_paused(value: bool) -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice != null:
			voice.stream_paused = value
	if _wind_player != null:
		_wind_player.stream_paused = value
	if _rumble_player != null:
		_rumble_player.stream_paused = value


func _stop_audio() -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice != null:
			voice.stop()
			voice.stream = null
	if _wind_player != null:
		_wind_player.stop()
	if _rumble_player != null:
		_rumble_player.stop()


func _exit_tree() -> void:
	_stop_audio()


# --- read-only state --------------------------------------------------------


func is_active() -> bool:
	return _active or _await_release


func is_playing() -> bool:
	return _active


func is_awaiting_release() -> bool:
	return _await_release


func get_phase_name() -> String:
	match _phase:
		Phase.IDLE:
			return "IDLE"
		Phase.BLACK:
			return "BLACK"
		Phase.FADE_IN:
			return "FADE_IN"
		Phase.ENTER:
			return "ENTER"
		Phase.TOUCH:
			return "TOUCH"
		Phase.DIALOGUE:
			return "DIALOGUE"
		Phase.CORE:
			return "CORE"
		Phase.RETURN:
			return "RETURN"
		Phase.AWAIT_RELEASE:
			return "AWAIT_RELEASE"
		_:
			return "UNKNOWN"


func get_elapsed() -> float:
	return _elapsed


func get_duration() -> float:
	return DURATION


func get_play_count() -> int:
	return _play_count


func get_skip_count() -> int:
	return _skip_count


func is_skipped() -> bool:
	return _skipped


func get_space_hold_time() -> float:
	return _space_time


func get_cue_count() -> int:
	return _cue_count


func is_ui_visible() -> bool:
	return _ui != null and _ui.visible


func get_dialogue_echo() -> GuideEcho:
	return _echo


func get_prompt_footer() -> Control:
	return _prompt_footer


func is_prompt_footer_visible() -> bool:
	return _prompt_footer != null and _prompt_footer.visible


func get_prompt_footer_text() -> String:
	if _prompt_footer == null:
		return ""
	return String(_prompt_footer.call("get_text"))


func is_skip_bar_visible() -> bool:
	return _skip_bar != null and _skip_bar.visible


func get_skip_bar_progress() -> float:
	return _skip_bar.get_progress() if _skip_bar != null else 0.0


func get_skip_bar_fill_width() -> float:
	return _skip_bar.get_fill_width() if _skip_bar != null else 0.0


func get_skip_bar_rect() -> Rect2:
	return _skip_bar.get_bar_rect() if _skip_bar != null else Rect2()


func get_skip_bar_label_text() -> String:
	return _skip_bar.get_label_text() if _skip_bar != null else ""


func get_skip_bar_label_rect() -> Rect2:
	return _skip_bar.get_label_rect() if _skip_bar != null else Rect2()


func get_skip_bar_label_font_size() -> int:
	return _skip_bar.get_label_font_size() if _skip_bar != null else 0


func get_skip_bar_style() -> StyleBoxFlat:
	return _skip_bar.get_style() if _skip_bar != null else null


func get_stop_position_x() -> float:
	return HANDOFF_X


func get_opening_start_x() -> float:
	return ENTRY_POSITION.x


func get_step_count() -> int:
	return 0


func is_skip_queued() -> bool:
	return false


func get_shake_amplitude() -> float:
	return _shake_amplitude


func get_core_handoff_count() -> int:
	return _core_handoff_count


func has_touched_stele() -> bool:
	return _stele_touched


func is_question_visible() -> bool:
	return _question != null and _question.visible


func is_echo_visible() -> bool:
	return _echo_projection != null and _echo_projection.modulate.a > 0.01


func get_echo_alpha() -> float:
	return _echo_projection.modulate.a if _echo_projection != null else 0.0


func get_camera_zoom() -> float:
	return _opening_camera.zoom.x if _opening_camera != null else 1.0


func is_letterbox_visible() -> bool:
	return (
		_top_bar != null
		and _top_bar.visible
		and _letterbox_height > 0.5
	)


func get_letterbox_height() -> float:
	return _letterbox_height


func was_question_seen() -> bool:
	return _question_seen


func get_doubt_start_x() -> float:
	return _doubt_start_x


func get_doubt_peak_offset() -> float:
	return _doubt_peak_offset


func get_opening_camera() -> Camera2D:
	return _opening_camera


func get_stele_glow() -> OpeningSteleGlow:
	return _stele_glow
