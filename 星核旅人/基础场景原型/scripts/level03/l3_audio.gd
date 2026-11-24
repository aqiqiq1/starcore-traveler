extends Node

## Tiny event-driven sound bank for level 03. Every stream is a real file copied
## into the runtime assets/ folders; no preview path is read at runtime.
##
## Approved-to-try: charge v2, slam v5. The float / seat files are still
## candidates and are marked TEMPORARY in the report and credits. The
## reassembly path now points to the 0.60 s CC0-derived A trial in
## assets/audio_movement_20261117/; the other file paths and volumes are
## unchanged. The old audio_reassemble.ogg remains as an audition reference.

## Streams are loaded lazily and held only by the players (not by script
## constants): a preloaded const keeps the Ogg stream and its packet sequence
## alive past scene teardown, which shows up as an ObjectDB/resource leak at
## process exit. The files and volume levels are otherwise unchanged.
const CHARGE_PATH: String = "res://assets/level03_prototype/audio_charge.ogg"
const SLAM_PATH: String = "res://assets/level03_prototype/audio_slam.ogg"
const REASSEMBLE_PATH: String = "res://assets/audio_movement_20261117/reassembly_a_reverse.wav"
const FLOAT_WARN_PATH: String = "res://assets/level03_prototype/audio_float_warn.ogg"
const FLOAT_SETTLE_PATH: String = "res://assets/level03_prototype/audio_float_settle.ogg"
const CORE_SEAT_PATH: String = "res://assets/level03_prototype/audio_core_seat.ogg"

var _charge: AudioStreamPlayer
var _slam: AudioStreamPlayer
var _reassemble: AudioStreamPlayer
var _float_warn: AudioStreamPlayer
var _float_settle: AudioStreamPlayer
var _core_seat: AudioStreamPlayer
var _stone_cue: AudioStreamPlayer
var _charge_tween: Tween = null
var _last_played: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_charge = _make_player("Charge", CHARGE_PATH, -6.0)
	_slam = _make_player("Slam", SLAM_PATH, -1.5)
	_reassemble = _make_player("Reassemble", REASSEMBLE_PATH, -4.0)
	_float_warn = _make_player("FloatWarn", FLOAT_WARN_PATH, -10.0)
	_float_settle = _make_player("FloatSettle", FLOAT_SETTLE_PATH, -11.0)
	_core_seat = _make_player("CoreSeat", CORE_SEAT_PATH, -5.0)
	# Short "stone has shifted" attention cue for the near-gate cinematic when
	# the guard is alive but not currently rebuilding. It deliberately reuses
	# the already-credited float-settle candidate instead of inventing a new
	# reassemble sound; a real rebuild keeps its own reassembly event.
	_stone_cue = _make_player("StoneCue", FLOAT_SETTLE_PATH, -10.0)


func _make_player(player_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	# CACHE_MODE_IGNORE: the cue stream must not stay in the global resource
	# cache after the level is torn down, otherwise its Ogg packet sequence and
	# playback are reported as leaked at process exit.
	player.stream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
	player.volume_db = volume_db
	player.bus = &"Master"
	add_child(player)
	return player


func play_charge() -> void:
	_stop_charge_tween()
	if _charge == null:
		return
	_charge.volume_db = -6.0
	_charge.play()
	_last_played = "charge"


func stop_charge(fade: float = 0.12) -> void:
	if _charge == null or not _charge.playing:
		return
	if fade <= 0.0:
		_charge.stop()
		return
	_stop_charge_tween()
	_charge_tween = create_tween()
	_charge_tween.tween_property(_charge, "volume_db", -40.0, fade)
	_charge_tween.tween_callback(_charge.stop)


func _stop_charge_tween() -> void:
	if _charge_tween != null and _charge_tween.is_valid():
		_charge_tween.kill()
	_charge_tween = null


func play_slam() -> void:
	_play_one(_slam, "slam")


func play_reassemble() -> void:
	_play_one(_reassemble, "reassemble")


func play_float_warn() -> void:
	_play_one(_float_warn, "float_warn")


func play_float_settle() -> void:
	_play_one(_float_settle, "float_settle")


func play_core_seat() -> void:
	_play_one(_core_seat, "core_seat")


func play_stone_cue() -> void:
	_play_one(_stone_cue, "stone_cue")


func _play_one(player: AudioStreamPlayer, tag: String) -> void:
	if player == null:
		return
	player.play()
	_last_played = tag


func stop_all() -> void:
	_stop_charge_tween()
	for player: AudioStreamPlayer in [_charge, _slam, _reassemble, _float_warn, _float_settle, _core_seat, _stone_cue]:
		if player != null:
			player.stop()


## Test/tear-down only: stop every cue and drop the stream references so the
## exit report has no live playback or stream held by this node.
func release_streams() -> void:
	stop_all()
	for player: AudioStreamPlayer in [_charge, _slam, _reassemble, _float_warn, _float_settle, _core_seat, _stone_cue]:
		if player != null:
			player.stream = null


func get_last_played() -> String:
	return _last_played


## Audit-only reset so a focused test can tell whether *this* branch emitted a
## cue instead of inheriting the previous section's last tag.
func reset_last_played() -> void:
	_last_played = ""


func is_charge_playing() -> bool:
	return _charge != null and _charge.playing
