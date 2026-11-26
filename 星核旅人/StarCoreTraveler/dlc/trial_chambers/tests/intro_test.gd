extends Node

## Contract checks for the DLC1 opening film:
##   - it plays on the first scene load, with HUD hidden and input locked;
##   - J / Q / move during the film cannot move or damage the player;
##   - F skips, then the intro guide opens;
##   - holding Space skips;
##   - R restarts the chapter without replaying the film.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	await _test_first_play_and_locks()
	await _test_f_skip_and_guide()
	await _test_space_skip()


func _test_first_play_and_locks() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(4)

	var cine: DlcIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null, "trial: cinematic exists on first load")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return
	_check(trial.is_intro_active(), "trial: intro active on first load")
	_check(cine.is_playing(), "trial: film is playing")
	_check(not trial.get_hud().visible, "trial: HUD hidden during film")
	_check(trial.get_guard().is_suspended(), "trial: guard suspended during film")
	_check(trial.get_player().is_cinematic_locked(), "trial: player cinematic lock on")
	_check(not get_tree().paused, "trial: tree not paused during film")
	_check(trial.get_ambience().is_playing(), "trial: chapter music continues")
	_check(cine.get_duration() >= 2.5 and cine.get_duration() <= 3.0,
		"trial: duration in 2.5-3.0 s", str(cine.get_duration()))

	var start_x: float = trial.get_player().global_position.x
	var hits: int = trial.get_player().get_hit_count()
	Input.action_press(&"move_right")
	_push_key(KEY_Q, true)
	_push_key(KEY_J, true)
	await _wait_physics(8)
	_push_key(KEY_Q, false)
	_push_key(KEY_J, false)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(absf(trial.get_player().global_position.x - start_x) < 0.75,
		"trial: movement locked during film",
		str(trial.get_player().global_position.x - start_x))
	_check(trial.get_player().get_hit_count() == hits,
		"trial: no damage during film")
	_check(not trial.get_player().is_attacking(), "trial: J did not start a swing")

	await _wait_until_finished(trial, 420)
	_check(not trial.is_intro_active(), "trial: film ends on its own")
	_check(trial.has_played_intro(), "trial: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(), "trial: natural finish not skipped")
	_check(trial.get_hud().visible, "trial: HUD returns after film")
	_check(not trial.get_player().is_cinematic_locked(), "trial: player lock released")
	_check(cine.get_cue_count() >= 4, "trial: beat cues fired", str(cine.get_cue_count()))

	var resumed_x: float = trial.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(trial.get_player().global_position.x > resumed_x + 1.0,
		"trial: gameplay resumes after film")

	# A real failure/recovery reset is also in-place and must not replay.
	trial.call("_begin_recovery", "fall")
	await _wait_recovery(trial, 120)
	_check(not trial.is_intro_active(), "trial: failure recovery did not replay film")
	_check(trial.get_intro_cinematic() == cine, "trial: failure recovery kept the finished film")

	# R restarts in place and must not create/replay the film.
	var same_cine: DlcIntroCinematic = trial.get_intro_cinematic()
	_push_key(KEY_R, true)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	await _wait_process(12)
	_check(not trial.is_intro_active(), "trial: R did not start a second film")
	_check(trial.get_intro_cinematic() == same_cine, "trial: no second cinematic node")
	_check(trial.has_played_intro(), "trial: first-play flag survives R")
	_check(same_cine != null and same_cine.is_finished(), "trial: old film stays finished")

	trial.queue_free()
	await get_tree().process_frame


func _test_f_skip_and_guide() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = true
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(5)
	var cine: DlcIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "trial skip: film started")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_until_finished(trial, 90)
	_check(cine.is_skipped(), "trial skip: F marks the film skipped")
	_check(trial.was_intro_skipped(), "trial skip: chapter records skipped")
	_check(trial.has_played_intro(), "trial skip: first play recorded")
	var guide: DlcGuide = trial.get_intro_guide()
	_check(guide != null and guide.is_open(), "trial skip: intro guide opens after film")
	_check(get_tree().paused, "trial skip: guide pauses the tree")
	_check(trial.get_hud().visible, "trial skip: HUD visible under guide")
	if guide != null and guide.is_open():
		guide.close()
	await _wait_process(4)
	_check(not get_tree().paused, "trial skip: closing guide unpauses")
	trial.queue_free()
	await get_tree().process_frame


func _test_space_skip() -> void:
	get_tree().paused = false
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(5)
	var cine: DlcIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "trial space: film started")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "trial space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= DlcIntroCinematic.SKIP_HOLD,
		"trial space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_until_finished(trial, 90)
	_check(cine.is_skipped(), "trial space: long hold skips")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not trial.is_intro_active(), "trial space: release hands control back")
	_check(not trial.get_player().is_cinematic_locked(), "trial space: player lock released")
	trial.queue_free()
	await get_tree().process_frame


func _wait_until_finished(trial: TrialChambers, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not trial.is_intro_active():
			return
		await get_tree().process_frame


func _wait_recovery(trial: TrialChambers, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not trial.is_recovery_active():
			return
		await get_tree().process_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _cleanup() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	get_tree().paused = false
	await _wait_process(30)
	print("TRIAL_INTRO_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
