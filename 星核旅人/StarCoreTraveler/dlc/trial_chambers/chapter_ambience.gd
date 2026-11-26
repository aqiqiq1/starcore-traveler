class_name DlcChapterAmbience
extends Node

## DLC chapter ambience player for 星核试炼场 / 裂隙工坊.
##
## The two tracks are produced by the separate music pass under
## res://dlc/audio/music/ (trial_ambience, rift_ambience).  This node resolves the
## file at runtime and prefers .ogg, then .wav, and stays silent (no player, no
## error) when neither exists yet.  Nothing is preloaded, so an absent or not yet
## imported track can never break the chapter, the editor import or the tests.
##
## Loop: the loop flag is set on a duplicate of the loaded stream only; the
## imported resource on disk is never mutated.  Both tracks are written as
## whole-loop music by the generator, so looping the full stream is seamless.
##
## Volume: -10 dB player gain.  The tracks peak at about -7.7 dBFS, so the
## audible peak lands near -18 dBFS under SFX (not the inaudible -27.7 that a
## literal -20 player gain produced).
##
## Pause: the player node is PROCESS_MODE_ALWAYS, so the intro guide and the
## mechanic popups (which pause the tree) keep the chapter music playing.  The
## pause page still explicitly sets stream_paused, so its frozen/resumed state
## is deterministic and testable.  Completion fades it out; returning to the
## title stops it; R plays it again from the first frame.

const MUSIC_DIRECTORY: String = "res://dlc/audio/music/"
const EXTENSIONS: Array[String] = [".ogg", ".wav"]
const TARGET_VOLUME_DB: float = -10.0
const SILENT_DB: float = -60.0
const STOP_FADE_SECONDS: float = 0.7
## A decoded stream shorter than this is treated as missing / not usable.
const MIN_STREAM_SECONDS: float = 0.25

@export var track_name: String = "trial_ambience"
@export var autoplay: bool = true

var _player: AudioStreamPlayer = null
var _stream: AudioStream = null
var _resolved_path: String = ""
var _paused: bool = false
var _stop_tween: Tween = null


func _ready() -> void:
	# Always: the guide and mechanic popups pause the tree but must not cut the
	# chapter music.  The pause page freezes playback explicitly in set_paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_stream()
	if autoplay:
		play()


func _exit_tree() -> void:
	_kill_stop_tween()
	_paused = false
	if _player != null:
		_player.stop()
		# Drop the stream reference so a chapter torn down (or the process
		# quitting) while the track is playing cannot leave the Ogg packet
		# sequence and its playback alive at exit.
		_player.stream = null
	_stream = null


# --- resolution -------------------------------------------------------------

## Loads the first usable .ogg/.wav for `track_name`.  Kept separate from
## _ready so a test can check the fallback path with a deliberately missing
## track without touching the real one.
func _resolve_stream() -> void:
	_resolved_path = ""
	_stream = null
	if track_name.is_empty():
		return
	for extension: String in EXTENSIONS:
		var candidate: String = MUSIC_DIRECTORY + track_name + extension
		if not ResourceLoader.exists(candidate):
			continue
		var loaded: Resource = ResourceLoader.load(
			candidate, "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if not (loaded is AudioStream):
			continue
		var stream: AudioStream = (loaded as AudioStream).duplicate() as AudioStream
		if stream == null:
			continue
		if stream.get_length() < MIN_STREAM_SECONDS:
			# A still-being-written or empty encode is not ambient music.
			continue
		_apply_loop(stream)
		_stream = stream
		_resolved_path = candidate
		return


func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = maxi(int(round(wav.get_length() * float(wav.mix_rate))), 1)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _ensure_player() -> void:
	if _stream == null:
		return
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "AmbiencePlayer"
		_player.stream = _stream
		_player.volume_db = TARGET_VOLUME_DB
		_player.bus = &"Master"
		# Explicit even though the parent is ALWAYS: the test asserts the node's
		# own mode and the guide/popup playback path.
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_player)


# --- playback ---------------------------------------------------------------

## Starts (or restarts) the track.  from_start = false only resumes if the
## player was paused; the default is a clean restart, used by the chapter start
## and by R.
func play(from_start: bool = true) -> void:
	_ensure_player()
	if _player == null:
		return
	_kill_stop_tween()
	_player.volume_db = TARGET_VOLUME_DB
	_paused = false
	_player.stream_paused = false
	if from_start or not _player.playing:
		_player.play()


func set_paused(value: bool) -> void:
	_paused = value
	if _player != null:
		_player.stream_paused = value


## Stops immediately (fade_time = 0) or fades out first.  The fade is only used
## on the completion page; a scene change stops immediately.
func stop(fade_time: float = 0.0) -> void:
	_paused = false
	if _player == null:
		return
	_player.stream_paused = false
	_kill_stop_tween()
	if not _player.playing:
		_player.volume_db = TARGET_VOLUME_DB
		return
	if fade_time <= 0.0 or not is_inside_tree():
		_player.stop()
		_player.volume_db = TARGET_VOLUME_DB
		return
	_stop_tween = create_tween()
	_stop_tween.tween_property(_player, "volume_db", SILENT_DB, fade_time)
	_stop_tween.tween_callback(func() -> void:
		if _player != null:
			_player.stop()
			_player.volume_db = TARGET_VOLUME_DB
	)


func _kill_stop_tween() -> void:
	if _stop_tween != null and _stop_tween.is_valid():
		_stop_tween.kill()
	_stop_tween = null


# --- read API (chapter / tests) --------------------------------------------

func has_stream() -> bool:
	return _player != null and _player.stream != null


func is_playing() -> bool:
	return _player != null and _player.playing and not _player.stream_paused


func is_music_paused() -> bool:
	return _paused


func get_track_name() -> String:
	return track_name


func get_stream_path() -> String:
	return _resolved_path


func get_stream_length() -> float:
	return _stream.get_length() if _stream != null else 0.0


func get_volume_db() -> float:
	return _player.volume_db if _player != null else TARGET_VOLUME_DB


func get_playback_position() -> float:
	return _player.get_playback_position() if _player != null else 0.0


func is_stream_looping() -> bool:
	if _stream is AudioStreamOggVorbis:
		return (_stream as AudioStreamOggVorbis).loop
	if _stream is AudioStreamWAV:
		return ((
			_stream as AudioStreamWAV
		).loop_mode != AudioStreamWAV.LOOP_DISABLED)
	if _stream is AudioStreamMP3:
		return (_stream as AudioStreamMP3).loop
	return false


func get_player() -> AudioStreamPlayer:
	return _player
