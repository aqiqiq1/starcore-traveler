extends Node

## Real-audio check for dlc/audio/music/loom_boss.ogg.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/music_test.tscn
##
## It starts the real boss scene, verifies the track is loaded at about -6 dB with
## loop enabled in code (the .import sidecar stays loop=false), waits for the
## playback position to advance, seeks near the end to prove the loop wraps,
## pauses the tree to check the track holds, then resumes.  A live screenshot
## of the fight is saved to tests/out/music_playback.png.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out"

var _loom: StarLoom
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# Music timing must not be interrupted by the fire teaching popup; it has
	# its own test and is not part of this audio check.
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	Input.action_release(&"move_right")
	await _cleanup()
	print("LOOM_MUSIC_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _cleanup() -> void:
	if _loom != null and is_instance_valid(_loom):
		_loom.queue_free()
		_loom = null
	await _wait_process(8)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(4)


func _save(name: String) -> void:
	# frame_post_draw never arrives with the dummy renderer, so a headless run
	# would hang here instead of reporting.  The shot is a real-window extra.
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped (headless): %s" % name)
		return
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	_check(packed != null, "star_loom scene loads for the music test")
	if packed == null:
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = true
	_loom.show_intro_cinematic = false
	add_child(_loom)
	await _wait_process(8)
	# The intro guide pauses the tree; the PROCESS_MODE_ALWAYS music player is
	# started before it, so a real window must keep playing through the guide.
	var guide: DlcGuide = _loom.get_intro_guide()
	var guide_opened: bool = false
	for _index: int in range(80):
		if guide != null and is_instance_valid(guide) and guide.is_open():
			guide_opened = true
			break
		await _wait_process(1)
	_check(guide_opened, "the intro guide opens on the real chapter")
	var early_audio: LoomAudio = _loom.get_audio()
	_check(early_audio.is_music_playing(),
		"music is already playing under the intro guide")
	_check(early_audio.get_music_player().process_mode == Node.PROCESS_MODE_ALWAYS,
		"the ALWAYS music player survives the guide's tree pause")
	if guide != null and is_instance_valid(guide):
		guide.close()
	await _wait_process(12)
	_check(not get_tree().paused, "closing the intro guide unpauses the tree")
	await _wait_seconds(0.3)
	var player: L3Player = _loom.get_player()
	player.global_position = Vector2(440.0, 320.0)
	player.velocity = Vector2.ZERO
	for _index: int in range(60):
		if _loom.is_boss_active():
			break
		await get_tree().physics_frame
	await _wait_seconds(1.2)
	var audio: LoomAudio = _loom.get_audio()
	_check(_loom.is_boss_active(), "the real boss is active")
	_check(audio.is_music_available(), "loom_boss.ogg is loaded")
	_check(audio.is_music_playing(), "music is actually playing")
	_check(audio.get_music_loop(), "AudioStreamOggVorbis.loop is enabled in code")
	var reverb: AudioEffectReverb = audio.get_reverb_effect()
	_check(audio.has_reverb_bus() and reverb != null,
		"the LoomReverb bus and AudioEffectReverb exist",
		audio.get_reverb_bus_name())
	if reverb != null:
		_check(reverb.room_size >= 0.5 and reverb.room_size <= 0.7,
			"reverb room size is 0.5-0.7", str(reverb.room_size))
		_check(reverb.wet >= 0.15 and reverb.wet <= 0.25,
			"reverb wet is 0.15-0.25", str(reverb.wet))
	_check(audio.get_music_player().bus == audio.get_reverb_bus_name(),
		"the boss music player is routed to the reverb bus")
	_check(audio.get_player_bus("NodeHit") == audio.get_reverb_bus_name()
		and audio.get_player_bus("Fire") == audio.get_reverb_bus_name()
		and audio.get_player_bus("Complete") == audio.get_reverb_bus_name(),
		"the main loom SFX players are routed to the reverb bus")
	_check(audio.is_music_playing(),
		"music stays playing with the reverb bus active")
	_check(audio.get_music_player() != null
		and audio.get_music_player().process_mode == Node.PROCESS_MODE_ALWAYS,
		"the music player is PROCESS_MODE_ALWAYS")
	_check(
		audio.get_music_volume_db() >= -7.0 and audio.get_music_volume_db() <= -5.0,
		"music player volume is between -7 and -5 dB",
		str(audio.get_music_volume_db())
	)
	var final_peak: float = -8.05 + audio.get_music_volume_db()
	_check(final_peak >= -15.0 and final_peak <= -13.0,
		"final music peak is about -14 dBFS", "%.2f dBFS" % final_peak)
	print("LOOM_MUSIC_FINAL_PEAK_DBFS=%.2f" % final_peak)
	_check(absf(audio.get_music_length() - 61.7) < 0.5,
		"music length is about 61.7 s", "%.2fs" % audio.get_music_length())
	var position_one: float = audio.get_music_position()
	await _wait_seconds(0.8)
	var position_two: float = audio.get_music_position()
	_check(position_two > position_one + 0.3,
		"playback position advances", "%.2f -> %.2f" % [position_one, position_two])

	# Seek close to the end and verify the loop wraps instead of stopping.
	var length: float = audio.get_music_length()
	audio.seek_music(length - 0.6)
	await _wait_seconds(1.4)
	var wrapped: float = audio.get_music_position()
	_check(audio.is_music_playing(), "music is still playing after the loop point")
	_check(wrapped < 5.0, "playback wrapped to the start of the loop",
		"pos=%.2f length=%.2f" % [wrapped, length])

	# Pause page: the pausable Audio node should hold the track, then resume.
	_push_key(KEY_ESCAPE, true)
	await _wait_process(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_seconds(0.3)
	_check(_loom.is_pause_open() and get_tree().paused, "pause page opens")
	_check(audio.is_music_paused(),
		"the pause page explicitly stream-pauses the music")
	var paused_one: float = audio.get_music_position()
	await _wait_seconds(0.6)
	var paused_two: float = audio.get_music_position()
	_check(absf(paused_two - paused_one) < 0.12,
		"music position holds while paused", "%.2f -> %.2f" % [paused_one, paused_two])
	_push_key(KEY_ESCAPE, true)
	await _wait_process(2)
	_push_key(KEY_ESCAPE, false)
	await _wait_seconds(0.6)
	_check(not get_tree().paused, "pause page closes")
	_check(not audio.is_music_paused(), "the pause stream flag is cleared")
	_check(audio.is_music_playing(), "music resumes with the fight")
	_check(audio.get_music_position() > 0.0, "music position advances after resume")

	await _save("music_playback.png")
	await _wait_process(4)
