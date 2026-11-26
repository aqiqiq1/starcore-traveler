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
var _bridge_plays: int = 0
var _slam_plays: int = 0
var _deny_plays: int = 0
var _complete_plays: int = 0
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


func _make_player(
	player_name: String, stream: AudioStream, volume_db: float
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


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
	for player: AudioStreamPlayer in [_inversion, _bridge, _complete, _slam, _deny]:
		if player != null:
			player.stop()
