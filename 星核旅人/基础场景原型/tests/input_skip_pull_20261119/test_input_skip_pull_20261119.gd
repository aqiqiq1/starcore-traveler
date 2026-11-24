extends Node

## 2026-11-19 input / skip / guard-pull acceptance harness.
##
## Run:
##   Godot --headless --path . \
##     res://tests/input_skip_pull_20261119/test_input_skip_pull_20261119.tscn
##
## Sections
##   A. L1 opening cinematic:
##      - a short Space tap neither completes nor advances the line;
##      - F completes the revealing line, then advances;
##      - holding Space past SKIP_HOLD skips the whole segment;
##      - control is held until the skip Space is released (no jump after).
##   B. L3 cinematic: the same four rules.
##   C. L3 guard GRAVITY_CHARGE pull at the current FIELD_ACCELERATION:
##      - a 160 px/s side pass: field-entry speed, peak speed, impulse, whether
##        the player crossed the guard and the weakpoint;
##      - release-input-at-weakpoint: coast distance past the weakpoint.
##
## Inputs are real InputEventKey events through Input.parse_input_event, not
## direct method calls. Test-only setup is limited to: disabling the L1 title
## menu, starting the L3 film through the level's own _start_cinematic() entry,
## choosing the opposite polarity, and placing the body at a known arena x.
## The guard AI, force sampling, player physics, collisions, camera and dialogue
## logic all run unmodified.

const LEVEL1_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL3_SCENE: PackedScene = preload("res://scenes/level_03.tscn")
const SKIP_HOLD: float = 0.6
const PULL_FRAME_DT: float = 1.0 / 60.0

var _passes: int = 0
var _fails: Array[String] = []
var _l1: Level01 = null
var _l3: Level03 = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run_opening()
	await _run_l3_cinematic()
	await _run_guard_pull()
	print("INPUT_SKIP_PULL_RESULT pass=%d fail=%d" % [_passes, _fails.size()])
	for failure: String in _fails:
		print("FAIL: ", failure)
	if _fails.is_empty():
		print("INPUT_SKIP_PULL_OK")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- small helpers ---------------------------------------------------------

func _check(ok: bool, label: String) -> bool:
	if ok:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails.append(label)
		print("  FAIL ", label)
	return ok


func _wait_physics(seconds: float) -> void:
	var frames: int = maxi(int(ceil(seconds * 60.0)), 1)
	for _i: int in range(frames):
		await get_tree().physics_frame


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _press(code: Key) -> void:
	Input.parse_input_event(_key_event(code, true))
	Input.flush_buffered_events()


func _release(code: Key) -> void:
	Input.parse_input_event(_key_event(code, false))
	Input.flush_buffered_events()


func _tap(code: Key, frames: int = 3) -> void:
	_press(code)
	await _wait_physics(float(frames) / 60.0)
	_release(code)
	await _wait_physics(1.0 / 60.0)


## Data-level check that the pause page really carries the new two-key wording.
func _controls_mention_dialogue_keys(menu: Node) -> bool:
	if menu == null:
		return false
	var rows: Variant = menu.get("controls_rows")
	if not (rows is Array):
		return false
	var text: String = ""
	for row: Variant in rows as Array:
		if row is Array:
			for cell: Variant in row as Array:
				text += String(cell) + " | "
	return text.contains("F继续") and text.contains("长按空格跳过整段")


# --- A. L1 opening ---------------------------------------------------------

func _run_opening() -> void:
	print("== A. L1 opening cinematic ==")
	_l1 = LEVEL1_SCENE.instantiate() as Level01
	_l1.enable_start_menu = false
	add_child(_l1)
	await _wait_physics(0.25)

	var opening: OpeningCinematic = _l1.get_opening()
	var echo: GuideEcho = _l1.get_narrative_guide()
	var player: PrototypePlayer = _l1.get_player()
	if not _check(opening != null and player != null and echo != null, "L1 opening/player/echo exist"):
		return
	if not _check(opening.is_playing(), "L1 opening auto-started"):
		return
	_check(
		_controls_mention_dialogue_keys(_l1.get_pause_menu()),
		"L1 pause controls show F advance + long-Space skip"
	)

	var reached: bool = await _wait_until(
		func() -> bool: return opening.get_phase_name() == "DIALOGUE", 20.0
	)
	if not _check(reached, "L1 opening reached DIALOGUE"):
		return
	var page_open: bool = await _wait_until(
		func() -> bool: return echo.is_dialogue_open(), 3.0
	)
	if not _check(page_open, "L1 first echo page opened"):
		return

	await _wait_physics(0.15)
	var full: String = echo.get_current_page_text()
	var shown: int = echo.get_revealed_count()
	_check(echo.get_page_index() == 0, "L1 starts on page 1/1")
	_check(shown < full.length(), "L1 line is still revealing before input")

	# Short Space: inert.
	await _tap(KEY_SPACE, 3)
	_check(echo.get_page_index() == 0, "L1 short Space did not advance the page")
	_check(echo.get_revealed_count() < full.length(), "L1 short Space did not complete the line")
	_check(opening.get_space_hold_time() < SKIP_HOLD, "L1 short Space stayed under SKIP_HOLD")
	_check(not opening.is_awaiting_release(), "L1 short Space did not skip")

	# F: complete, then advance.
	await _tap(KEY_F, 3)
	_check(echo.get_page_text() == full, "L1 F completed the revealing line")
	_check(echo.get_page_index() == 0, "L1 F completion stayed on the same page")
	await _tap(KEY_F, 3)
	_check(echo.get_page_index() == 1, "L1 second F advanced to page 2")

	# Long Space: skip the whole segment (never page-by-page).
	_press(KEY_SPACE)
	await _wait_physics(SKIP_HOLD + 0.10)
	var outro_phase: String = String(opening.get_phase_name())
	_check(
		outro_phase == "OUTRO" or outro_phase == "AWAIT_RELEASE" or opening.is_awaiting_release(),
		"L1 long Space skipped the whole segment"
	)
	var boundary: bool = await _wait_until(
		func() -> bool: return opening.is_awaiting_release() or not opening.is_active(), 2.0
	)
	_check(boundary, "L1 skip reached the hand-off boundary while Space held")
	_check(opening.is_awaiting_release(), "L1 held Space keeps control until release")

	_release(KEY_SPACE)
	await _wait_physics(0.12)
	_check(not opening.is_active(), "L1 control returned after Space release")
	_check(not echo.is_dialogue_open(), "L1 echo page closed by the skip")
	_check(not _l1.is_intro_active(), "L1 level intro state cleared")
	_check(opening.is_skipped(), "L1 opening recorded skipped=true")

	var y_before: float = player.global_position.y
	await _wait_physics(0.25)
	_check(
		player.velocity.y >= -1.0 and absf(player.global_position.y - y_before) < 1.0,
		"L1 no jump from the skip Space after hand-off"
	)

	_l1.queue_free()
	await _wait_physics(0.1)
	_l1 = null


# --- B. L3 cinematic -------------------------------------------------------

func _run_l3_cinematic() -> void:
	print("== B. L3 cinematic ==")
	_l3 = LEVEL3_SCENE.instantiate() as Level03
	add_child(_l3)
	await _wait_physics(0.35)

	var cine: L3Cinematic = _l3.get_cine()
	var player: L3Player = _l3.get_player()
	if not _check(cine != null and player != null, "L3 cinematic/player exist"):
		return
	# The level's own cinematic entry (same as the real trigger path).
	_l3.call("_start_cinematic")
	await _wait_physics(0.1)
	if not _check(cine.is_playing(), "L3 cinematic started"):
		return
	_check(
		_controls_mention_dialogue_keys(_l3.get_pause_menu()),
		"L3 pause controls show F advance + long-Space skip"
	)

	var reached: bool = await _wait_until(
		func() -> bool: return cine.get_phase_name() == "DIALOGUE", 20.0
	)
	if not _check(reached, "L3 cinematic reached DIALOGUE"):
		return
	var page_open: bool = await _wait_until(
		func() -> bool: return cine.is_bubble_visible() and cine.get_page_index() == 0, 3.0
	)
	if not _check(page_open, "L3 first page bubble opened"):
		return

	await _wait_physics(0.15)
	var full: String = cine.get_full_page_text()
	_check(cine.get_body_text().length() < full.length(), "L3 line is still revealing before input")

	# Short Space: inert.
	await _tap(KEY_SPACE, 3)
	_check(cine.get_page_index() == 0, "L3 short Space did not advance the page")
	_check(cine.get_body_text() != full, "L3 short Space did not complete the line")
	_check(not cine.is_awaiting_release(), "L3 short Space did not skip")

	# F: complete, then advance.
	await _tap(KEY_F, 3)
	_check(cine.get_body_text() == full, "L3 F completed the revealing line")
	_check(cine.get_page_index() == 0, "L3 F completion stayed on the same page")
	await _tap(KEY_F, 3)
	_check(cine.get_page_index() == 1, "L3 second F advanced to page 2")

	# Long Space: skip the whole segment.
	_press(KEY_SPACE)
	await _wait_physics(SKIP_HOLD + 0.10)
	_check(bool(cine.get("_skipped")), "L3 long Space recorded skipped=true")
	var boundary: bool = await _wait_until(
		func() -> bool: return cine.is_awaiting_release() or not cine.is_active(), 2.0
	)
	_check(boundary, "L3 skip reached the hand-off boundary while Space held")
	_check(cine.is_awaiting_release(), "L3 held Space keeps control until release")

	_release(KEY_SPACE)
	await _wait_physics(0.12)
	_check(not cine.is_active(), "L3 control returned after Space release")
	_check(not cine.is_bubble_visible(), "L3 dialogue bubble closed by the skip")

	var y_before: float = player.global_position.y
	await _wait_physics(0.25)
	_check(
		player.velocity.y >= -1.0 and absf(player.global_position.y - y_before) < 1.0,
		"L3 no jump from the skip Space after hand-off"
	)

	_l3.queue_free()
	await _wait_physics(0.15)
	_l3 = null


# --- C. guard pull ---------------------------------------------------------

func _run_guard_pull() -> void:
	print("== C. L3 guard GRAVITY_CHARGE pull ==")
	_l3 = LEVEL3_SCENE.instantiate() as Level03
	add_child(_l3)
	await _wait_physics(0.45)

	var guard: L3Guard = _l3.get_guard()
	var player: L3Player = _l3.get_player()
	if not _check(guard != null and player != null, "L3 guard/player available"):
		return
	var tuning: Dictionary = guard.get_field_tuning()
	var acceleration: float = float(tuning.get("acceleration", 0.0))
	print(
		"PULL_TUNING acceleration=%.1f range=%.1f inner=%.1f full=%.1f fade=%.1f"
		% [
			acceleration,
			float(tuning.get("range", 0.0)),
			float(tuning.get("inner", 0.0)),
			float(tuning.get("full", 0.0)),
			float(tuning.get("fade", 0.0)),
		]
	)
	_check(is_equal_approx(acceleration, 520.0), "FIELD_ACCELERATION is 520.0")
	_check(
		is_equal_approx(float(tuning.get("range", 0.0)), 118.0)
		and is_equal_approx(float(tuning.get("inner", 0.0)), 16.0)
		and is_equal_approx(float(tuning.get("full", 0.0)), 42.0)
		and is_equal_approx(float(tuning.get("fade", 0.0)), 24.0),
		"field range/inner/full/fade unchanged"
	)

	# The positive guard attracts only an opposite (negative) player.
	player.set_polarity_state(false)
	_check(not player.is_positive(), "player set to the opposite polarity (attract)")

	var pass_result: Dictionary = await _pull_pass_through(guard, player)
	# Park the body well away from the guard before the next charge, so the
	# guard's own alert/attack branches cannot interfere with the second run.
	_place_player(player, guard.global_position.x - 250.0)
	await _wait_for_guard_active(guard)
	var stop_result: Dictionary = await _pull_stop_near_weakpoint(guard, player)
	_place_player(player, guard.global_position.x - 250.0)
	await _wait_for_guard_active(guard)
	var early_result: Dictionary = await _pull_stop_early(guard, player)

	print("PULL_PASS acceleration=%.1f" % acceleration)
	for key: String in pass_result.keys():
		print("PULL_PASS %s=%s" % [key, str(pass_result[key])])
	print("PULL_STOP acceleration=%.1f" % acceleration)
	for key: String in stop_result.keys():
		print("PULL_STOP %s=%s" % [key, str(stop_result[key])])
	print("PULL_EARLY acceleration=%.1f" % acceleration)
	for key: String in early_result.keys():
		print("PULL_EARLY %s=%s" % [key, str(early_result[key])])

	# Same geometry, old constant: linear per-tick comparison (the trajectory
	# would differ slightly, so this is a theoretical impulse, not a re-run).
	var old_ratio: float = 750.0 / maxf(acceleration, 1.0)
	print(
		"PULL_OLD750_THEORY impulse_ratio=%.4f pass_pre_cross_extra=%.2f"
		% [
			old_ratio,
			float(pass_result.get("impulse_pre_cross_dv", 0.0)) * old_ratio,
		]
	)
	print(
		"PULL_OLD750_THEORY max_accel=%.1f (measured %.1f x %.4f)"
		% [float(pass_result.get("max_accel", 0.0)) * old_ratio, acceleration, old_ratio]
	)

	_check(
		bool(pass_result.get("crossed_weakpoint", false)),
		"160 px/s pass still crosses the guard weakpoint (not hard-locked)"
	)
	_check(
		float(pass_result.get("max_accel", 0.0)) <= acceleration + 0.5,
		"sampled pull acceleration never exceeds FIELD_ACCELERATION"
	)

	_l3.queue_free()
	await _wait_physics(0.15)
	_l3 = null


func _wait_for_guard_active(guard: L3Guard) -> void:
	var ok: bool = await _wait_until(
		func() -> bool:
			var state: String = String(guard.get_state_name())
			return state == "ACTIVE" or state == "WAIT_RUBBLE" or state == "DEAD",
		5.0
	)
	if not ok:
		print("  ! guard did not return to ACTIVE before the second run")


func _place_player(player: L3Player, x: float) -> void:
	player.global_position = Vector2(x, 320.0)
	player.velocity = Vector2.ZERO
	player.clear_input_buffers()
	player.clear_external_force()


## Run in from outside the field and start the gravity charge when the body is
## already at the shared 160 px/s run speed and close to the field edge.
func _run_to_pre_field(guard: L3Guard, player: L3Player) -> void:
	_place_player(player, guard.global_position.x - 320.0)
	player.begin_input_override()
	player.set_input_override_axis(1.0, true)
	var frames: int = 0
	while player.global_position.x < guard.global_position.x - 152.0 and frames < 180:
		frames += 1
		await get_tree().physics_frame


## Run through the field from the left at the shared 160 px/s run speed.
func _pull_pass_through(guard: L3Guard, player: L3Player) -> Dictionary:
	var result: Dictionary = {}
	await _run_to_pre_field(guard, player)
	guard.debug_force_gravity()
	await _wait_physics(2.0 / 60.0)
	var chest: Vector2 = guard.get_chest_global_position()
	var run_start_x: float = player.global_position.x
	var entry_speed: float = player.velocity.x

	var peak_speed: float = 0.0
	var max_accel: float = 0.0
	var impulse_pre_cross: float = 0.0
	var time_above_run: float = 0.0
	var crossed_weakpoint: bool = false
	var crossed_guard: bool = false
	var frames: int = 0
	while String(guard.get_state_name()) == "GRAVITY_CHARGE" and frames < 180:
		var center: Vector2 = player.global_position + Vector2(0.0, -15.0)
		var sample: Dictionary = guard.sample_player_force(center, player.is_positive(), player.get_rid())
		var force: Vector2 = sample.get("acceleration", Vector2.ZERO)
		if absf(force.x) > 0.1 and player.global_position.x < chest.x:
			impulse_pre_cross += force.x * PULL_FRAME_DT
		max_accel = maxf(max_accel, absf(force.x))
		peak_speed = maxf(peak_speed, absf(player.velocity.x))
		if absf(player.velocity.x) > 160.5:
			time_above_run += PULL_FRAME_DT
		if player.global_position.x > chest.x:
			crossed_weakpoint = true
		if player.global_position.x > guard.global_position.x:
			crossed_guard = true
		frames += 1
		await get_tree().physics_frame

	var end_x: float = player.global_position.x
	player.set_input_override_axis(0.0, false)
	await _wait_physics(0.05)

	result["run_start_x"] = snappedf(run_start_x, 0.01)
	result["chest_x"] = snappedf(chest.x, 0.01)
	result["entry_speed"] = snappedf(entry_speed, 0.01)
	result["peak_speed"] = snappedf(peak_speed, 0.01)
	result["max_accel"] = snappedf(max_accel, 0.01)
	result["impulse_pre_cross_dv"] = snappedf(impulse_pre_cross, 0.01)
	result["time_above_run_s"] = snappedf(time_above_run, 0.001)
	result["frames_in_charge"] = frames
	result["end_x_minus_chest"] = snappedf(end_x - chest.x, 0.01)
	result["crossed_weakpoint"] = crossed_weakpoint
	result["crossed_guard"] = crossed_guard
	result["velocity_cap_reached"] = peak_speed >= 319.0
	return result


## Run in, then release input when the body is 24 px left of the weakpoint and
## measure how far the still-pulling field carries the body past it.
func _pull_stop_near_weakpoint(guard: L3Guard, player: L3Player) -> Dictionary:
	var result: Dictionary = {}
	await _run_to_pre_field(guard, player)
	guard.debug_force_gravity()
	await _wait_physics(2.0 / 60.0)
	var chest: Vector2 = guard.get_chest_global_position()

	var frames: int = 0
	while player.global_position.x < chest.x - 24.0 and frames < 150:
		frames += 1
		await get_tree().physics_frame

	var release_x: float = player.global_position.x
	var release_speed: float = player.velocity.x
	player.set_input_override_axis(0.0, false)

	var stop_frames: int = 0
	var trace: Array[String] = []
	while absf(player.velocity.x) > 1.0 and stop_frames < 150:
		if stop_frames % 4 == 0:
			var sample: Dictionary = guard.sample_player_force(
				player.global_position + Vector2(0.0, -15.0), player.is_positive(), player.get_rid()
			)
			var force: Vector2 = sample.get("acceleration", Vector2.ZERO)
			trace.append(
				"f%d vx=%.1f x=%.1f floor=%s force=%.1f y=%.1f"
				% [
					stop_frames,
					player.velocity.x,
					player.global_position.x - chest.x,
					str(player.is_on_floor()),
					force.x,
					player.global_position.y,
				]
			)
		stop_frames += 1
		await get_tree().physics_frame
	var rest_x: float = player.global_position.x
	var still_charging: bool = String(guard.get_state_name()) == "GRAVITY_CHARGE"
	await _wait_physics(0.05)

	result["release_x_minus_chest"] = snappedf(release_x - chest.x, 0.01)
	result["release_speed"] = snappedf(release_speed, 0.01)
	result["rest_x_minus_chest"] = snappedf(rest_x - chest.x, 0.01)
	result["coast_past_release"] = snappedf(rest_x - release_x, 0.01)
	result["passed_weakpoint"] = rest_x > chest.x
	result["charge_still_active_at_rest"] = still_charging
	result["rest_on_floor"] = player.is_on_floor()
	result["rest_y"] = snappedf(player.global_position.y, 0.01)
	result["stop_frames"] = stop_frames
	result["approach_frames"] = frames
	result["player_hits"] = _l3.get_player_hits() if _l3 != null else -1
	result["trace"] = trace
	return result


## Clean comparison point: release the run key 60 px before the weakpoint, so
## the whole stop happens inside the charge and before the release ring.
func _pull_stop_early(guard: L3Guard, player: L3Player) -> Dictionary:
	var result: Dictionary = {}
	await _run_to_pre_field(guard, player)
	guard.debug_force_gravity()
	await _wait_physics(2.0 / 60.0)
	var chest: Vector2 = guard.get_chest_global_position()

	var frames: int = 0
	while player.global_position.x < chest.x - 60.0 and frames < 150:
		frames += 1
		await get_tree().physics_frame

	var release_x: float = player.global_position.x
	var release_speed: float = player.velocity.x
	player.set_input_override_axis(0.0, false)

	var stop_frames: int = 0
	while absf(player.velocity.x) > 1.0 and stop_frames < 120:
		stop_frames += 1
		await get_tree().physics_frame
	var rest_x: float = player.global_position.x
	var still_charging: bool = String(guard.get_state_name()) == "GRAVITY_CHARGE"
	var hits: int = _l3.get_player_hits() if _l3 != null else -1
	await _wait_physics(0.05)

	result["release_x_minus_chest"] = snappedf(release_x - chest.x, 0.01)
	result["release_speed"] = snappedf(release_speed, 0.01)
	result["rest_x_minus_chest"] = snappedf(rest_x - chest.x, 0.01)
	result["coast_past_release"] = snappedf(rest_x - release_x, 0.01)
	result["overshoot_past_weakpoint"] = snappedf(rest_x - chest.x, 0.01)
	result["charge_still_active_at_rest"] = still_charging
	result["player_hits"] = hits
	result["stop_frames"] = stop_frames
	return result
