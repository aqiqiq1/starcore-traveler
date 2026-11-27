extends Node

## Contract checks for the DLC3 opening film (2026-11-27 rework).
##
## The film is no longer a painted CanvasLayer: it must drive the real chapter
## through a real OpeningCamera2D, the real loom (`Boss/Core`, `NodeA`,
## `NodeB`) and the real player at the chapter start.  These checks cover:
##   - first play, HUD/input lock, no damage, boss still dormant;
##   - the real camera starts on the loom and ends on the exact player view;
##   - boss BGM stays off for the film while the real scene is used;
##   - F skip -> guide, long-Space skip, mid-pull skip snap;
##   - failure and R never replay the film.

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
	await _test_mid_pull_skip()


func _test_first_play_and_locks() -> void:
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(5)

	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null, "loom: cinematic exists on first load")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return
	_check(loom.is_intro_active(), "loom: intro active on first load")
	_check(cine.is_playing(), "loom: film is playing")
	_check(cine.get_duration() >= 3.6 and cine.get_duration() <= 4.2,
		"loom: duration in 3.6-4.2 s", str(cine.get_duration()))
	_check(cine.get_phase_name() == "LOOM_SILHOUETTE",
		"loom: opens on the real loom hall", cine.get_phase_name())

	# The film must use the chapter's real nodes, not a painted copy.
	var opening_camera: Camera2D = cine.get_opening_camera()
	_check(opening_camera != null, "loom: OpeningCamera2D exists")
	_check(get_viewport().get_camera_2d() == opening_camera,
		"loom: viewport camera is the OpeningCamera2D")
	_check(opening_camera != loom.get_camera(),
		"loom: opening camera is separate from the player camera")
	_check(not loom.get_camera().enabled,
		"loom: player camera is disabled during the film")
	_check(cine.get_core() == loom.get_core(),
		"loom: film points at the real LoomCore")
	_check(cine.get_node_a() == loom.get_node_a()
		and cine.get_node_b() == loom.get_node_b(),
		"loom: film points at the real NodeA/NodeB")
	_check(cine.get_player() == loom.get_player(),
		"loom: film points at the real player")
	_check(opening_camera.get_parent() == cine,
		"loom: opening camera lives under the film node")
	_check(cine.get_camera_center().x > 600.0,
		"loom: first shot is centred on the loom",
		str(cine.get_camera_center().x))
	_check(cine.get_camera_zoom() > 1.05,
		"loom: first shot uses a real push-in",
		str(cine.get_camera_zoom()))
	_check(cine.get_lamp_rows_lit() == 0,
		"loom: ceiling rows start dark")
	_check(cine.get_grade_alpha() > 0.6,
		"loom: first beat is dark but not a black backdrop",
		str(cine.get_grade_alpha()))

	_check(not loom.get_core().is_active(), "loom: real core not active during film")
	_check(not loom.get_node_a().is_active() and not loom.get_node_b().is_active(),
		"loom: real nodes not active during film")
	_check(not loom.is_boss_active(), "loom: boss not awake during film")
	_check(not loom.get_audio().is_music_playing(),
		"loom: boss BGM did not start during film")
	_check(not loom.get_hud().visible, "loom: HUD hidden during film")
	_check(loom.get_player().is_cinematic_locked(), "loom: player cinematic lock on")
	_check(not get_tree().paused, "loom: tree not paused during film")
	_check(not loom.get_audio().is_music_paused(), "loom: music not paused")

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

	# Wait for the three-row + shuttle beat and read the real core's frame.  The
	# film locks the real 4-frame sheet at 4 fps; 1.98 s is frame 3 (shuttle to
	# the right of the core).  The core must still be inactive.
	var shuttle_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < shuttle_deadline:
		if cine.get_elapsed() >= 1.98:
			break
		await get_tree().process_frame
	_check(cine.get_lamp_rows_lit() == 3,
		"loom: three lamp rows lit at the shuttle beat")
	_check(cine.get_core_sprite_frame() == 3,
		"loom: real 4-frame shuttle reaches frame 3",
		str(cine.get_core_sprite_frame()))
	_check(not loom.get_core().is_active(),
		"loom: real core still inactive at the shuttle beat")

	# Headless runs faster than 60 fps; the wait is a frame budget with margin,
	# not a duration assertion.  The film itself owns the 4.0 s timing.
	await _wait_until_finished(loom, 900)
	_check(not loom.is_intro_active(), "loom: film ends on its own")
	_check(loom.has_played_intro(), "loom: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(),
		"loom: natural finish not skipped")
	_check(cine.get_cue_count() >= 8, "loom: beat cues fired", str(cine.get_cue_count()))

	# The hand-off is the player camera at the exact gameplay view.  Because the
	# player waits at x=40, that is the left-clamped 320 px view centre.
	_check(get_viewport().get_camera_2d() == loom.get_camera(),
		"loom: camera returned to the player")
	_check(loom.get_camera().enabled, "loom: player camera re-enabled")
	_check(absf(cine.get_camera_center().x - 320.0) < 1.0,
		"loom: film ends on the player view", str(cine.get_camera_center().x))
	_check(not cine.get_opening_camera().enabled,
		"loom: OpeningCamera2D disabled after film")
	_check(absf(loom.get_player().global_position.x - 40.0) < 1.0,
		"loom: real player still stands at the entrance",
		str(loom.get_player().global_position.x))
	_check(loom.get_hud().visible, "loom: HUD returns after film")
	_check(loom.get_hud().get_chrome_alpha() < 0.9,
		"loom: HUD starts its 0.35 s fade", str(loom.get_hud().get_chrome_alpha()))

	await _wait_seconds(0.55)
	_check(loom.get_hud().get_chrome_alpha() > 0.85,
		"loom: HUD chrome faded in", str(loom.get_hud().get_chrome_alpha()))
	_check(not loom.get_player().is_cinematic_locked(), "loom: player lock released")
	_check(not loom.get_core().is_active(), "loom: core remains dormant after hand-off")
	_check(not loom.is_boss_active(), "loom: boss still dormant after hand-off")
	if DisplayServer.get_name() != "headless":
		_check(loom.get_audio().is_music_playing(),
			"loom: BGM starts after hand-off, not during the film")

	var resumed_x: float = loom.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(loom.get_player().global_position.x > resumed_x + 1.0,
		"loom: gameplay resumes after film")

	loom.call("_begin_recovery", "fall")
	await _wait_recovery(loom, 120)
	_check(not loom.is_intro_active(), "loom: failure recovery did not replay film")
	_check(loom.get_intro_cinematic() == cine,
		"loom: failure recovery kept the finished film")

	var same_cine: LoomIntroCinematic = loom.get_intro_cinematic()
	_push_key(KEY_R, true)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	await _wait_process(12)
	_check(not loom.is_intro_active(), "loom: R did not start a second film")
	_check(loom.get_intro_cinematic() == same_cine, "loom: no second cinematic node")
	_check(loom.has_played_intro(), "loom: first-play flag survives R")
	_check(same_cine != null and same_cine.is_finished(),
		"loom: old film stays finished")

	loom.queue_free()
	await get_tree().process_frame


func _test_f_skip_and_guide() -> void:
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = true
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(5)
	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "loom skip: film started")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_seconds(0.12)
	_check(cine.is_skipped(), "loom skip: F marks the film skipped")
	_check(not cine.is_playing(), "loom skip: film stopped immediately")
	_check(get_viewport().get_camera_2d() == loom.get_camera(),
		"loom skip: camera snapped to the player")
	_check(not cine.get_opening_camera().enabled,
		"loom skip: opening camera disabled in the same skip")
	_check(loom.was_intro_skipped(), "loom skip: chapter records skipped")
	_check(loom.has_played_intro(), "loom skip: first play recorded")
	_check(loom.get_hud().visible, "loom skip: HUD visible immediately")
	_check(loom.get_intro_guide() == null or not loom.get_intro_guide().is_open(),
		"loom skip: guide waits 0.45 s after the film")

	var guide: DlcGuide = await _wait_for_guide(loom, 120)
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
	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "loom space: film started")
	if cine == null:
		loom.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "loom space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= LoomIntroCinematic.SKIP_HOLD,
		"loom space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_process(3)
	_check(cine.is_skipped(), "loom space: long hold skips")
	_check(get_viewport().get_camera_2d() == loom.get_camera(),
		"loom space: camera returns before the key release")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not loom.is_intro_active(), "loom space: release hands control back")
	_check(not loom.get_player().is_cinematic_locked(),
		"loom space: player lock released")
	loom.queue_free()
	await get_tree().process_frame


## F during the pan must not leave the camera between rooms.  We wait until the
## real film time is in the pull, then skip; the only acceptable end state is
## the player camera at the gameplay view.
func _test_mid_pull_skip() -> void:
	get_tree().paused = false
	var loom: StarLoom = (load(LOOM_SCENE) as PackedScene).instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(5)
	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	if cine == null:
		_check(false, "loom pull skip: film exists")
		loom.queue_free()
		await get_tree().process_frame
		return
	var pull_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < pull_deadline:
		if cine.get_elapsed() >= 3.15:
			break
		await get_tree().process_frame
	var was_pulling: bool = cine.get_camera_center().x > 360.0
	_check(was_pulling, "loom pull skip: skip really starts inside the pan",
		str(cine.get_camera_center().x))
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(2)
	_check(not loom.is_intro_active(), "loom pull skip: F finishes at once")
	_check(cine.is_skipped(), "loom pull skip: marked skipped")
	var current_camera: Camera2D = get_viewport().get_camera_2d()
	_check(current_camera == loom.get_camera(),
		"loom pull skip: player camera current")
	_check(current_camera != null
		and absf(current_camera.get_screen_center_position().x - 320.0) < 1.0,
		"loom pull skip: no half-finished pan",
		str(current_camera.get_screen_center_position().x if current_camera else -1.0))
	loom.queue_free()
	await get_tree().process_frame


func _wait_for_guide(loom: StarLoom, _max_frames: int) -> DlcGuide:
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var guide: DlcGuide = loom.get_intro_guide()
		if guide != null and guide.is_open():
			return guide
		await get_tree().process_frame
	return loom.get_intro_guide()


func _wait_until_finished(loom: StarLoom, _max_frames: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if not loom.is_intro_active():
			return
		await get_tree().process_frame


func _wait_recovery(loom: StarLoom, _max_frames: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if not loom.is_recovery_active():
			return
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.001)).timeout


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
