extends Node

## Demo-only, event-driven SFX bank shared by the three formal levels.
##
## Scope: nine already-recorded offline candidates (UI / core take / core seat /
## link / player hurt / gate / complete / failure / respawn) plus the three
## approved CC0-derived sounds (Q phase change / J swing / heavy shell shatter)
## wired into existing gameplay events. No music is started: the two BGM tracks
## stay local audition copies only.
##
## Technical rules kept deliberately small:
##   - no new bus layout; every player uses the existing Master bus, so the
##     existing master-volume slider (0 % -> mute) controls all of this audio;
##   - bounded player pools (world 6, UI 4) instead of one node per event, so
##     repeated cues can never accumulate players; the oldest slot is reused;
##   - world players are PAUSABLE (they freeze with the scene tree), UI players
##     are ALWAYS (a menu confirmation is still heard behind the pause page);
##   - streams are loaded lazily with CACHE_MODE_IGNORE and only held by the
##     players, mirroring l3_audio.gd's teardown behaviour.
##
## Nothing here decides composition, mixing or approval: the files are demo
## trials, not a listening verdict.

const RUNTIME_DIR: String = "res://assets/audio_demo_v2_20261116/"
const DIALOGUE_AUDIO_DIR: String = "res://assets/dialogue_feedback_20261117/"
## 2026-11-27 polarity-switch replacement.  The old
## assets/audio_demo_v2_20261116/polarity_switch.wav stays on disk untouched;
## only this event points at the v2 file.  play_polarity_switch() is unchanged.
const POLARITY_SWITCH_DIR: String = "res://assets/audio/sfx/"
## Until the v2 switch cue is delivered, the approved v1 cue keeps the base
## levels audible instead of going silent.
const POLARITY_SWITCH_FALLBACK: String = "res://assets/audio_demo_v2_20261116/polarity_switch.wav"
## Trial install (user-approved direction): total +3.5 st from the approved
## player_hurt_vocal source, same 120 Hz high-pass, no volume increase.
const HURT_YOUTH_DIR: String = "res://assets/experience_alignment_20261117/hurt_youth/"
const WORLD_POOL_SIZE: int = 6
const UI_POOL_SIZE: int = 4

const EVENT_UI_CLICK: String = "ui_click"
const EVENT_CORE_TAKE: String = "core_take"
const EVENT_CORE_SEAT: String = "core_seat"
const EVENT_LINK: String = "link"
const EVENT_PLAYER_HURT: String = "player_hurt"
const EVENT_RECORD_SAVE: String = "record_save"
const EVENT_GATE: String = "gate"
const EVENT_COMPLETE: String = "complete"
const EVENT_FAILURE: String = "failure"
const EVENT_RESPAWN: String = "respawn"
const EVENT_POLARITY_SWITCH: String = "polarity_switch"
const EVENT_SWING: String = "swing"
const EVENT_SHELL_SHATTER: String = "shell_shatter"

const EVENT_SPECS: Dictionary = {
	EVENT_UI_CLICK: {"file": "ui_confirm.wav", "volume_db": -10.0, "ui": true},
	EVENT_CORE_TAKE: {"file": "core_take.wav", "volume_db": -6.0, "ui": false},
	EVENT_CORE_SEAT: {"file": "core_seat.wav", "volume_db": -6.0, "ui": false},
	EVENT_LINK: {"file": "link_pulse.wav", "volume_db": -7.0, "ui": false},
	EVENT_PLAYER_HURT: {"dir": HURT_YOUTH_DIR, "file": "player_hurt_plus4st.wav", "volume_db": -3.0, "ui": false},
	EVENT_RECORD_SAVE: {"dir": DIALOGUE_AUDIO_DIR, "file": "record_confirm.wav", "volume_db": -3.0, "ui": false},
	EVENT_GATE: {"file": "gate_rise.wav", "volume_db": -10.0, "ui": false},
	EVENT_COMPLETE: {"file": "complete.wav", "volume_db": -4.0, "ui": false},
	EVENT_FAILURE: {"file": "failure.wav", "volume_db": -5.0, "ui": false},
	EVENT_RESPAWN: {"file": "respawn.wav", "volume_db": -6.0, "ui": false},
	EVENT_POLARITY_SWITCH: {
		"dir": POLARITY_SWITCH_DIR,
		"file": "polarity_switch_v2.wav",
		"volume_db": -6.0,
		"ui": false,
	},
	EVENT_SWING: {"file": "swing.wav", "volume_db": -6.0, "ui": false},
	EVENT_SHELL_SHATTER: {"file": "shell_shatter_heavy.wav", "volume_db": -3.0, "ui": false},
}

var _world_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _world_next: int = 0
var _ui_next: int = 0
var _streams: Dictionary = {}
var _play_counts: Dictionary = {}
var _last_event: String = ""


func _ready() -> void:
	# The service itself must stay reachable while the tree is paused so the
	# pause page can still ask for a UI click.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in range(WORLD_POOL_SIZE):
		_world_players.append(_make_player("WorldCue%d" % (index + 1), Node.PROCESS_MODE_PAUSABLE))
	for index: int in range(UI_POOL_SIZE):
		_ui_players.append(_make_player("UICue%d" % (index + 1), Node.PROCESS_MODE_ALWAYS))


func _make_player(player_name: String, mode: ProcessMode) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"Master"
	player.process_mode = mode
	add_child(player)
	return player


# --- Wired events ----------------------------------------------------------

func play_ui_click() -> bool:
	return _play_event(EVENT_UI_CLICK)


func play_core_take() -> bool:
	return _play_event(EVENT_CORE_TAKE)


func play_core_seat() -> bool:
	return _play_event(EVENT_CORE_SEAT)


func play_link() -> bool:
	return _play_event(EVENT_LINK)


func play_player_hurt() -> bool:
	return _play_event(EVENT_PLAYER_HURT)


func play_record_save() -> bool:
	return _play_event(EVENT_RECORD_SAVE)


func play_gate() -> bool:
	return _play_event(EVENT_GATE)


func play_complete() -> bool:
	return _play_event(EVENT_COMPLETE)


func play_failure() -> bool:
	return _play_event(EVENT_FAILURE)


func play_respawn() -> bool:
	return _play_event(EVENT_RESPAWN)


func play_polarity_switch() -> bool:
	return _play_event(EVENT_POLARITY_SWITCH)


func play_swing() -> bool:
	return _play_event(EVENT_SWING)


func play_shell_shatter() -> bool:
	return _play_event(EVENT_SHELL_SHATTER)


# --- Playback core ---------------------------------------------------------

func _play_event(event_name: String) -> bool:
	if not EVENT_SPECS.has(event_name):
		return false
	var stream: AudioStream = _stream_for(event_name)
	if stream == null:
		return false
	var spec: Dictionary = EVENT_SPECS[event_name]
	var player: AudioStreamPlayer = _pick_player(bool(spec.get("ui", false)))
	if player == null:
		return false
	player.stream = stream
	player.volume_db = float(spec.get("volume_db", -6.0))
	player.play()
	_play_counts[event_name] = int(_play_counts.get(event_name, 0)) + 1
	_last_event = event_name
	return true


func _stream_for(event_name: String) -> AudioStream:
	if _streams.has(event_name):
		return _streams[event_name] as AudioStream
	var path: String = get_event_stream_path(event_name)
	if not ResourceLoader.exists(path):
		if event_name == EVENT_POLARITY_SWITCH and ResourceLoader.exists(POLARITY_SWITCH_FALLBACK):
			path = POLARITY_SWITCH_FALLBACK
		else:
			push_warning("DemoAudio: missing stream %s" % path)
			_streams[event_name] = null
			return null
	var stream: AudioStream = load_stream_if_exists(path)
	_streams[event_name] = stream
	return stream


## Fixed path for an event (dir + file), exposed so tests and logs can print
## the exact resource the event will use.
func get_event_stream_path(event_name: String) -> String:
	if not EVENT_SPECS.has(event_name):
		return ""
	var spec: Dictionary = EVENT_SPECS[event_name]
	return String(spec.get("dir", RUNTIME_DIR)) + String(spec.get("file", ""))


## The path the switch cue will actually load: v2 when delivered, otherwise the
## v1 fallback so the base levels never lose the cue.
func get_polarity_switch_effective_path() -> String:
	var primary: String = get_event_stream_path(EVENT_POLARITY_SWITCH)
	if ResourceLoader.exists(primary):
		return primary
	return POLARITY_SWITCH_FALLBACK


## Existence-guarded loader shared by every event.  A missing file returns
## null; callers decide whether that is silence or a warning.
static func load_stream_if_exists(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as AudioStream


func _pick_player(ui: bool) -> AudioStreamPlayer:
	var pool: Array[AudioStreamPlayer] = _ui_players if ui else _world_players
	if pool.is_empty():
		return null
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	# Bounded fallback: reuse the next slot instead of creating another player.
	if ui:
		var ui_player: AudioStreamPlayer = pool[_ui_next % pool.size()]
		_ui_next = (_ui_next + 1) % pool.size()
		return ui_player
	var world_player: AudioStreamPlayer = pool[_world_next % pool.size()]
	_world_next = (_world_next + 1) % pool.size()
	return world_player


# --- Lifecycle / scene changes --------------------------------------------

## Called by each level on _exit_tree: world cues must not survive a scene
## change, while a short UI click may finish naturally.
func stop_world() -> void:
	for player: AudioStreamPlayer in _world_players:
		if player != null:
			player.stop()


func stop_all() -> void:
	stop_world()
	for player: AudioStreamPlayer in _ui_players:
		if player != null:
			player.stop()


## Test/teardown only: stop everything and drop the loaded streams so the exit
## report has no live playback or stream held by this service.
func release_streams() -> void:
	stop_all()
	for player: AudioStreamPlayer in _world_players + _ui_players:
		if player != null:
			player.stream = null
	_streams.clear()


# --- Introspection (tests / report, no gameplay effect) --------------------

func get_runtime_events() -> Array:
	return EVENT_SPECS.keys()


func get_play_count(event_name: String) -> int:
	return int(_play_counts.get(event_name, 0))


func get_total_play_count() -> int:
	var total: int = 0
	for value: Variant in _play_counts.values():
		total += int(value)
	return total


func get_last_event() -> String:
	return _last_event


func get_event_specs() -> Dictionary:
	return EVENT_SPECS.duplicate(true)


func get_world_pool_size() -> int:
	return _world_players.size()


func get_ui_pool_size() -> int:
	return _ui_players.size()


func get_active_world_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _world_players:
		if player != null and player.playing:
			count += 1
	return count


func get_active_ui_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _ui_players:
		if player != null and player.playing:
			count += 1
	return count


## True when every world player that is still playing is paused by the tree.
func is_world_paused() -> bool:
	for player: AudioStreamPlayer in _world_players:
		if player != null and player.playing and not player.stream_paused:
			return false
	return true


func get_paused_world_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _world_players:
		if player != null and player.stream_paused:
			count += 1
	return count


func get_paused_ui_count() -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _ui_players:
		if player != null and player.stream_paused:
			count += 1
	return count


func are_all_players_on_master() -> bool:
	for player: AudioStreamPlayer in _world_players + _ui_players:
		if player == null or player.bus != &"Master":
			return false
	return true


func reset_counts() -> void:
	_play_counts.clear()
	_last_event = ""
