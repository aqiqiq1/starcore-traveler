extends Node

## DLC-local audio for the rift workshop.
##
## Only the five generated WAV files in res://dlc/rift_workshop/assets/audio are
## used here; DemoAudio and the three base levels' audio are not modified.  The
## shared DemoAudio autoload is still called by the chapter for the existing
## swing / hurt / failure / respawn cues, because those are the approved sounds
## of the shared L3 player and guard rules.

const INVERSION_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_inversion.wav"
)
const BRIDGE_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_bridge.wav"
)
const COMPLETE_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_complete.wav"
)
const DENY_STREAM: AudioStreamWAV = preload(
	"res://dlc/rift_workshop/assets/audio/sfx_deny.wav"
)
## The mirror sweep reuses the already approved level-03 impact cue, because
## the arena has no other contact sound.  Loaded at runtime (not preloaded)
## exactly like scripts/level03/l3_audio.gd, so the Ogg packet sequence is not
## kept alive past teardown.  The base file is read only.
const SLAM_PATH: String = "res://assets/level03_prototype/audio_slam.ogg"

## Music/defeat paths are fixed by the 2026-11-27 audio hand-off.  They are
## deliberately loaded at runtime and guarded by ResourceLoader.exists(): the
## music route may deliver the files after this code lands, and a missing file
## must stay silent instead of raising an error or blocking the fight.
const MUSIC_PATH: String = "res://dlc/rift_workshop/assets/audio/mirror_boss.ogg"
const DEFEAT_PATH: String = "res://dlc/rift_workshop/assets/audio/mirror_defeat.ogg"
## Same -6 dB local-music level as the star-loom chapter.  The player stays on
## the Master bus, so the existing master-volume slider controls it.
const MUSIC_DB: float = -6.0
const DEFEAT_DB: float = -2.0

# The WAVs are peak-normalised to -3 dBFS (hum -9 dBFS), so these player gains
# are the real final peaks: inversion / complete -3 dBFS, bridge -5 dBFS when it
# forms and -7 dBFS when it dissolves, at the base levels' audible level without
# stacking into clipping (one deck change fires at most one coalesced chime).
const INVERSION_DB: float = 0.0
const BRIDGE_SOLID_DB: float = -2.0
const BRIDGE_GONE_DB: float = -4.0
const COMPLETE_DB: float = 0.0
## -4 dB on a -3 dBFS peak cue leaves headroom beside the ambience.
const SLAM_DB: float = -4.0
## One sweep resolution per attack; the coalesce window only protects against
## a duplicated signal in the same 60 ms.
const SLAM_COALESCE_MS: int = 60

var _inversion: AudioStreamPlayer
var _bridge: AudioStreamPlayer
var _complete: AudioStreamPlayer
var _slam: AudioStreamPlayer
var _deny: AudioStreamPlayer
var _music: AudioStreamPlayer = null
var _defeat: AudioStreamPlayer
var _bridge_plays: int = 0
var _slam_plays: int = 0
var _deny_plays: int = 0
var _complete_plays: int = 0
var _music_start_count: int = 0
var _defeat_plays: int = 0
var _last_slam_ms: int = -1000


func _ready() -> void:
	_inversion = _make_player("Inversion", INVERSION_STREAM, INVERSION_DB)
	_bridge = _make_player("Bridge", BRIDGE_STREAM, BRIDGE_SOLID_DB)
	_complete = _make_player("Complete", COMPLETE_STREAM, COMPLETE_DB)
	_slam = _make_player("Slam", null, SLAM_DB)
	if _slam != null:
		_slam.stream = ResourceLoader.load(
			SLAM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
		) as AudioStream
	_deny = _make_player("Deny", DENY_STREAM, -6.0)
	_defeat = _make_player("Defeat", null, DEFEAT_DB)
	_setup_defeat(DEFEAT_PATH)
	_setup_music(MUSIC_PATH)


func _make_player(
	player_name: String, stream: AudioStream, volume_db: float
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"Master"
	add_child(player)
	return player


# --- optional boss music / defeat cue --------------------------------------

## Missing music is a supported silent state, not an error.  The OGG loop flag
## is set in code because the generated .import sidecar may leave it off.
func _setup_music(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: Resource = ResourceLoader.load(path)
	if not (stream is AudioStream):
		return
	_set_stream_loop(stream as AudioStream, true)
	if _music == null:
		_music = _make_player("Music", null, MUSIC_DB)
		# The chapter's pause page pauses the tree; the BGM must freeze with it
		# instead of inheriting the chapter's PROCESS_MODE_ALWAYS.
		_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	_music.stream = stream as AudioStream


func _setup_defeat(path: String) -> void:
	if _defeat == null:
		return
	if not ResourceLoader.exists(path):
		return
	var stream: Resource = ResourceLoader.load(path)
	if stream is AudioStream:
		_defeat.stream = stream as AudioStream


func _set_stream_loop(stream: AudioStream, value: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = value
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = value
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if value else AudioStreamWAV.LOOP_DISABLED
		)


func start_music() -> void:
	if _music == null:
		return
	if not _music.playing:
		_music.play()
		_music_start_count += 1


func stop_music() -> void:
	if _music != null:
		_music.stop()


func pause_music() -> void:
	if _music != null and _music.playing:
		_music.stream_paused = true


func resume_music() -> void:
	if _music != null:
		_music.stream_paused = false


func play_defeat() -> bool:
	if _defeat == null or _defeat.stream == null:
		return false
	_defeat.play()
	_defeat_plays += 1
	return true


func is_music_available() -> bool:
	return _music != null and _music.stream != null


func is_music_playing() -> bool:
	return _music != null and _music.playing


func is_music_paused() -> bool:
	return _music != null and _music.stream_paused


func is_music_loop() -> bool:
	if _music == null or _music.stream == null:
		return false
	var stream: AudioStream = _music.stream
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false


func is_defeat_available() -> bool:
	return _defeat != null and _defeat.stream != null


func get_music_path() -> String:
	return MUSIC_PATH


func get_defeat_path() -> String:
	return DEFEAT_PATH


func get_music_player() -> AudioStreamPlayer:
	return _music


func get_defeat_player() -> AudioStreamPlayer:
	return _defeat


func get_music_start_count() -> int:
	return _music_start_count


func get_defeat_play_count() -> int:
	return _defeat_plays


## Test hooks: prove the positive existence branch with any real audio file
## even while the delivered fixed-path assets are still absent.
func setup_music_for_test(path: String) -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null
	_setup_music(path)


func setup_defeat_for_test(path: String) -> void:
	_setup_defeat(path)


func play_inversion() -> void:
	if _inversion == null:
		return
	_inversion.pitch_scale = randf_range(0.97, 1.03)
	_inversion.play()


## The same short chime is pitched up when a deck appears and down when one
## dissolves: one generated file, two readable events.  Both directions are
## real plays, and the counter lets the chapter test prove it.
func play_bridge(solid: bool) -> void:
	if _bridge == null:
		return
	if solid:
		_bridge.pitch_scale = 1.06
		_bridge.volume_db = BRIDGE_SOLID_DB
	else:
		_bridge.pitch_scale = 0.80
		_bridge.volume_db = BRIDGE_GONE_DB
	_bridge.play()
	_bridge_plays += 1


func get_bridge_play_count() -> int:
	return _bridge_plays


## Real impact cue for a mirror sweep that lands.  Coalesced so a duplicated
## signal in the same 60 ms window produces one thud instead of a doubled hit.
func play_slam() -> void:
	if _slam == null or _slam.stream == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_slam_ms < SLAM_COALESCE_MS:
		return
	_last_slam_ms = now_ms
	_slam.play()
	_slam_plays += 1


func get_slam_play_count() -> int:
	return _slam_plays


## Q is locked in this chapter.  One dry, low refusal cue per press, never the
## rising phase-switch sound.
func play_deny() -> void:
	if _deny == null:
		return
	_deny.pitch_scale = randf_range(0.97, 1.02)
	_deny.play()
	_deny_plays += 1


func get_deny_play_count() -> int:
	return _deny_plays


func play_complete() -> void:
	if _complete == null:
		return
	_complete.play()
	_complete_plays += 1


func get_complete_play_count() -> int:
	return _complete_plays


func stop_all() -> void:
	stop_music()
	for player: AudioStreamPlayer in [
		_inversion, _bridge, _complete, _slam, _deny, _defeat,
	]:
		if player != null:
			player.stop()


## Scene shutdown: drop the OGG playback/stream before the SceneTree exits so
## no music stream survives a title hand-off.  stop_all() alone is enough for
## retries, where the streams must stay loaded.
func shutdown() -> void:
	stop_all()
	if _music != null:
		_music.stream = null
	if _defeat != null:
		_defeat.stream = null
