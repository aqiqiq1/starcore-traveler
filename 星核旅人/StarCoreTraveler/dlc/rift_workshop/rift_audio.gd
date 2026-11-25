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

var _inversion: AudioStreamPlayer
var _bridge: AudioStreamPlayer
var _complete: AudioStreamPlayer


func _ready() -> void:
	_inversion = _make_player("Inversion", INVERSION_STREAM, -7.0)
	_bridge = _make_player("Bridge", BRIDGE_STREAM, -9.0)
	_complete = _make_player("Complete", COMPLETE_STREAM, -5.0)


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
## dissolves: one generated file, two readable events.
func play_bridge(solid: bool) -> void:
	if _bridge == null:
		return
	if solid:
		_bridge.pitch_scale = 1.06
		_bridge.volume_db = -9.0
	else:
		_bridge.pitch_scale = 0.80
		_bridge.volume_db = -13.0
	_bridge.play()


func play_complete() -> void:
	if _complete == null:
		return
	_complete.play()


func stop_all() -> void:
	for player: AudioStreamPlayer in [_inversion, _bridge, _complete]:
		if player != null:
			player.stop()
