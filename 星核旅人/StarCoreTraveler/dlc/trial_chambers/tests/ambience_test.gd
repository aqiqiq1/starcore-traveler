extends Node

## Ambience integration test for the two DLC chapters.
##
##   ... --headless --path . res://dlc/trial_chambers/tests/ambience_test.tscn
##
## Proves, on the real scenes:
##   - the .ogg track under res://dlc/audio/music/ is resolved at runtime
##     (preferred over .wav), with a real length and looping enabled on the
##     duplicated stream only;
##   - playback actually starts and advances;
##   - the whole-file loop wraps instead of stopping;
##   - the pause page freezes the track (stream_paused + frozen position) and
##     resuming continues from the same point;
##   - completion fades it out, R starts it again from the beginning, and
##     returning to the title stops it;
##   - a missing track stays silent instead of erroring (degradation path).
##
## This test never writes to dlc/audio.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const TRIAL_TRACK: String = "res://dlc/audio/music/trial_ambience.ogg"
const RIFT_TRACK: String = "res://dlc/audio/music/rift_ambience.ogg"
const VOLUME_MIN_DB: float = -12.0
const VOLUME_MAX_DB: float = -8.0

var _checks: int = 0
var _failures: Array[String] = []
var _trial: TrialChambers = null
var _rift: RiftWorkshop = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("DLC_AMBIENCE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ---------------------------------------------------------------

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("PASS: " + label + ("" if detail.is_empty() else " [" + detail + "]"))
		return
	_failures.append(label + ("" if detail.is_empty() else " [" + detail + "]"))
	print("FAIL: " + label + ("" if detail.is_empty() else " [" + detail + "]"))


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


## Waits in real time (the headless frame rate is not 60 fps, so a fixed frame
## count is not a reliable duration for audio/tween checks).
func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _wait_ms(duration_ms: int) -> void:
	var deadline: int = Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	# The shared player only accepts left Shift for sprint; an unspecified
	# location is ignored on purpose.
	event.location = (
		KEY_LOCATION_LEFT if code == KEY_SHIFT else KEY_LOCATION_UNSPECIFIED
	)
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(2)
	_push_key(code, false)
	await _wait_physics(2)


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	if _trial != null and is_instance_valid(_trial):
		_trial.queue_free()
	if _rift != null and is_instance_valid(_rift):
		_rift.queue_free()
	await _wait_process(3)


# --- shared track checks ---------------------------------------------------

func _check_track(
	ambience: DlcChapterAmbience, track_name: String, expected_path: String
) -> void:
	_check(ambience != null, "%s ambience node exists" % track_name)
	if ambience == null:
		return
	_check(ambience.get_track_name() == track_name,
		"%s node is configured for its own track" % track_name, ambience.get_track_name())
	_check(ResourceLoader.exists(expected_path),
		"%s .ogg file exists on disk" % track_name, expected_path)
	_check(ambience.has_stream(), "%s resolved a real audio stream" % track_name)
	_check(ambience.get_stream_path() == expected_path,
		"%s prefers the .ogg file" % track_name, ambience.get_stream_path())
	_check(ambience.get_stream_length() > 10.0,
		"%s stream has a real length" % track_name, "%.2f s" % ambience.get_stream_length())
	var volume: float = ambience.get_volume_db()
	_check(volume >= VOLUME_MIN_DB and volume <= VOLUME_MAX_DB,
		"%s volume is inside -8..-12 dB" % track_name, "%.1f dB" % volume)
	_check(ambience.is_stream_looping(), "%s stream is set to loop" % track_name)


func _check_playback(ambience: DlcChapterAmbience, label: String) -> void:
	_check(ambience.is_playing(), "%s is playing after start" % label)
	var advanced: bool = await _wait_until(
		func() -> bool: return ambience.get_playback_position() > 0.01, 1500
	)
	_check(advanced and ambience.is_playing(), "%s playback position advances" % label,
		"%.3f s" % ambience.get_playback_position())


# --- trial -----------------------------------------------------------------

func _run() -> void:
	_trial = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	_trial.show_intro_guide = false
	_trial.show_intro_cinematic = false
	get_tree().root.add_child(_trial)
	get_tree().current_scene = _trial
	await _wait_process(3)
	await _wait_physics(6)

	var ambience: DlcChapterAmbience = _trial.get_ambience()
	_check_track(ambience, "trial_ambience", TRIAL_TRACK)
	await _check_playback(ambience, "trial ambience")
	_check(ambience.process_mode == Node.PROCESS_MODE_ALWAYS,
		"trial ambience node is PROCESS_MODE_ALWAYS")
	_check(ambience.get_player().process_mode == Node.PROCESS_MODE_ALWAYS,
		"trial ambience AudioStreamPlayer is PROCESS_MODE_ALWAYS")

	# --- footsteps: node exists, bank loaded, real run produces steps ------
	var steps: PlayerFootstepAudio = _trial.get_footsteps()
	_check(steps != null and steps.is_bound(), "trial has a bound footstep helper")
	if steps != null:
		_check(steps.get_voice_count() == 2, "footstep helper owns two voices",
			str(steps.get_voice_count()))
		_check(steps.are_voices_on_master(), "footstep voices are on the Master bus")
		_check(steps.is_bank_loaded(), "six CC0 stone-step files are loaded")
		_check(_trial.is_footsteps_allowed(), "footsteps are allowed in normal play")
		_trial.get_player().global_position = Vector2(48.0, 320.0)
		_trial.get_player().velocity = Vector2.ZERO
		_trial.get_camera().reset_smoothing()
		await _wait_physics(4)
		_push_key(KEY_SHIFT, true)
		Input.action_press(&"move_right")
		await _wait_physics(80)
		Input.action_release(&"move_right")
		_push_key(KEY_SHIFT, false)
		await _wait_physics(2)
		_check(steps.get_step_count() > 0, "a real run produced footstep candidates",
			str(steps.get_step_count()))
		_check(steps.get_played_count() > 0, "a real run played footstep audio",
			str(steps.get_played_count()))
		_check(steps.get_last_played_anim() == &"run",
			"the moving footsteps used the run bank", str(steps.get_last_played_anim()))
		_check(is_equal_approx(steps.get_last_volume_db(), -15.0),
			"run footsteps use the approved -15 dB", "%.1f" % steps.get_last_volume_db())

	# Whole-file loop: seek just before the end, then wait until the position
	# comes back to the beginning.  A non-looping stream would have stopped.
	var length: float = ambience.get_stream_length()
	var player: AudioStreamPlayer = ambience.get_player()
	player.seek(maxf(length - 0.20, 0.0))
	var wrapped: bool = await _wait_until(
		func() -> bool: return ambience.get_playback_position() < 1.0, 3000
	)
	_check(player.playing, "trial ambience keeps playing across the loop point")
	_check(wrapped, "trial ambience wrapped to the start of the file",
		"%.3f s of %.2f s" % [ambience.get_playback_position(), length])

	# Move to a mid-file point so the pause/resume positions are unambiguous.
	player.seek(10.0)
	await _wait_until(
		func() -> bool: return ambience.get_playback_position() > 10.2, 1500
	)

	# Pause page: real Esc, then check the track is frozen.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	_check(_trial.is_pause_open(), "trial pause page opens with Esc")
	_check(not _trial.is_footsteps_allowed(), "pause page disables footstep playback")
	_check(ambience.is_music_paused(), "trial ambience marks itself paused")
	_check(player.stream_paused, "trial ambience stream_paused is set")
	var paused_from: float = ambience.get_playback_position()
	await _wait_ms(400)
	var paused_to: float = ambience.get_playback_position()
	_check(absf(paused_to - paused_from) < 0.03, "trial ambience position is frozen while paused",
		"%.3f -> %.3f" % [paused_from, paused_to])
	await _tap_key(KEY_ESCAPE)
	await _wait_process(8)
	_check(not _trial.is_pause_open(), "trial pause page closes with Esc")
	_check(not ambience.is_music_paused(), "trial ambience is no longer marked paused")
	var resumed: bool = await _wait_until(
		func() -> bool: return ambience.get_playback_position() > paused_to + 0.05, 1500
	)
	_check(ambience.is_playing(), "trial ambience resumes after the pause page")
	_check(resumed, "trial ambience continues from the paused point",
		"%.3f -> %.3f" % [paused_to, ambience.get_playback_position()])

	# --- mechanic popup: tree pauses, music keeps playing ------------------
	var popup: MechanicPopup = _trial.get_mechanic_popup()
	_check(popup != null, "trial exposes the shared mechanic popup")
	if popup != null:
		var popup_music_before: float = ambience.get_playback_position()
		var opened: bool = popup.open_for_test("trial_guard_deny")
		_check(opened and popup.is_open(), "mechanic popup opens for the music check")
		_check(get_tree().paused, "mechanic popup pauses the tree")
		_check(not _trial.is_footsteps_allowed(),
			"mechanic popup disables footstep playback")
		if steps != null:
			_check(steps.get_active_voice_count() == 0,
				"no footstep tail survives into the mechanic popup")
		_check(ambience.is_playing(), "music is still playing while the popup is open")
		await _wait_ms(350)
		_check(ambience.get_playback_position() > popup_music_before + 0.05,
			"music keeps advancing behind the mechanic popup",
			"%.2f -> %.2f" % [popup_music_before, ambience.get_playback_position()])
		popup.close()
		await _wait_process(6)
		_check(not get_tree().paused, "closing the popup unpauses the tree")
		_check(ambience.is_playing(), "music is still playing after the popup")

	# Completion fades the music out.
	_trial.get_guard().debug_force_death()
	_trial.get_guard().defeated.emit()
	await _wait_process(10)
	_trial.get_player().global_position = Vector2(1204.0, 320.0)
	_trial.get_player().velocity = Vector2.ZERO
	await _wait_physics(4)
	_check(_trial.is_completed(), "trial completion page reached")
	_check(not _trial.is_footsteps_allowed(), "completion page disables footsteps")
	if steps != null:
		_check(steps.get_active_voice_count() == 0,
			"no footstep tail survives onto the completion page")
	var stopped: bool = await _wait_until(
		func() -> bool: return not ambience.is_playing(), 3000
	)
	_check(stopped, "trial ambience stops on the completion page",
		"%.2f s" % (Time.get_ticks_msec() / 1000.0))
	_check(ambience.has_stream(), "trial ambience stream is kept after stopping")

	# R on the completion page restarts the chapter and the track.
	await _tap_key(KEY_R)
	await _wait_process(10)
	_check(not _trial.is_completed(), "trial R leaves the completion page")
	_check(ambience.is_playing(), "trial ambience plays again after R")
	_check(ambience.get_playback_position() < 0.6, "trial ambience restarted from the first frame",
		"%.3f s" % ambience.get_playback_position())

	# Pause -> 返回主界面 must stop the track and still return to level_01.
	# The page has four rows now: continue, restart, return, quit.  Move to the
	# third row with the real Down path.
	await _tap_key(KEY_ESCAPE)
	await _wait_process(4)
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	await _wait_process(3)
	_check(_trial.get_hud().get_title_button().has_focus(),
		"trial pause focus reaches 返回主界面")
	_push_key(KEY_ENTER, true)
	# _return_to_title() unpauses the tree and stops the track synchronously
	# inside this input dispatch; checking both now proves the stop happened
	# (a still-playing player would resume with the unpause).
	var left_unpaused: bool = not get_tree().paused
	var stopped_on_title: bool = not ambience.is_playing()
	_push_key(KEY_ENTER, false)
	_check(left_unpaused and stopped_on_title, "trial ambience stops when 返回主界面 is activated")
	var changed: bool = false
	for _index: int in range(150):
		var current: Node = get_tree().current_scene
		if current != null and current != _trial:
			changed = true
			break
		await get_tree().process_frame
	var current: Node = get_tree().current_scene
	var path: String = current.scene_file_path if current != null else ""
	_check(changed and path == LEVEL_01, "pause 返回主界面 still returns to level_01", path)
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	_trial = null
	await _wait_process(6)

	# Missing-file degradation: no stream, no playback, no error.
	var silent: DlcChapterAmbience = DlcChapterAmbience.new()
	silent.track_name = "ambience_that_does_not_exist"
	add_child(silent)
	await _wait_process(3)
	_check(not silent.has_stream(), "missing track resolves to silence")
	_check(not silent.is_playing(), "missing track never starts playing")
	_check(silent.get_stream_path().is_empty(), "missing track has no resolved path")
	silent.queue_free()
	await _wait_process(3)

	# --- rift --------------------------------------------------------------
	_rift = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	_rift.show_intro_cinematic = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(6)
	var rift_ambience: DlcChapterAmbience = _rift.get_ambience()
	_check_track(rift_ambience, "rift_ambience", RIFT_TRACK)
	await _check_playback(rift_ambience, "rift ambience")

	await _tap_key(KEY_ESCAPE)
	await _wait_process(6)
	_check(_rift.is_pause_open(), "rift pause page opens with Esc")
	_check(rift_ambience.is_music_paused(), "rift ambience marks itself paused")
	var rift_player: AudioStreamPlayer = rift_ambience.get_player()
	_check(rift_player.stream_paused, "rift ambience stream_paused is set")
	var rift_from: float = rift_ambience.get_playback_position()
	await _wait_ms(400)
	var rift_to: float = rift_ambience.get_playback_position()
	_check(absf(rift_to - rift_from) < 0.03, "rift ambience position is frozen while paused",
		"%.3f -> %.3f" % [rift_from, rift_to])
	await _tap_key(KEY_ESCAPE)
	await _wait_process(16)
	_check(rift_ambience.is_playing(), "rift ambience resumes after the pause page")

	# R restarts from the top, like the trial chapter.
	await _tap_key(KEY_R)
	await _wait_process(8)
	_check(rift_ambience.is_playing(), "rift ambience plays after R")
	_check(rift_ambience.get_playback_position() < 0.6,
		"rift ambience restarted from the first frame",
		"%.3f s" % rift_ambience.get_playback_position())

	# Intro guide: music must continue during the guide, not be held back.
	_rift.queue_free()
	_rift = null
	await _wait_process(4)
	var guided: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	guided.show_intro_cinematic = false
	get_tree().root.add_child(guided)
	get_tree().current_scene = guided
	await _wait_process(8)
	var guide: DlcGuide = guided.get_intro_guide()
	_check(guide != null and guide.is_open(), "trial intro guide opens on a normal entry")
	var guided_ambience: DlcChapterAmbience = guided.get_ambience()
	_check(guided_ambience.is_playing(), "trial ambience plays while the intro guide is open")
	_check(not guided.is_footsteps_allowed(), "intro guide disables footstep playback")
	var guide_music_before: float = guided_ambience.get_playback_position()
	await _wait_ms(350)
	_check(guided_ambience.get_playback_position() > guide_music_before + 0.05,
		"trial ambience keeps advancing behind the guide",
		"%.2f -> %.2f" % [guide_music_before, guided_ambience.get_playback_position()])
	if guide != null:
		guide.close()
	await _wait_process(8)
	_check(not get_tree().paused, "closing the guide unpauses the tree")
	_check(guided_ambience.is_playing(), "trial ambience continues after the guide closes")
	_check(guided.is_footsteps_allowed(), "closing the guide re-enables footsteps")
	guided.queue_free()
	await _wait_process(4)
