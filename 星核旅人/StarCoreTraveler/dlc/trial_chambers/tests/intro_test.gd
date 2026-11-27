extends Node

## Contract checks for the DLC1 opening film (2026-11-27 rework).
##
## The film is no longer a painted CanvasLayer: it must drive the real chapter
## through a real OpeningCamera2D, the real locked GateGold (sun plate, padlock
## and 8 px curtain), the real gold PhaseCrystal, the real sealed cyan twin and
## the real player at the entrance.  These checks cover:
##   - first play, HUD/input lock, no damage, real gate still locked;
##   - camera ownership before/after and the exact player view after the pan;
##   - the gate's phase rule is unchanged (player still 澜相, gold gate locked);
##   - F skip -> guide, long-Space skip, mid-pull skip;
##   - failure and R never replay the film.

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
	await _test_mid_pull_skip()


func _test_first_play_and_locks() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(5)

	var cine: TrialIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null, "trial: cinematic exists on first load")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return
	_check(trial.is_intro_active(), "trial: intro active on first load")
	_check(cine.is_playing(), "trial: film is playing")
	_check(cine.get_duration() >= 3.0 and cine.get_duration() <= 3.6,
		"trial: duration in 3.0-3.6 s", str(cine.get_duration()))
	_check(cine.get_phase_name() == "GATE_HELD",
		"trial: opens on the real locked gate", cine.get_phase_name())

	# The film must use the chapter's real nodes, not a painted copy.
	var opening_camera: Camera2D = cine.get_opening_camera()
	var gate: PolarityGate = trial.get_gate_gold()
	var crystal: TrialPhaseCrystal = trial.get_phase_crystal()
	var relic: TrialSealedCrystal = trial.get_sealed_crystal()
	_check(opening_camera != null, "trial: OpeningCamera2D exists")
	_check(get_viewport().get_camera_2d() == opening_camera,
		"trial: viewport camera is the OpeningCamera2D")
	_check(opening_camera != trial.get_camera(),
		"trial: opening camera is separate from the player camera")
	_check(not trial.get_camera().enabled,
		"trial: player camera is disabled during the film")
	_check(cine.get_gate() == gate, "trial: film points at the real gold gate")
	_check(cine.get_crystal() == crystal,
		"trial: film points at the real gold crystal")
	_check(cine.get_relic() == relic,
		"trial: film points at the real sealed cyan twin")
	_check(cine.get_player() == trial.get_player(),
		"trial: film points at the real player")
	_check(opening_camera.get_parent() == cine,
		"trial: opening camera lives under the film node")
	_check(cine.get_gate_emblem_world_position()
		== gate.get_emblem_center_global(),
		"trial: lock rings are anchored to the real emblem plate")
	_check(cine.get_crystal_world_position()
		== crystal.get_shard_center_global(),
		"trial: gold halo is anchored to the real crystal")
	_check(cine.get_relic_world_position()
		== relic.get_shard_center_global(),
		"trial: cyan halo is anchored to the real sealed twin")
	_check(relic.is_display_only(),
		"trial: the cyan twin is display-only, not a second key")
	_check(gate.get_required_positive(),
		"trial: gold gate still requires 辉相")
	_check(gate.get_lock_state() == "locked",
		"trial: gold gate is really locked during the film")
	_check(not trial.get_player().is_positive(),
		"trial: player still starts 澜相; the film did not flip it")

	var start_center: Vector2 = cine.get_camera_center()
	_check(absf(start_center.x - 280.0) < 1.0,
		"trial: film opens on the gate at x=280", str(start_center.x))
	_check(cine.get_camera_zoom() > 1.5 and cine.get_camera_zoom() < 1.7,
		"trial: gate view uses a real 1.6 zoom", str(cine.get_camera_zoom()))
	_check(trial.get_player().global_position.x < 42.0,
		"trial: real player waits at the entrance",
		str(trial.get_player().global_position.x))

	_check(trial.get_guard().is_suspended(), "trial: guard suspended during film")
	_check(trial.get_player().is_cinematic_locked(),
		"trial: player cinematic lock on")
	_check(not get_tree().paused, "trial: tree not paused during film")
	_check(trial.get_ambience().is_playing(),
		"trial: chapter music continues")
	_check(not trial.get_hud().visible, "trial: HUD hidden during film")
	_check(cine.get_grade_alpha() > 0.4,
		"trial: first beat is dark but not a black backdrop",
		str(cine.get_grade_alpha()))
	_check(cine.get_gold_lit_amount() < 0.05,
		"trial: gold crystal starts unlit", str(cine.get_gold_lit_amount()))
	_check(cine.get_cyan_lit_amount() < 0.05,
		"trial: cyan twin starts unlit", str(cine.get_cyan_lit_amount()))

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

	# Beat order: gold first, cyan second, then the lock/seam.  These are read
	# from the live film timeline, not forced states.
	await _wait_until_elapsed(cine, 1.12, 300)
	_check(cine.get_gold_lit_amount() > 0.45,
		"trial: gold crystal lights first",
		str(cine.get_gold_lit_amount()))
	_check(cine.get_cyan_lit_amount() < 0.10,
		"trial: cyan twin is still dark at the gold beat",
		str(cine.get_cyan_lit_amount()))
	await _wait_until_elapsed(cine, 1.62, 300)
	_check(cine.get_cyan_lit_amount() > 0.90,
		"trial: cyan twin lights second",
		str(cine.get_cyan_lit_amount()))
	_check(cine.get_lock_turn_amount() > 0.40,
		"trial: the real-plate lock rings are turning",
		str(cine.get_lock_turn_amount()))
	_check(cine.get_seam_amount() > 0.10,
		"trial: the warm seam light has started",
		str(cine.get_seam_amount()))

	# Headless runs faster than 60 fps; the wait is a frame budget with margin,
	# not a duration assertion.  The film itself owns the 3.4 s timing.
	await _wait_until_finished(trial, 900)
	_check(not trial.is_intro_active(), "trial: film ends on its own")
	_check(trial.has_played_intro(), "trial: first play recorded")
	_check(cine.is_finished() and not cine.is_skipped(),
		"trial: natural finish not skipped")
	_check(cine.get_cue_count() >= 4, "trial: beat cues fired",
		str(cine.get_cue_count()))

	# The hand-off is the player camera at the exact gameplay view.  Because the
	# player waits at x=40, that is the left-clamped 320 px view centre.
	_check(get_viewport().get_camera_2d() == trial.get_camera(),
		"trial: camera returned to the player")
	_check(trial.get_camera().enabled, "trial: player camera re-enabled")
	_check(absf(cine.get_camera_center().x - 320.0) < 1.0,
		"trial: film ends on the player view", str(cine.get_camera_center().x))
	_check(absf(cine.get_camera_center().y - 180.0) < 1.0,
		"trial: film ends on the gameplay height", str(cine.get_camera_center().y))
	_check(not cine.get_opening_camera().enabled,
		"trial: OpeningCamera2D disabled after film")
	_check(absf(trial.get_player().global_position.x - 40.0) < 1.0,
		"trial: real player still stands at the entrance",
		str(trial.get_player().global_position.x))
	_check(not trial.get_player().is_positive(),
		"trial: player is still 澜相 after the film")
	_check(gate.get_lock_state() == "locked",
		"trial: gold gate is still locked after the film")
	_check(trial.get_hud().visible, "trial: HUD returns after film")

	await _wait_process(120)
	_check(trial.get_hud().get_chrome_alpha() > 0.85,
		"trial: HUD chrome faded in",
		str(trial.get_hud().get_chrome_alpha()))
	_check(not trial.get_player().is_cinematic_locked(),
		"trial: player lock released")
	_check(trial.get_guard().is_suspended(),
		"trial: guard still suspended after hand-off")
	_check(not trial.is_arena_entered(),
		"trial: arena not entered after hand-off")
	_check(trial.get_ambience().is_playing(),
		"trial: chapter music still continues after hand-off")

	var resumed_x: float = trial.get_player().global_position.x
	Input.action_press(&"move_right")
	await _wait_physics(8)
	Input.action_release(&"move_right")
	_check(trial.get_player().global_position.x > resumed_x + 1.0,
		"trial: gameplay resumes after film")

	# A real failure/recovery reset is also in-place and must not replay.
	trial.call("_begin_recovery", "fall")
	await _wait_recovery(trial, 160)
	_check(not trial.is_intro_active(),
		"trial: failure recovery did not replay film")
	_check(trial.get_intro_cinematic() == cine,
		"trial: failure recovery kept the finished film")

	# R restarts in place and must not create/replay the film.
	var same_cine: TrialIntroCinematic = trial.get_intro_cinematic()
	_push_key(KEY_R, true)
	_push_key(KEY_R, false)
	await _wait_physics(8)
	await _wait_process(12)
	_check(not trial.is_intro_active(), "trial: R did not start a second film")
	_check(trial.get_intro_cinematic() == same_cine,
		"trial: no second cinematic node")
	_check(trial.has_played_intro(), "trial: first-play flag survives R")
	_check(same_cine != null and same_cine.is_finished(),
		"trial: old film stays finished")

	trial.queue_free()
	await get_tree().process_frame


func _test_f_skip_and_guide() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = true
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(5)
	var cine: TrialIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "trial skip: film started")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(3)
	_check(cine.is_skipped(), "trial skip: F marks the film skipped")
	_check(not cine.is_playing(), "trial skip: film stopped immediately")
	_check(get_viewport().get_camera_2d() == trial.get_camera(),
		"trial skip: camera snapped to the player")
	_check(not cine.get_opening_camera().enabled,
		"trial skip: opening camera disabled in the same skip")
	_check(trial.was_intro_skipped(), "trial skip: chapter records skipped")
	_check(trial.has_played_intro(), "trial skip: first play recorded")
	_check(trial.get_hud().visible, "trial skip: HUD visible immediately")

	var guide: DlcGuide = await _wait_for_guide(trial, 180)
	_check(guide != null and guide.is_open(),
		"trial skip: intro guide opens after the hand-off beat")
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
	var cine: TrialIntroCinematic = trial.get_intro_cinematic()
	_check(cine != null and cine.is_playing(), "trial space: film started")
	if cine == null:
		trial.queue_free()
		await get_tree().process_frame
		return

	_push_key(KEY_SPACE, true)
	await _wait_physics(10)
	_check(cine.is_skip_bar_visible(), "trial space: hold bar visible")
	await _wait_physics(35)
	_check(cine.get_space_hold_time() >= TrialIntroCinematic.SKIP_HOLD,
		"trial space: hold threshold reached", str(cine.get_space_hold_time()))
	await _wait_process(3)
	_check(cine.is_skipped(), "trial space: long hold skips")
	_check(get_viewport().get_camera_2d() == trial.get_camera(),
		"trial space: camera returns before the key release")
	_push_key(KEY_SPACE, false)
	await _wait_process(4)
	_check(not trial.is_intro_active(),
		"trial space: release hands control back")
	_check(not trial.get_player().is_cinematic_locked(),
		"trial space: player lock released")
	trial.queue_free()
	await get_tree().process_frame


## F during the pull must not leave the camera between the gate and the player.
## We wait until the real film time is inside the pull, then skip; the only
## acceptable end state is the player camera at the gameplay view.
func _test_mid_pull_skip() -> void:
	get_tree().paused = false
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(5)
	var cine: TrialIntroCinematic = trial.get_intro_cinematic()
	if cine == null:
		_check(false, "trial pull skip: film exists")
		trial.queue_free()
		await get_tree().process_frame
		return
	for _index: int in range(500):
		if cine.get_elapsed() >= 2.9:
			break
		await get_tree().process_frame
	var was_pulling: bool = cine.get_camera_zoom() > 1.02 \
		and cine.get_camera_center().x > 281.0 \
		and cine.get_camera_center().x < 320.0
	_check(was_pulling, "trial pull skip: skip really starts inside the pull",
		"zoom=%.2f centre=%.1f" % [cine.get_camera_zoom(), cine.get_camera_center().x])
	_push_key(KEY_F, true)
	_push_key(KEY_F, false)
	await _wait_process(2)
	_check(not trial.is_intro_active(), "trial pull skip: F finishes at once")
	_check(cine.is_skipped(), "trial pull skip: marked skipped")
	var current_camera: Camera2D = get_viewport().get_camera_2d()
	_check(current_camera == trial.get_camera(),
		"trial pull skip: player camera current")
	_check(current_camera != null
		and absf(current_camera.get_screen_center_position().x - 320.0) < 1.0,
		"trial pull skip: no half-finished pan",
		str(current_camera.get_screen_center_position().x if current_camera else -1.0))
	_check(absf(trial.get_gate_gold().modulate.r - 1.0) < 0.01,
		"trial pull skip: real gate look restored",
		str(trial.get_gate_gold().modulate))
	trial.queue_free()
	await get_tree().process_frame


func _wait_for_guide(trial: TrialChambers, max_frames: int) -> DlcGuide:
	for _index: int in range(max_frames):
		var guide: DlcGuide = trial.get_intro_guide()
		if guide != null and guide.is_open():
			return guide
		await get_tree().process_frame
	return trial.get_intro_guide()


func _wait_until_finished(trial: TrialChambers, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if not trial.is_intro_active():
			return
		await get_tree().process_frame


func _wait_until_elapsed(cine: TrialIntroCinematic, target: float, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if cine.get_elapsed() >= target or not cine.is_playing():
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
