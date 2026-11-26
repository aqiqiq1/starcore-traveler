extends Node

## Contract checks for the DLC2 opening film, mirroring the DLC1 suite:
## first play, HUD/input lock and no damage, F skip -> guide, long-Space skip,
## and R restart without a replay.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"

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
	var rift: RiftWorkshop = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(4)

	var cine: DlcIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null, "rift: cinematic exists on first load")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return
	_check(rift.is_intro_active(), "rift: intro active on first load")
	_check(cine.is_playing(), "rift: film is playing")
	_check(not rift.get_hud().visible, "rift: HUD hidden during film")
	_check(rift.get_boss().is_suspended(), "rift: mirror boss suspended during film")
	_check(rift.get_player().is_cinematic_locked(), "rift: player cinematic lock on")
	_check(not get_tree().paused, "rift: tree not paused during film")
	_check(rift.get_ambience().is_playing(), "rift: chapter music continues")
	_check(cine.get_duration() >= 2.5 and cine.get_duration() <= 3.0,
		"rift: duration in 2.5-3.0 s", str(cine.get_duration()))

	var start_x: float = rift.get_player().global_position.x
	var hits: int = rift.get_player().get_hit_count()
	Input.action_press(&"move_right")
	_push_key(KEY_Q, true)
	_push_key(KEY_J, true)
	await _wait_physics(8)
	_push_key(KEY_Q, false)
	_push_key(KEY_J, false)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(absf(rift.get_player().global_position.x - start_x) < 0.75,
		"rift: movement locked during film",
		str(rift.get_player().global_position.x - start_x))
	_check(rift.get_player().get_hit_count() == hits, "rift: no damage during film")
	_check(not rift.get_player().is_attacking(), "rift: J did not start a swing")

	await _wait_until_finished(rift, 420)
	_check(not rift.is_intro_active(), "rift: film ends on its own")
	_check(rift.has_played_intro(), "rift: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(), "rift: natural finish not skipped")
	_check(rift.get_hud().visible, "rift: HUD returns after film")
	_check(not rift.get_player().is_cinematic_locked(), "rift: player lock released")
	_check(cine.get_cue_count() >= 6, "rift: beat cues fired", str(cine.get_cue_count()))

	var resumed_x: float = rift.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(rift.get_player().global_position.x > resumed_x + 1.0,
		"rift: gameplay resumes after film")

	rift.call("_begin_recovery", "fall")
	await _wait_recovery(rift, 120)
	_check(not rift.is_intro_active(), "rift: failure recovery did not replay film")
	_check(rift.get_intro_cinematic() == cine, "rift: failure recovery kept the finished film")

	var same_cine: DlcIntroCinematic = rift.get_intro_cinematic()
	_push_key(KEY_R, true)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	await _wait_process(12)
	_check(not rift.is_intro_active(), "rift: R did not start a second film")
	_check(rift.get_intro_cinematic() == same_cine, "rift: no second cinematic node")
	_check(rift.has_played_intro(), "rift: first-play flag survives R")
	_check(same_cine != null and same_cine.is_finished(), "rift: old film stays finished")

	rift.queue_free()
	await get_tree().process_frame


func _test_f_skip_and_guide() -> void:
	var rift: RiftWorkshop = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	rift.show_intro_guide = true
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(5)
	var cine: DlcIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "rift skip: film started")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_until_finished(rift, 90)
	_check(cine.is_skipped(), "rift skip: F marks the film skipped")
	_check(rift.was_intro_skipped(), "rift skip: chapter records skipped")
	_check(rift.has_played_intro(), "rift skip: first play recorded")
	var guide: DlcGuide = rift.get_intro_guide()
	_check(guide != null and guide.is_open(), "rift skip: intro guide opens after film")
	_check(get_tree().paused, "rift skip: guide pauses the tree")
	_check(rift.get_hud().visible, "rift skip: HUD visible under guide")
	if guide != null and guide.is_open():
		guide.close()
	await _wait_process(4)
	_check(not get_tree().paused, "rift skip: closing guide unpauses")
	rift.queue_free()
	await get_tree().process_frame


func _test_space_skip() -> void:
	get_tree().paused = false
	var rift: RiftWorkshop = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(5)
	var cine: DlcIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "rift space: film started")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "rift space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= DlcIntroCinematic.SKIP_HOLD,
		"rift space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_until_finished(rift, 90)
	_check(cine.is_skipped(), "rift space: long hold skips")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not rift.is_intro_active(), "rift space: release hands control back")
	_check(not rift.get_player().is_cinematic_locked(), "rift space: player lock released")
	rift.queue_free()
	await get_tree().process_frame


func _wait_until_finished(rift: RiftWorkshop, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not rift.is_intro_active():
			return
		await get_tree().process_frame


func _wait_recovery(rift: RiftWorkshop, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not rift.is_recovery_active():
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
	print("RIFT_INTRO_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
