extends Node

## Contract checks for the DLC2 opening film (2026-11-27 rework).
##
## The film is no longer a painted CanvasLayer: it must drive the real chapter
## through a real OpeningCamera2D, the real suspended RiftMirrorBoss and the
## real player at the chapter start.  These checks cover:
##   - first play, HUD/input lock, no damage, boss still dormant;
##   - camera ownership before/after, and the exact player view after the pan;
##   - boss BGM stays off while ambience continues;
##   - F skip -> guide, long-Space skip;
##   - failure and R never replay the film.

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
	await _test_mid_pull_skip()


func _test_first_play_and_locks() -> void:
	var rift: RiftWorkshop = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(5)

	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null, "rift: cinematic exists on first load")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return
	_check(rift.is_intro_active(), "rift: intro active on first load")
	_check(cine.is_playing(), "rift: film is playing")
	_check(cine.get_duration() >= 3.6 and cine.get_duration() <= 4.2,
		"rift: duration in 3.6-4.2 s", str(cine.get_duration()))
	_check(cine.get_phase_name() == "MIRROR_HELD",
		"rift: opens on the real mirror hall", cine.get_phase_name())

	# The film must use the chapter's real nodes, not a painted copy.
	var opening_camera: Camera2D = cine.get_opening_camera()
	_check(opening_camera != null, "rift: OpeningCamera2D exists")
	_check(get_viewport().get_camera_2d() == opening_camera,
		"rift: viewport camera is the OpeningCamera2D")
	_check(opening_camera != rift.get_camera(),
		"rift: opening camera is separate from the player camera")
	_check(not rift.get_camera().enabled,
		"rift: player camera is disabled during the film")
	_check(cine.get_boss() == rift.get_boss(),
		"rift: film points at the real mirror boss")
	_check(cine.get_player() == rift.get_player(),
		"rift: film points at the real player")
	_check(opening_camera.get_parent() == cine,
		"rift: opening camera lives under the film node")
	_check(cine.get_eye_world_position() == rift.get_boss().get_boss_center(),
		"rift: eye overlay is anchored to the real boss")
	_check(cine.get_face_world_position(true)
		== rift.get_boss().get_face_center_global(true),
		"rift: gold plate light is anchored to the real face plate")
	_check(cine.get_face_world_position(false)
		== rift.get_boss().get_face_center_global(false),
		"rift: cyan plate light is anchored to the real face plate")
	_check(is_equal_approx(cine.get_wave_floor_y(), 320.0),
		"rift: wave overlay sits on the real arena floor")

	_check(not rift.get_boss().is_active(), "rift: mirror boss not active during film")
	_check(rift.get_boss().is_suspended(), "rift: mirror boss suspended during film")
	_check(not rift.is_boss_active(), "rift: chapter BGM state off during film")
	_check(not rift.is_arena_entered(), "rift: player has not entered the arena")
	_check(not bool(rift.get_audio().call("is_music_playing")),
		"rift: boss BGM did not start")
	_check(int(rift.get_audio().call("get_music_start_count")) == 0,
		"rift: boss BGM start count is zero")
	_check(rift.get_ambience().is_playing(), "rift: chapter ambience continues")
	_check(not rift.get_hud().visible, "rift: HUD hidden during film")
	_check(rift.get_player().is_cinematic_locked(), "rift: player cinematic lock on")
	_check(not get_tree().paused, "rift: tree not paused during film")
	_check(cine.get_grade_alpha() > 0.5,
		"rift: first beat is dark but not a black backdrop",
		str(cine.get_grade_alpha()))
	_check(cine.get_eye_open_amount() < 0.05,
		"rift: mirror eye starts closed", str(cine.get_eye_open_amount()))

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

	# Headless runs faster than 60 fps; the wait is a frame budget with margin,
	# not a duration assertion.  The film itself owns the 4.0 s timing.
	await _wait_until_finished(rift, 900)
	_check(not rift.is_intro_active(), "rift: film ends on its own")
	_check(rift.has_played_intro(), "rift: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(), "rift: natural finish not skipped")
	_check(cine.get_cue_count() >= 6, "rift: beat cues fired", str(cine.get_cue_count()))

	# The hand-off is the player camera at the exact gameplay view.  Because the
	# player waits at x=40, that is the left-clamped 320 px view centre.
	_check(get_viewport().get_camera_2d() == rift.get_camera(),
		"rift: camera returned to the player")
	_check(rift.get_camera().enabled, "rift: player camera re-enabled")
	_check(absf(cine.get_camera_center().x - 320.0) < 1.0,
		"rift: film ends on the player view", str(cine.get_camera_center().x))
	_check(not cine.get_opening_camera().enabled,
		"rift: OpeningCamera2D disabled after film")
	_check(absf(rift.get_player().global_position.x - 40.0) < 1.0,
		"rift: real player still stands at the entrance",
		str(rift.get_player().global_position.x))
	_check(rift.get_hud().visible, "rift: HUD returns after film")

	await _wait_process(80)
	_check(rift.get_hud().get_chrome_alpha() > 0.85,
		"rift: HUD chrome faded in", str(rift.get_hud().get_chrome_alpha()))
	_check(not rift.get_player().is_cinematic_locked(), "rift: player lock released")
	_check(not rift.get_boss().is_active(), "rift: boss still dormant after hand-off")
	_check(rift.get_boss().is_suspended(), "rift: boss still suspended after hand-off")
	_check(not rift.is_arena_entered(), "rift: arena not entered after hand-off")
	_check(not bool(rift.get_audio().call("is_music_playing")),
		"rift: boss BGM still off after hand-off")

	var resumed_x: float = rift.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(rift.get_player().global_position.x > resumed_x + 1.0,
		"rift: gameplay resumes after film")

	rift.call("_begin_recovery", "fall")
	await _wait_recovery(rift, 120)
	_check(not rift.is_intro_active(), "rift: failure recovery did not replay film")
	_check(rift.get_intro_cinematic() == cine,
		"rift: failure recovery kept the finished film")

	var same_cine: RiftIntroCinematic = rift.get_intro_cinematic()
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
	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "rift skip: film started")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(3)
	_check(cine.is_skipped(), "rift skip: F marks the film skipped")
	_check(not cine.is_playing(), "rift skip: film stopped immediately")
	_check(get_viewport().get_camera_2d() == rift.get_camera(),
		"rift skip: camera snapped to the player")
	_check(not cine.get_opening_camera().enabled,
		"rift skip: opening camera disabled in the same skip")
	_check(rift.was_intro_skipped(), "rift skip: chapter records skipped")
	_check(rift.has_played_intro(), "rift skip: first play recorded")
	_check(rift.get_hud().visible, "rift skip: HUD visible immediately")

	var guide: DlcGuide = await _wait_for_guide(rift, 120)
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
	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "rift space: film started")
	if cine == null:
		rift.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "rift space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= RiftIntroCinematic.SKIP_HOLD,
		"rift space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_process(3)
	_check(cine.is_skipped(), "rift space: long hold skips")
	_check(get_viewport().get_camera_2d() == rift.get_camera(),
		"rift space: camera returns before the key release")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not rift.is_intro_active(), "rift space: release hands control back")
	_check(not rift.get_player().is_cinematic_locked(),
		"rift space: player lock released")
	rift.queue_free()
	await get_tree().process_frame


## F during the pan must not leave the camera between rooms.  We wait until the
## real film time is in the pull, then skip; the only acceptable end state is
## the player camera at the gameplay view.
func _test_mid_pull_skip() -> void:
	get_tree().paused = false
	var rift: RiftWorkshop = (load(RIFT_SCENE) as PackedScene).instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(5)
	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	if cine == null:
		_check(false, "rift pull skip: film exists")
		rift.queue_free()
		await get_tree().process_frame
		return
	for _index: int in range(400):
		if cine.get_elapsed() >= 2.9:
			break
		await get_tree().process_frame
	var was_pulling: bool = cine.get_camera_center().x > 400.0
	_check(was_pulling, "rift pull skip: skip really starts inside the pan",
		str(cine.get_camera_center().x))
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(2)
	_check(not rift.is_intro_active(), "rift pull skip: F finishes at once")
	_check(cine.is_skipped(), "rift pull skip: marked skipped")
	var current_camera: Camera2D = get_viewport().get_camera_2d()
	_check(current_camera == rift.get_camera(),
		"rift pull skip: player camera current")
	_check(current_camera != null
		and absf(current_camera.get_screen_center_position().x - 320.0) < 1.0,
		"rift pull skip: no half-finished pan",
		str(current_camera.get_screen_center_position().x if current_camera else -1.0))
	rift.queue_free()
	await get_tree().process_frame


func _wait_for_guide(rift: RiftWorkshop, max_frames: int) -> DlcGuide:
	for _index: int in range(max_frames):
		var guide: DlcGuide = rift.get_intro_guide()
		if guide != null and guide.is_open():
			return guide
		await get_tree().process_frame
	return rift.get_intro_guide()


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
