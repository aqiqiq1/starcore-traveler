class_name PlayerFootstepAudio
extends Node

## Technical-only footstep phase helper for the three formal levels.
##
## This node does NOT play audio and does NOT own a stream, bank or bus. It reads
## only the player's public state (state name, animation frame, animation restart
## count, is_on_floor, input axis, global position) and emits a candidate signal
## when the walk/run animation enters a foot-contact frame while the player is
## really moving on the ground. The next stage can attach a small bank to the
## signal; a missing bank is never warned about here.
##
## Frame choice (project art, not an external reference conclusion):
##   walk: 10 frames @ 9 fps, contacts 0 and 5 (~0.556 s apart)
##   run:  10 frames @ 14 fps, contacts 1 and 6 (~0.357 s apart)
## The defaults are editable in the inspector; tests report the values actually
## used. `state_changed` is deliberately not used: it only fires on animation
## switches, not on every stepping frame.
##
## Guards (all from public player APIs / Node2D position):
##   - only "walk" or "run", on the floor, with a real input axis;
##   - actual horizontal displacement above a speed window + instant threshold,
##     so standing, wall push, jitter and platform carry without locomotion do
##     not fire;
##   - no input override (intro, cinematic, recovery, completion, menu lock),
##     no L3 hit reaction, no L3 completion lock;
##   - paused trees do not tick (attach_to inherits the player's process mode);
##   - a minimum interval prevents a switch/direction change from machine-gunning;
##   - the first sample of a new animation or an animation restart is a baseline,
##     not a step; a large teleport also resets the baseline.
##
## Lifecycle: `attach_to(player)` re-parents this node under the player, so it is
## freed with the player. No global singleton, autoload, input replacement or
## physics rewrite is involved.
##
## Small local bank: two AudioStreamPlayers on the existing Master bus (not the
## DemoAudio critical world pool). Six CC0 stone-step files rotate in fixed order
## for walk and run; walk is -18 dB / pitch 1.0, run is -15 dB / pitch 1.05. A
## missing file would only skip playback (the phase signal still fires) and is
## never warned about at runtime.

signal footstep_candidate(
	anim: StringName,
	frame: int,
	marker_index: int,
	world_position: Vector2,
	speed: float
)

const FOOTSTEP_DIR: String = "res://assets/audio_movement_20261117/"
const FOOTSTEP_FILES: Array[String] = [
	"footstep_stone_1.wav",
	"footstep_stone_2.wav",
	"footstep_stone_3.wav",
	"footstep_stone_4.wav",
	"footstep_stone_5.wav",
	"footstep_stone_6.wav",
]
const VOICE_COUNT: int = 2
const WALK_VOLUME_DB: float = -18.0
const RUN_VOLUME_DB: float = -15.0
const WALK_PITCH: float = 1.0
const RUN_PITCH: float = 1.05

@export var enabled: bool = true
## Foot-contact frames inside the current 10-frame walk/run sheets.
@export var walk_contact_frames: Array[int] = [0, 5]
@export var run_contact_frames: Array[int] = [1, 6]
## Locomotion intent, measured displacement and anti-machine-gun thresholds.
@export var min_input_axis: float = 0.12
@export var speed_window_s: float = 0.10
@export var min_speed: float = 25.0
@export var min_instant_speed: float = 15.0
@export var min_step_interval_s: float = 0.16
## A single-tick position jump larger than this is a setup/teleport, not a step.
@export var teleport_reset_distance: float = 40.0

var _player: Node2D = null
var _enabled_check: Callable = Callable()

var _last_anim: StringName = &""
var _last_frame: int = -1
var _last_restart: int = -1
var _last_x: float = 0.0
var _window_start_x: float = 0.0
var _window_elapsed: float = 0.0
var _speed_window: float = 0.0
var _instant_speed: float = 0.0
var _since_step: float = 999.0
var _step_count: int = 0
var _last_step_anim: StringName = &""
var _last_step_frame: int = -1
var _last_step_marker: int = -1
var _last_step_speed: float = 0.0
var _voices: Array[AudioStreamPlayer] = []
var _streams: Array[AudioStream] = []
var _voice_cursor: int = 0
var _next_variant: int = 0
var _last_variant: int = -1
var _played_count: int = 0
var _last_played_anim: StringName = &""
var _last_played_variant: int = -1
var _last_volume_db: float = 0.0
var _last_pitch_scale: float = 1.0
var _variant_history: Array[int] = []


func _ready() -> void:
	# The recommended attach path makes this node a child of the player, so
	# INHERIT follows the player's pausable/disabled state (menu, pause, etc.).
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	_build_voices()
	_ensure_streams()


func _build_voices() -> void:
	if not _voices.is_empty():
		return
	for index: int in range(VOICE_COUNT):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "FootstepVoice%d" % (index + 1)
		voice.bus = &"Master"
		# Explicit PAUSABLE: a tree pause freezes footstep tails even though the
		# helper itself inherits the player's process mode.
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_voices.append(voice)


func _ensure_streams() -> void:
	if _streams.size() == FOOTSTEP_FILES.size():
		return
	_streams.clear()
	for file_name: String in FOOTSTEP_FILES:
		var path: String = FOOTSTEP_DIR + file_name
		if not ResourceLoader.exists(path):
			# No runtime warning: the phase signal still works, and the next
			# stage can attach or replace the bank without a missing-asset spam.
			_streams.append(null)
			continue
		_streams.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream)


func _pick_voice() -> AudioStreamPlayer:
	if _voices.is_empty():
		return null
	for voice: AudioStreamPlayer in _voices:
		if voice != null and not voice.playing:
			return voice
	var fallback: AudioStreamPlayer = _voices[_voice_cursor % _voices.size()]
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	return fallback


func _play_step(anim: StringName) -> void:
	_ensure_streams()
	if _streams.is_empty():
		return
	var variant: int = _next_variant % _streams.size()
	if variant == _last_variant:
		variant = (variant + 1) % _streams.size()
	var stream: AudioStream = _streams[variant]
	if stream == null:
		return
	var voice: AudioStreamPlayer = _pick_voice()
	if voice == null:
		return
	if voice.playing:
		voice.stop()
	voice.stream = stream
	voice.volume_db = RUN_VOLUME_DB if anim == &"run" else WALK_VOLUME_DB
	voice.pitch_scale = RUN_PITCH if anim == &"run" else WALK_PITCH
	voice.play()
	_last_variant = variant
	_next_variant = (variant + 1) % _streams.size()
	_played_count += 1
	_last_played_anim = anim
	_last_played_variant = variant
	_last_volume_db = voice.volume_db
	_last_pitch_scale = voice.pitch_scale
	_variant_history.append(variant)


## Stop both bounded tails immediately (menu/recovery/completion entry).
func stop() -> void:
	for voice: AudioStreamPlayer in _voices:
		if voice != null:
			voice.stop()



# --- Binding / lifecycle ---------------------------------------------------

## Bind to a player without re-parenting. The caller owns this node's lifetime.
func bind_player(player: Node) -> bool:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return false
	for method_name: String in [
		"get_state_name", "get_anim_frame", "get_anim_frame_count",
		"get_move_input_axis", "is_on_floor",
	]:
		if not player.has_method(method_name):
			return false
	_player = player as Node2D
	reset_tracking()
	set_physics_process(true)
	return true


## Recommended: bind and become a child of the player, so freeing the player
## frees this helper. Calling it again with the same player is a no-op.
func attach_to(player: Node) -> bool:
	if not bind_player(player):
		return false
	var parent: Node = get_parent()
	if parent != _player:
		if parent != null:
			parent.remove_child(self)
		_player.add_child(self)
	process_mode = Node.PROCESS_MODE_INHERIT
	return true


func get_player() -> Node2D:
	return _player


func is_bound() -> bool:
	return _player != null and is_instance_valid(_player)


func _exit_tree() -> void:
	stop()
	_streams.clear()
	_player = null


# --- Enable gate -----------------------------------------------------------

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop()
		_sync_baseline()


func is_enabled() -> bool:
	return enabled


## Optional level-owned gate, e.g. "only while the current level is in normal
## gameplay". The callable must return bool. Invalid callables are ignored.
func set_enabled_check(check: Callable) -> void:
	_enabled_check = check


func clear_enabled_check() -> void:
	_enabled_check = Callable()


func _gate_allows() -> bool:
	if not enabled:
		return false
	if _enabled_check.is_valid():
		return bool(_enabled_check.call())
	return true


# --- Physics-time frame phase ---------------------------------------------

func _physics_process(delta: float) -> void:
	_since_step = minf(_since_step + delta, 999.0)
	if _player == null or not is_instance_valid(_player):
		return
	if get_tree().paused:
		return
	if not _gate_allows():
		stop()
		_sync_baseline()
		return

	var pos: Vector2 = _player.global_position
	var dx: float = pos.x - _last_x
	_instant_speed = absf(dx) / maxf(delta, 0.0001)
	if absf(dx) > teleport_reset_distance:
		# Setup/teleport, not a real locomotion tick. Never infer a step here.
		_sync_baseline()
		return

	_window_elapsed += delta
	_speed_window = absf(pos.x - _window_start_x) / maxf(_window_elapsed, 0.0001)
	if _window_elapsed >= speed_window_s:
		_window_start_x = pos.x
		_window_elapsed = 0.0
	_last_x = pos.x

	var state: StringName = StringName(String(_player.call("get_state_name")))
	var frame: int = int(_player.call("get_anim_frame"))
	var frame_count: int = int(_player.call("get_anim_frame_count"))
	var restart: int = 0
	if _player.has_method("get_anim_restart_count"):
		restart = int(_player.call("get_anim_restart_count"))

	# New animation or a restart: establish a baseline, do not emit the first
	# sample. This is what prevents a switch from producing a burst.
	if state != _last_anim or restart != _last_restart:
		_last_anim = state
		_last_frame = frame
		_last_restart = restart
		_reset_window(pos.x)
		return

	if frame == _last_frame:
		return

	var markers: Array[int] = _markers_for(state)
	var crossed: Array[int] = _crossed_markers(_last_frame, frame, frame_count, markers)
	_last_frame = frame
	if crossed.is_empty() or not _is_locomotion_tick():
		return

	# At most one step per physics tick; a huge frame skip must not stack two.
	for marker_frame: int in crossed:
		if _since_step < min_step_interval_s:
			break
		_emit_step(state, marker_frame, markers.find(marker_frame), pos)
		break


func _is_locomotion_tick() -> bool:
	if _player == null:
		return false
	if not bool(_player.call("is_on_floor")):
		return false
	if absf(float(_player.call("get_move_input_axis"))) < min_input_axis:
		return false
	if _player.has_method("is_input_override_active") \
			and bool(_player.call("is_input_override_active")):
		return false
	if _player.has_method("is_in_hit_reaction") \
			and bool(_player.call("is_in_hit_reaction")):
		return false
	if _player.has_method("is_completion_locked") \
			and bool(_player.call("is_completion_locked")):
		return false
	if _speed_window < min_speed:
		return false
	if _instant_speed < min_instant_speed:
		return false
	return true


func _emit_step(state: StringName, frame: int, marker_index: int, pos: Vector2) -> void:
	_since_step = 0.0
	_step_count += 1
	_last_step_anim = state
	_last_step_frame = frame
	_last_step_marker = marker_index
	_last_step_speed = _speed_window
	footstep_candidate.emit(state, frame, marker_index, pos, _speed_window)
	_play_step(state)


func _markers_for(state: StringName) -> Array[int]:
	if state == &"walk":
		return walk_contact_frames
	if state == &"run":
		return run_contact_frames
	return []


## Frames strictly after `last_frame` through `current_frame`, including a loop
## wrap. Marker frames are returned in the order the animation crossed them.
func _crossed_markers(
	last_frame: int, current_frame: int, frame_count: int, markers: Array[int]
) -> Array[int]:
	var result: Array[int] = []
	if frame_count <= 0 or markers.is_empty():
		return result
	var crossed_frames: Array[int] = []
	if current_frame >= last_frame:
		for f: int in range(last_frame + 1, current_frame + 1):
			crossed_frames.append(f)
	else:
		for f: int in range(last_frame + 1, frame_count):
			crossed_frames.append(f)
		for f: int in range(0, current_frame + 1):
			crossed_frames.append(f)
	for f: int in crossed_frames:
		if markers.has(f):
			result.append(f)
	return result


func _reset_window(x: float) -> void:
	_last_x = x
	_window_start_x = x
	_window_elapsed = 0.0
	_speed_window = 0.0
	_instant_speed = 0.0


func _sync_baseline() -> void:
	if _player == null or not is_instance_valid(_player):
		_last_anim = &""
		_last_frame = -1
		_last_restart = -1
		return
	_last_anim = StringName(String(_player.call("get_state_name")))
	_last_frame = int(_player.call("get_anim_frame"))
	_last_restart = 0
	if _player.has_method("get_anim_restart_count"):
		_last_restart = int(_player.call("get_anim_restart_count"))
	_reset_window(_player.global_position.x)


# --- Test / report accessors (no gameplay effect) --------------------------

func reset_tracking() -> void:
	_last_anim = &""
	_last_frame = -1
	_last_restart = -1
	_since_step = 999.0
	_step_count = 0
	_last_step_anim = &""
	_last_step_frame = -1
	_last_step_marker = -1
	_last_step_speed = 0.0
	if _player != null and is_instance_valid(_player):
		_last_anim = StringName(String(_player.call("get_state_name")))
		_last_frame = int(_player.call("get_anim_frame"))
		if _player.has_method("get_anim_restart_count"):
			_last_restart = int(_player.call("get_anim_restart_count"))
		_reset_window(_player.global_position.x)


func get_step_count() -> int:
	return _step_count


func get_last_step_anim() -> StringName:
	return _last_step_anim


func get_last_step_frame() -> int:
	return _last_step_frame


func get_last_step_marker() -> int:
	return _last_step_marker


func get_last_step_speed() -> float:
	return _last_step_speed


func get_since_last_step() -> float:
	return _since_step


func get_speed_window() -> float:
	return _speed_window


func get_instant_speed() -> float:
	return _instant_speed


func get_marker_frames(state: StringName) -> Array[int]:
	return _markers_for(state).duplicate()


func get_tracked_anim() -> StringName:
	return _last_anim


func get_tracked_frame() -> int:
	return _last_frame


# --- Local bank audit accessors (tests / report) ---------------------------

func get_voice_count() -> int:
	return _voices.size()


func get_variant_count() -> int:
	return FOOTSTEP_FILES.size()


func get_stream_paths() -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in FOOTSTEP_FILES:
		paths.append(FOOTSTEP_DIR + file_name)
	return paths


func is_bank_loaded() -> bool:
	if _streams.size() != FOOTSTEP_FILES.size():
		return false
	for stream: AudioStream in _streams:
		if stream == null:
			return false
	return true


func get_played_count() -> int:
	return _played_count


func get_last_played_anim() -> StringName:
	return _last_played_anim


func get_last_played_variant() -> int:
	return _last_played_variant


func get_last_volume_db() -> float:
	return _last_volume_db


func get_last_pitch_scale() -> float:
	return _last_pitch_scale


func get_variant_history() -> Array[int]:
	return _variant_history.duplicate()


func get_active_voice_count() -> int:
	var active: int = 0
	for voice: AudioStreamPlayer in _voices:
		if voice != null and voice.playing:
			active += 1
	return active


func get_paused_voice_count() -> int:
	var paused: int = 0
	for voice: AudioStreamPlayer in _voices:
		if voice != null and voice.stream_paused:
			paused += 1
	return paused


func are_voices_on_master() -> bool:
	for voice: AudioStreamPlayer in _voices:
		if voice == null or voice.bus != &"Master":
			return false
	return true

