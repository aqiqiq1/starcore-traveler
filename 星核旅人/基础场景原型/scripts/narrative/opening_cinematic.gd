class_name OpeningCinematic
extends Node

## Level-01 opening film, local to this level.
##
## It does not invent a camera move, a teleport or a new dialogue: the player
## really runs along the authored ground under the existing input-override
## rules, stops about 32 px left of the first GuideEcho, and the echo's own
## public page API opens the three existing pages (246x60 bubble, 34 cps).
##
## Presentation is the already-approved level-03 language: 44 px letterbox,
## Space short-press completes/advances, holding Space for 0.6 s skips, and
## control returns only after Space is released. The node is PAUSABLE, so the
## tree pause freezes its bar easing, hold timer and page reveal together.
##
## Footsteps: the shared footstep helper intentionally rejects scripted input
## overrides, so this controller reuses the same six existing CC0 stone-step
## files, run contact markers (1/6), volume (-15 dB) and pitch (1.05) for the
## scripted run only. No new audio source is introduced.

signal finished(skipped: bool)
signal aborted

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const BAR_HEIGHT: float = 44.0
const BAR_EASE_TIME: float = 0.3
const STOP_GAP: float = 32.0
## Set the axis to zero a few pixels early so the existing ground deceleration
## lands on the target instead of overshooting or being snapped there.
const BRAKE_LEAD: float = 8.0
const STOP_SETTLE_TIMEOUT: float = 0.8
const STOP_SPEED_EPSILON: float = 6.0
const DIALOGUE_OPEN_TIMEOUT: float = 1.0
const SKIP_HOLD: float = 0.6

const FOOTSTEP_DIR: String = "res://assets/audio_movement_20261117/"
const FOOTSTEP_FILES: Array[String] = [
	"footstep_stone_1.wav",
	"footstep_stone_2.wav",
	"footstep_stone_3.wav",
	"footstep_stone_4.wav",
	"footstep_stone_5.wav",
	"footstep_stone_6.wav",
]
const RUN_CONTACT_FRAMES: Array[int] = [1, 6]
const RUN_VOLUME_DB: float = -15.0
const RUN_PITCH: float = 1.05
const MIN_STEP_INTERVAL: float = 0.16

enum Phase { IDLE, BARS_IN, RUN, STOPPING, DIALOGUE, OUTRO, AWAIT_RELEASE }

var _level: Node = null
var _player: PrototypePlayer = null
var _echo: GuideEcho = null
var _hud: Level01HUD = null
var _run_ratio: float = 0.75

var _ui: CanvasLayer = null
var _root: Control = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _bar_height: float = 0.0

var _phase: Phase = Phase.IDLE
var _active: bool = false
var _await_release: bool = false
var _space_held: bool = false
var _space_time: float = 0.0
var _space_action_done: bool = false
var _skip_queued: bool = false
var _skipped: bool = false
var _elapsed: float = 0.0
var _phase_time: float = 0.0
var _run_timeout: float = 9.0
var _stop_x: float = 0.0
var _opening_start_x: float = 0.0
var _play_count: int = 0
var _dialogue_opened: bool = false
var _dialogue_attempting: bool = false

var _step_streams: Array[AudioStream] = []
var _step_voices: Array[AudioStreamPlayer] = []
var _step_cursor: int = 0
var _step_last_variant: int = -1
var _step_last_frame: int = -1
var _step_last_anim: StringName = &""
var _step_since: float = 999.0
var _step_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_ui()
	_apply_bar_height()
	set_process(false)
	set_process_unhandled_input(false)


func setup(level: Node, player: PrototypePlayer, echo: GuideEcho, hud: Level01HUD) -> void:
	_level = level
	_player = player
	_echo = echo
	_hud = hud
	if _level != null and _level.has_method("get_intro_run_speed_ratio"):
		_run_ratio = clampf(float(_level.call("get_intro_run_speed_ratio")), 0.5, 1.0)
	if _level != null and _level.has_method("get_intro_max_duration"):
		_run_timeout = maxf(float(_level.call("get_intro_max_duration")), 2.0)


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

	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(VIEW_SIZE.x, 0.0)
	_top_bar.color = Color(0.008, 0.014, 0.018, 0.96)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.position = Vector2(0.0, VIEW_SIZE.y)
	_bottom_bar.size = Vector2(VIEW_SIZE.x, 0.0)
	_bottom_bar.color = Color(0.008, 0.014, 0.018, 0.96)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom_bar)

	_ui.visible = false


func start() -> bool:
	if _active or _await_release:
		return false
	if _player == null or _echo == null or _hud == null:
		return false
	if _echo.get_page_count() <= 0:
		return false
	if _level != null and _level.has_method("get_intro_run_speed_ratio"):
		_run_ratio = clampf(float(_level.call("get_intro_run_speed_ratio")), 0.5, 1.0)
	if _level != null and _level.has_method("get_intro_max_duration"):
		_run_timeout = maxf(float(_level.call("get_intro_max_duration")), 2.0)

	_play_count += 1
	_active = true
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_skip_queued = false
	_skipped = false
	_elapsed = 0.0
	_phase_time = 0.0
	_dialogue_opened = false
	_dialogue_attempting = false
	_bar_height = 0.0
	_apply_bar_height()
	_opening_start_x = _player.global_position.x
	_stop_x = _echo.global_position.x - STOP_GAP

	# Real run, existing override rules: no teleport and no global Input press.
	_player.begin_input_override()
	_player.set_input_override_axis(0.0, false)

	_echo.force_close()
	_echo.set_cinematic_owned(true)
	_hud.set_opening_active(true)
	_hud.show_toast("", 0.0)

	_reset_step_tracking()
	_ui.visible = true
	_phase = Phase.BARS_IN
	set_process(true)
	set_process_unhandled_input(true)
	return true


func _process(delta: float) -> void:
	if not _active and not _await_release:
		return
	if get_tree() != null and get_tree().paused:
		return

	if _await_release:
		if not _space_held and not Input.is_physical_key_pressed(KEY_SPACE):
			_complete_handoff()
		return

	_elapsed += delta
	_phase_time += delta
	_update_bars(delta)

	if _space_held and not _space_action_done:
		_space_time += delta
		if _space_time >= SKIP_HOLD:
			_space_action_done = true
			_request_skip()

	match _phase:
		Phase.BARS_IN:
			if _phase_time >= BAR_EASE_TIME:
				_enter_run()
		Phase.RUN:
			_tick_footsteps(delta)
			if _player.global_position.x >= _stop_x - BRAKE_LEAD:
				_enter_stopping()
			elif _elapsed >= _run_timeout:
				abort()
		Phase.STOPPING:
			_tick_footsteps(delta)
			var stopped: bool = absf(_player.velocity.x) <= STOP_SPEED_EPSILON
			if (stopped and _phase_time >= 0.12) or _phase_time >= STOP_SETTLE_TIMEOUT:
				_enter_dialogue()
		Phase.DIALOGUE:
			if _skip_queued:
				_begin_outro(true)
			elif not _dialogue_attempting:
				_dialogue_opened = _echo.is_dialogue_open()
				if not _dialogue_opened:
					# The page can only close through our own advanced press or a
					# real external cleanup; both end the opening cleanly.
					_begin_outro(false)
		Phase.OUTRO:
			if _bar_height <= 0.05:
				_complete_finish()
		_:
			pass


func _enter_run() -> void:
	_phase = Phase.RUN
	_phase_time = 0.0
	if _player != null:
		_player.begin_input_override()
		_player.set_input_override_axis(_run_ratio, true)
	_reset_step_tracking()


func _enter_stopping() -> void:
	_phase = Phase.STOPPING
	_phase_time = 0.0
	_stop_local_footsteps()
	if _player != null:
		_player.set_input_override_axis(0.0, false)


func _enter_dialogue() -> void:
	_stop_local_footsteps()
	_phase = Phase.DIALOGUE
	_phase_time = 0.0
	_dialogue_attempting = true
	if _skip_queued:
		_dialogue_attempting = false
		_begin_outro(true)
		return
	if _echo == null:
		_dialogue_attempting = false
		abort()
		return
	if not _echo.open_dialogue():
		# The stop point is inside the echo's normal talk range; retry a moment
		# in case the manifestation fade has not caught up yet.
		var waited: float = 0.0
		while waited < DIALOGUE_OPEN_TIMEOUT:
			await get_tree().process_frame
			if not _active:
				return
			waited += get_process_delta_time()
			if _echo.open_dialogue():
				break
		if not _echo.is_dialogue_open():
			_dialogue_attempting = false
			abort()
			return
	_dialogue_attempting = false
	_dialogue_opened = true


func _request_skip() -> void:
	if _phase == Phase.BARS_IN or _phase == Phase.RUN or _phase == Phase.STOPPING:
		# Never cut away mid-run; the request waits for the safe stop.
		_skip_queued = true
	elif _phase == Phase.DIALOGUE:
		_begin_outro(true)
	# OUTRO/AWAIT_RELEASE already release on their own; a held key only delays
	# the hand-off until release, it does not rush the bar fade.

func _begin_outro(skipped: bool) -> void:
	if _phase == Phase.OUTRO or _phase == Phase.AWAIT_RELEASE:
		return
	_phase = Phase.OUTRO
	_phase_time = 0.0
	_skipped = skipped
	_stop_local_footsteps()
	if _echo != null:
		_echo.force_close()
	if _player != null:
		_player.set_input_override_axis(0.0, false)


func _update_bars(delta: float) -> void:
	var target: float = BAR_HEIGHT
	if _phase == Phase.OUTRO:
		target = 0.0
	var speed: float = BAR_HEIGHT / BAR_EASE_TIME
	_bar_height = move_toward(_bar_height, target, speed * delta)
	if _phase == Phase.BARS_IN:
		var t: float = clampf(_phase_time / BAR_EASE_TIME, 0.0, 1.0)
		# Same 0-44 px ease as the approved L3 bar, with a soft start/end.
		_bar_height = BAR_HEIGHT * (t * t * (3.0 - 2.0 * t))
	_apply_bar_height()


func _apply_bar_height() -> void:
	if _top_bar != null:
		_top_bar.size.y = _bar_height
	if _bottom_bar != null:
		_bottom_bar.position.y = VIEW_SIZE.y - _bar_height
		_bottom_bar.size.y = _bar_height


func _complete_finish() -> void:
	if not _active:
		return
	if _echo != null:
		_echo.force_close()
	_stop_local_footsteps()
	_ui.visible = false
	_bar_height = 0.0
	_apply_bar_height()
	_await_release = _space_held or Input.is_physical_key_pressed(KEY_SPACE)
	if _await_release:
		# Keep the movement override and the hidden objective until the same
		# Space press is released, so one long skip cannot become a jump.
		_phase = Phase.AWAIT_RELEASE
		return
	_complete_handoff()


func _complete_handoff() -> void:
	_await_release = false
	_active = false
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_phase = Phase.IDLE
	_ui.visible = false
	_bar_height = 0.0
	_apply_bar_height()
	_stop_local_footsteps()
	if _player != null:
		_player.end_input_override()
	if _echo != null:
		_echo.force_close()
		_echo.set_cinematic_owned(false)
	if _hud != null:
		_hud.set_opening_active(false)
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(_skipped)


func abort() -> void:
	if not _active and not _await_release:
		return
	_active = false
	_await_release = false
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_skip_queued = false
	_phase = Phase.IDLE
	_ui.visible = false
	_bar_height = 0.0
	_apply_bar_height()
	_stop_local_footsteps()
	if _player != null:
		_player.end_input_override()
	if _echo != null:
		_echo.force_close()
		_echo.set_cinematic_owned(false)
	if _hud != null:
		_hud.set_opening_active(false)
	set_process(false)
	set_process_unhandled_input(false)
	aborted.emit()


func handle_pause_opened() -> void:
	# The tree pause freezes our process, but the pause page also clears the
	# player buffers. Re-assert the opening lock so an unpause cannot leak real
	# input into a half-finished run, and drop any held Space latch.
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	_stop_local_footsteps()
	if not (_active or _await_release) or _player == null:
		return
	if _await_release:
		_player.begin_input_override()
		_player.set_input_override_axis(0.0, false)
		return
	_player.begin_input_override()
	if _phase == Phase.RUN:
		_player.set_input_override_axis(_run_ratio, true)
	else:
		_player.set_input_override_axis(0.0, false)


func handle_pause_resumed() -> void:
	_space_held = false
	_space_time = 0.0
	_space_action_done = false
	if not (_active or _await_release) or _player == null:
		return
	_player.begin_input_override()
	if _phase == Phase.RUN:
		_player.set_input_override_axis(_run_ratio, true)
	else:
		_player.set_input_override_axis(0.0, false)
	if _await_release and not Input.is_physical_key_pressed(KEY_SPACE):
		_complete_handoff()


func handle_focus_lost() -> void:
	# A lost window is a real abort, not a free skip: control is returned at the
	# current point and the opening is not marked as watched/complete.
	abort()


func _unhandled_input(event: InputEvent) -> void:
	if not (_active or _await_release):
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.echo:
		return
	if int(key_event.physical_keycode) != int(KEY_SPACE) \
			and int(key_event.keycode) != int(KEY_SPACE):
		return
	if key_event.pressed:
		if _await_release:
			get_viewport().set_input_as_handled()
			return
		_space_held = true
		_space_time = 0.0
		_space_action_done = false
		get_viewport().set_input_as_handled()
	else:
		if _await_release:
			_space_held = false
			if not Input.is_physical_key_pressed(KEY_SPACE):
				_complete_handoff()
			get_viewport().set_input_as_handled()
			return
		if (
			_space_held
			and not _space_action_done
			and _space_time < SKIP_HOLD
			and _phase == Phase.DIALOGUE
		):
			_echo.advance_page()
			if not _echo.is_dialogue_open():
				_begin_outro(false)
		_space_held = false
		get_viewport().set_input_as_handled()


# --- Existing stone-step bank, scripted run only ---------------------------

func _reset_step_tracking() -> void:
	_step_last_frame = -1
	_step_last_anim = &""
	_step_since = 999.0
	if _player != null:
		_step_last_anim = StringName(String(_player.get_state_name()))
		_step_last_frame = _player.get_anim_frame()


func _tick_footsteps(delta: float) -> void:
	_step_since = minf(_step_since + delta, 999.0)
	if _player == null:
		return
	var state: StringName = StringName(String(_player.get_state_name()))
	var frame: int = _player.get_anim_frame()
	if state != _step_last_anim:
		_step_last_anim = state
		_step_last_frame = frame
		return
	if frame == _step_last_frame:
		return
	var crossed: bool = false
	if state == &"run":
		var current: int = frame
		var last: int = _step_last_frame
		if current >= last:
			for f: int in range(last + 1, current + 1):
				if RUN_CONTACT_FRAMES.has(f):
					crossed = true
					break
		else:
			for f: int in range(last + 1, _player.get_anim_frame_count()):
				if RUN_CONTACT_FRAMES.has(f):
					crossed = true
					break
			if not crossed:
				for f: int in range(0, current + 1):
					if RUN_CONTACT_FRAMES.has(f):
						crossed = true
						break
	_step_last_frame = frame
	if not crossed:
		return
	if not _player.is_on_floor() or absf(_player.velocity.x) < 25.0:
		return
	if _step_since < MIN_STEP_INTERVAL:
		return
	_step_since = 0.0
	_play_step()


func _play_step() -> void:
	_ensure_step_bank()
	if _step_streams.is_empty():
		return
	var variant: int = _step_cursor % _step_streams.size()
	_step_cursor += 1
	if variant == _step_last_variant:
		variant = (variant + 1) % _step_streams.size()
	var stream: AudioStream = _step_streams[variant]
	if stream == null:
		return
	var voice: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in _step_voices:
		if candidate != null and not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = _step_voices[0] as AudioStreamPlayer
		if voice == null:
			return
		voice.stop()
	voice.stream = stream
	voice.volume_db = RUN_VOLUME_DB
	voice.pitch_scale = RUN_PITCH
	voice.play()
	_step_last_variant = variant
	_step_count += 1


func _ensure_step_bank() -> void:
	if _step_voices.is_empty():
		for index: int in range(2):
			var voice: AudioStreamPlayer = AudioStreamPlayer.new()
			voice.name = "OpeningStepVoice%d" % (index + 1)
			voice.bus = &"Master"
			voice.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(voice)
			_step_voices.append(voice)
	if _step_streams.size() == FOOTSTEP_FILES.size():
		return
	_step_streams.clear()
	for file_name: String in FOOTSTEP_FILES:
		var path: String = FOOTSTEP_DIR + file_name
		if not ResourceLoader.exists(path):
			_step_streams.append(null)
			continue
		_step_streams.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream)


func _stop_local_footsteps() -> void:
	for voice: AudioStreamPlayer in _step_voices:
		if voice != null:
			voice.stop()


# --- Read-only state for tests / captures ----------------------------------

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
		Phase.BARS_IN:
			return "BARS_IN"
		Phase.RUN:
			return "RUN"
		Phase.STOPPING:
			return "STOPPING"
		Phase.DIALOGUE:
			return "DIALOGUE"
		Phase.OUTRO:
			return "OUTRO"
		Phase.AWAIT_RELEASE:
			return "AWAIT_RELEASE"
		_:
			return "UNKNOWN"


func get_bar_height() -> float:
	return _bar_height


func get_stop_position_x() -> float:
	return _stop_x


func get_opening_start_x() -> float:
	return _opening_start_x


func get_elapsed() -> float:
	return _elapsed


func get_play_count() -> int:
	return _play_count


func get_step_count() -> int:
	return _step_count


func is_skip_queued() -> bool:
	return _skip_queued


func is_skipped() -> bool:
	return _skipped


func get_space_hold_time() -> float:
	return _space_time


func is_ui_visible() -> bool:
	return _ui != null and _ui.visible


func get_dialogue_echo() -> GuideEcho:
	return _echo
