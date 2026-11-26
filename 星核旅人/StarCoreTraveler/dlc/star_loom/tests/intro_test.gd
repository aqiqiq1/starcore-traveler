extends Node

## Contract checks for the DLC3 opening film: first play with HUD hidden and
## input locked, no damage/attack, F skip -> guide, long-Space skip, and R
## restart without a replay.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"

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
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(4)

	var cine: DlcIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null, "loom: cinematic exists on first load")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return
	_check(loom.is_intro_active(), "loom: intro active on first load")
	_check(cine.is_playing(), "loom: film is playing")
	_check(not loom.get_hud().visible, "loom: HUD hidden during film")
	_check(not loom.is_boss_active(), "loom: boss not awake during film")
	_check(loom.get_player().is_cinematic_locked(), "loom: player cinematic lock on")
	_check(not get_tree().paused, "loom: tree not paused during film")
	_check(not loom.get_audio().is_music_paused(), "loom: music not paused")
	_check(cine.get_duration() >= 3.0 and cine.get_duration() <= 3.5,
		"loom: duration in 3.0-3.5 s", str(cine.get_duration()))

	var start_x: float = loom.get_player().global_position.x
	var hits: int = loom.get_player().get_hit_count()
	Input.action_press(&"move_right")
	_push_key(KEY_Q, true)
	_push_key(KEY_J, true)
	await _wait_physics(8)
	_push_key(KEY_Q, false)
	_push_key(KEY_J, false)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(absf(loom.get_player().global_position.x - start_x) < 0.75,
		"loom: movement locked during film",
		str(loom.get_player().global_position.x - start_x))
	_check(loom.get_player().get_hit_count() == hits, "loom: no damage during film")
	_check(not loom.get_player().is_attacking(), "loom: J did not start a swing")

	await _wait_until_finished(loom, 480)
	_check(not loom.is_intro_active(), "loom: film ends on its own")
	_check(loom.has_played_intro(), "loom: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(), "loom: natural finish not skipped")
	_check(loom.get_hud().visible, "loom: HUD appears after film")
	_check(not loom.get_player().is_cinematic_locked(), "loom: player lock released")
	_check(cine.get_cue_count() >= 7, "loom: beat cues fired", str(cine.get_cue_count()))

	var resumed_x: float = loom.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(loom.get_player().global_position.x > resumed_x + 1.0,
		"loom: gameplay resumes after film")

	loom.call("_begin_recovery", "fall")
	await _wait_recovery(loom, 120)
	_check(not loom.is_intro_active(), "loom: failure recovery did not replay film")
	_check(loom.get_intro_cinematic() == cine, "loom: failure recovery kept the finished film")

	var same_cine: DlcIntroCinematic = loom.get_intro_cinematic()
	_push_key(KEY_R, true)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	await _wait_process(12)
	_check(not loom.is_intro_active(), "loom: R did not start a second film")
	_check(loom.get_intro_cinematic() == same_cine, "loom: no second cinematic node")
	_check(loom.has_played_intro(), "loom: first-play flag survives R")
	_check(same_cine != null and same_cine.is_finished(), "loom: old film stays finished")

	loom.queue_free()
	await get_tree().process_frame


func _test_f_skip_and_guide() -> void:
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = true
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(5)
	var cine: DlcIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "loom skip: film started")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_until_finished(loom, 90)
	_check(cine.is_skipped(), "loom skip: F marks the film skipped")
	_check(loom.was_intro_skipped(), "loom skip: chapter records skipped")
	_check(loom.has_played_intro(), "loom skip: first play recorded")
	var guide: DlcGuide = loom.get_intro_guide()
	_check(guide != null and guide.is_open(), "loom skip: intro guide opens after film")
	_check(get_tree().paused, "loom skip: guide pauses the tree")
	_check(loom.get_hud().visible, "loom skip: HUD visible under guide")
	if guide != null and guide.is_open():
		guide.close()
	await _wait_process(4)
	_check(not get_tree().paused, "loom skip: closing guide unpauses")
	loom.queue_free()
	await get_tree().process_frame


func _test_space_skip() -> void:
	get_tree().paused = false
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(5)
	var cine: DlcIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "loom space: film started")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "loom space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= DlcIntroCinematic.SKIP_HOLD,
		"loom space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_until_finished(loom, 90)
	_check(cine.is_skipped(), "loom space: long hold skips")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not loom.is_intro_active(), "loom space: release hands control back")
	_check(not loom.get_player().is_cinematic_locked(), "loom space: player lock released")
	loom.queue_free()
	await get_tree().process_frame


func _wait_until_finished(loom: StarLoom, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not loom.is_intro_active():
			return
		await get_tree().process_frame


func _wait_recovery(loom: StarLoom, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not loom.is_recovery_active():
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
	print("LOOM_INTRO_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
