extends Node

## Measures the original level-01 opening cue bank. Run headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/opening_l1/tests/sfx_measure.tscn
##
## It prints the actual 16-bit PCM duration and peak for every generated cue so
## dlc/audio/OPENING_L1_SFX.md can quote measured values rather than guesses.

const SFX = preload("res://scripts/narrative/opening_l1_sfx.gd")

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_measure("low_rumble", SFX.low_rumble(), 9.2, 9.4)
	_measure("debris_a", SFX.debris(0), 1.0, 1.2)
	_measure("debris_b", SFX.debris(1), 1.0, 1.2)
	_measure("wind_loop", SFX.wind_loop(), 5.9, 6.1)
	_measure("stele_touch", SFX.stele_touch(), 1.0, 1.1)
	_measure("echo_whisper", SFX.echo_whisper(), 1.3, 1.5)
	_measure("core_emerge", SFX.core_emerge(), 0.9, 1.0)
	_measure("core_handoff", SFX.core_handoff(), 1.1, 1.3)
	_measure("return_whoosh", SFX.return_whoosh(), 0.7, 0.9)
	print("OPENING_L1_SFX_MEASURE failures=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _measure(id: String, stream: AudioStreamWAV, min_seconds: float, max_seconds: float) -> void:
	var seconds: float = SFX.stream_seconds(stream)
	var peak: float = SFX.stream_peak(stream)
	print("SFX %s seconds=%.3f peak=%.4f" % [id, seconds, peak])
	if seconds < min_seconds or seconds > max_seconds:
		_failures += 1
		printerr("FAIL duration %s" % id)
	if peak <= 0.0 or peak >= 0.999:
		_failures += 1
		printerr("FAIL peak %s" % id)
