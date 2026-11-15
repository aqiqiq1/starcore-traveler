extends Node

## Independent near-follow acceptance test for the 100 px star-core field.
##
## This is not the main interaction runner. It uses the standalone room and real
## InputMap actions at 60 Hz to measure:
##   - normal-walk trailing distance (target roughly 30..60 px),
##   - stop approach and tail stability (no violent jitter),
##   - target store -> re-release -> return store under the same field,
##   - same-sign repulsion and a run that leaves the range with no chase.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/follow_near_distance.tscn

const SCENE: PackedScene = preload("res://scenes/star_core_interaction_standalone.tscn")

var _standalone: Node2D
var _room: StarCoreInteractionRoom
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _pass_count: int = 0
var _fail_count: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_standalone = SCENE.instantiate() as Node2D
	add_child(_standalone)
	await get_tree().process_frame
	await get_tree().physics_frame
	_room = _standalone.get_room()
	_player = _standalone.get_player()
	_hud = _standalone.get_hud()

	_log("Star Core Traveler - near-follow test (100 px trial)")
	_log("Godot %s  physics=%s" % [
		Engine.get_version_info()["string"],
		str(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")),
	])

	_section("DEFAULT FIELD")
	_check(_room.get_interaction_range() >= 95.0
		and _room.get_interaction_range() <= 105.0,
		"trial range is about 100 px", "%.1f" % _room.get_interaction_range())
	_check(_room.inner_radius >= 30.0 and _room.inner_radius <= 45.0,
		"stable inner zone is about 30..45 px", "%.1f" % _room.inner_radius)
	_check(_room.full_radius > _room.inner_radius
		and _room.full_radius < _room.get_interaction_range(),
		"full-strength band starts before the outer edge",
		"%.1f" % _room.full_radius)
	_check(_room.outer_fade > 0.0, "outer fade is present", "%.1f" % _room.outer_fade)
	var near_zone: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(330.0, 312.0), true, false
	)
	_check(String(near_zone["status"]).contains("NEAR")
		and (near_zone["core_acceleration"] as Vector2).is_zero_approx(),
		"near stable zone has zero force, not a position snap")
	var zero: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(300.0, 305.0), true, false
	)
	_check(is_finite((zero["core_acceleration"] as Vector2).x),
		"zero distance stays finite and safe")

	await _run_full_loop()
	await _run_stop_resume()
	await _run_same_sign_and_range_boundary()

	_log("")
	_log("RESULT pass=%d fail=%d skipped=0" % [_pass_count, _fail_count])
	_write_log()
	print("FOLLOW_NEAR_DISTANCE_RESULT pass=%d fail=%d" % [_pass_count, _fail_count])
	_standalone.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _fail_count > 0 else 0)


func _run_full_loop() -> void:
	_section("GOLD -> CYAN WALK FOLLOW / TARGET STORE / RETURN")
	await _reset()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active() and not _room.get_core().is_positive(),
		"GOLD player E releases an active CYAN core without Q")

	var right: Dictionary = await _walk_right_sample(552.0)
	_log("  walk right: ticks=%d trail(min/mean/max)=%.1f/%.1f/%.1f out=%d core_max_v=%.0f" % [
		right["ticks"], right["min"], right["mean"], right["max"],
		right["out_ticks"], right["core_max_speed"],
	])
	_check(right["ticks"] > 150, "normal walk produced enough trailing samples")
	_check(right["out_ticks"] == 0, "normal walk never leaves the 100 px field")
	_check(right["min"] >= 30.0 and right["min"] <= 60.0,
		"steady walk trailing minimum is in the 30..60 px band",
		"min=%.1f" % right["min"])
	_check(right["mean"] >= 30.0 and right["mean"] <= 60.0,
		"steady walk trailing mean is in the 30..60 px band",
		"mean=%.1f" % right["mean"])
	_check(right["max"] <= 60.0,
		"steady walk trailing maximum stays at or below 60 px",
		"max=%.1f" % right["max"])
	_check(right["core_max_speed"] <= _room.get_core().get_max_speed() + 0.1,
		"core never exceeds its 120 px/s cap",
		"%.1f" % right["core_max_speed"])
	_check(_room.get_target_bay().is_open_empty() and not _room.is_success(),
		"walking without E never auto-stores or auto-succeeds")

	var stop: Dictionary = await _stop_sample()
	_log("  stop right: gap_start=%.1f gap_end=%.1f core_v=%.1f jitter=%.2f player_drift=%.2f core_drift=%.2f" % [
		stop["gap_start"], stop["gap_end"], stop["end_speed"], stop["jitter"],
		stop["player_drift"], stop["core_drift"],
	])
	_check(stop["gap_end"] >= 20.0 and stop["gap_end"] <= 60.0,
		"walk stop settles at a readable near distance",
		"gap=%.1f" % stop["gap_end"])
	_check(stop["end_speed"] < 1.0, "core is at rest after stopping",
		"vx=%.1f" % stop["end_speed"])
	_check(stop["jitter"] < 2.0, "tail distance does not jitter",
		"%.2f px" % stop["jitter"])
	_check(absf(stop["player_drift"]) < 8.0,
		"player does not glide after releasing the walk key",
		"drift=%.2f px" % stop["player_drift"])
	_check(stop["tail_player_jitter"] < 2.0 and stop["tail_core_jitter"] < 2.0,
		"both bodies are stationary in the stop tail",
		"player=%.2f core=%.2f px" % [
			stop["tail_player_jitter"], stop["tail_core_jitter"]
		])
	_check(_room.get_target_bay().is_core_in_store_zone(_room.get_core().global_position)
		and _room.get_target_bay().is_player_in_range(_player.global_position),
		"core settles in the target seat with the player in bay range")
	_check(_hud.get_interaction_e_text().contains("STORE CORE (TARGET)"),
		"three-party E store becomes available", _hud.get_interaction_e_text())

	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_store_bay() == _room.get_target_bay()
		and not _room.get_core().is_active(),
		"E manually stores the core in the target")
	_check(_room.is_success(), "target store reports success")
	await _wait_until(func() -> bool: return _room.get_target_bay().is_locked(), 40)
	_check(_room.get_target_bay().is_locked(), "target bay finishes closing")

	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active() and _room.get_core().global_position.x > 450.0,
		"target re-release creates a core on the away-from-player side")
	_check(_room.get_last_release_position().is_equal_approx(Vector2(480.0, 312.0)),
		"re-release uses the left safe point because the player is on the right",
		str(_room.get_last_release_position()))
	var release_gap: float = _distance()
	_check(release_gap < _room.get_interaction_range(),
		"released core starts inside the 100 px field", "%.1f" % release_gap)

	var left: Dictionary = await _walk_left_sample(84.0)
	_log("  walk left: ticks=%d trail(min/mean/max)=%.1f/%.1f/%.1f out=%d" % [
		left["ticks"], left["min"], left["mean"], left["max"], left["out_ticks"],
	])
	_check(left["out_ticks"] == 0, "return walk never leaves the 100 px field")
	_check(left["min"] >= 30.0 and left["min"] <= 60.0,
		"return steady trailing minimum is in the 30..60 px band",
		"min=%.1f" % left["min"])
	_check(left["mean"] >= 30.0 and left["mean"] <= 60.0,
		"return steady trailing mean is in the 30..60 px band",
		"mean=%.1f" % left["mean"])
	_check(left["max"] <= 60.0,
		"return steady trailing maximum stays at or below 60 px",
		"max=%.1f" % left["max"])

	var return_stop: Dictionary = await _stop_sample()
	_log("  stop left: gap_start=%.1f gap_end=%.1f core_v=%.1f jitter=%.2f player_drift=%.2f core_drift=%.2f" % [
		return_stop["gap_start"], return_stop["gap_end"],
		return_stop["end_speed"], return_stop["jitter"],
		return_stop["player_drift"], return_stop["core_drift"],
	])
	_check(return_stop["gap_end"] >= 20.0 and return_stop["gap_end"] <= 60.0,
		"return stop settles at a readable near distance",
		"gap=%.1f" % return_stop["gap_end"])
	_check(return_stop["jitter"] < 2.0, "return stop tail does not jitter")
	_check(absf(return_stop["player_drift"]) < 8.0,
		"return player does not glide after stopping",
		"drift=%.2f px" % return_stop["player_drift"])
	_check(
		return_stop["tail_player_jitter"] < 2.0
		and return_stop["tail_core_jitter"] < 2.0,
		"return stop tail keeps both bodies stationary",
		"player=%.2f core=%.2f px" % [
			return_stop["tail_player_jitter"], return_stop["tail_core_jitter"]
		]
	)
	_check(_room.get_start_bay().is_core_in_store_zone(_room.get_core().global_position)
		and _room.get_start_bay().is_player_in_range(_player.global_position),
		"returning core settles in the start seat")
	_check(_hud.get_interaction_e_text().contains("STORE CORE (START)"),
		"return E store becomes available", _hud.get_interaction_e_text())
	await _tap_action(&"interact")
	await _step(2)
	_check(_room.get_store_bay() == _room.get_start_bay(),
		"E manually stores the returning core in the start bay")
	await _wait_until(func() -> bool: return _room.get_start_bay().is_locked(), 40)
	_check(_room.get_start_bay().is_locked(), "start bay finishes closing")


func _run_stop_resume() -> void:
	_section("STOP / RESUME FOLLOW")
	await _reset()
	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	_check(_room.get_core().is_active(), "core active before the stop/resume check")
	await _walk_to_x(300.0)
	await _step(60)
	var stop_gap: float = _distance()
	_check(stop_gap >= 20.0 and stop_gap <= 60.0,
		"resume test stop settles near the player", "gap=%.1f" % stop_gap)
	_check(absf(_room.get_core().velocity.x) < 1.0,
		"core is at rest before resuming", "vx=%.1f" % _room.get_core().velocity.x)
	var core_stop_x: float = _room.get_core().global_position.x
	Input.action_press(&"move_right")
	await _step(60)
	Input.action_release(&"move_right")
	await _step(5)
	_check(_room.get_core().global_position.x > core_stop_x + 20.0,
		"core resumes following after the player walks again",
		"%.1f -> %.1f" % [core_stop_x, _room.get_core().global_position.x])
	_check(_distance() < _room.get_interaction_range(),
		"resumed follow stays in range", "%.1f" % _distance())
	_check(_room.get_last_status() != "OUT OF RANGE",
		"resumed follow is still powered", _room.get_last_status())
	_log("  stop/resume: stop_gap=%.1f core_x %.1f -> %.1f gap=%.1f" % [
		stop_gap, core_stop_x, _room.get_core().global_position.x, _distance(),
	])


func _run_same_sign_and_range_boundary() -> void:
	_section("SAME-SIGN REPEL / RUN BOUNDARY / NO OUT-OF-RANGE CHASE")
	await _reset()
	var repel: Dictionary = _room.compute_field(
		Vector2(300.0, 305.0), Vector2(342.0, 312.0), true, true
	)
	var to_core: Vector2 = Vector2(42.0, 7.0)
	_check(String(repel["status"]) == "REPEL",
		"same-sign 40..60 px field is REPEL", String(repel["status"]))
	_check((repel["core_acceleration"] as Vector2).dot(to_core) > 0.0,
		"same-sign force pushes the core away")
	_check((repel["player_acceleration"] as Vector2).dot(-to_core) > 0.0,
		"same-sign force pushes the player away")

	await _walk_to_x(84.0)
	await _tap_action(&"interact")
	await _step(20)
	if not _room.get_core().is_active():
		_check(false, "core active before run boundary")
		return
	_send_key(KEY_D, true)
	_send_key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _step(90)
	var mid_gap: float = _distance()
	var mid_status: String = _room.get_last_status()
	_check(_room.get_core().is_active(), "core stays active during run")
	_check(_room.get_core().velocity.length() <= _room.get_core().get_max_speed() + 0.1,
		"run does not raise the core above 120 px/s")
	_log("  run 90 frames: gap=%.1f status=%s" % [mid_gap, mid_status])
	await _step(120)
	var late_gap: float = _distance()
	var late_status: String = _room.get_last_status()
	_send_key(KEY_D, false)
	_send_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _step(60)
	_check(late_gap > _room.get_interaction_range(),
		"run can leave the 100 px field", "gap=%.1f" % late_gap)
	_check(late_status == "OUT OF RANGE",
		"run beyond the field reports OUT OF RANGE", late_status)
	var core_x_before: float = _room.get_core().global_position.x
	await _step(30)
	_check(absf(_room.get_core().global_position.x - core_x_before) < 8.0,
		"out-of-range core does not resume chasing",
		"x %.1f -> %.1f" % [core_x_before, _room.get_core().global_position.x])
	_check(absf(_room.get_core().velocity.x) < 1.0,
		"out-of-range core coasts to rest", "vx=%.1f" % _room.get_core().velocity.x)
	_log("  run 210 frames: gap=%.1f status=%s" % [late_gap, late_status])


# ---------------------------------------------------------------------------
# Sampling and helpers


func _walk_right_sample(target_x: float) -> Dictionary:
	var distances: Array[float] = []
	var out_ticks: int = 0
	var core_max_speed: float = 0.0
	Input.action_press(&"move_right")
	for i: int in range(360):
		await _step(1)
		if _player.global_position.x >= 220.0:
			var d: float = _distance()
			distances.append(d)
			if _room.get_last_status() == "OUT OF RANGE":
				out_ticks += 1
			core_max_speed = maxf(core_max_speed, absf(_room.get_core().velocity.x))
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _step(1)
	return {
		"ticks": distances.size(),
		"min": _min(distances),
		"mean": _mean(distances),
		"max": _max(distances),
		"out_ticks": out_ticks,
		"core_max_speed": core_max_speed,
	}


func _walk_left_sample(target_x: float) -> Dictionary:
	var distances: Array[float] = []
	var out_ticks: int = 0
	Input.action_press(&"move_left")
	for i: int in range(360):
		await _step(1)
		if _player.global_position.x <= 400.0:
			var d: float = _distance()
			distances.append(d)
			if _room.get_last_status() == "OUT OF RANGE":
				out_ticks += 1
		if _player.global_position.x <= target_x:
			break
	Input.action_release(&"move_left")
	await _step(1)
	return {
		"ticks": distances.size(),
		"min": _min(distances),
		"mean": _mean(distances),
		"max": _max(distances),
		"out_ticks": out_ticks,
	}


func _stop_sample() -> Dictionary:
	var gaps: Array[float] = []
	var core_positions: Array[float] = []
	var player_positions: Array[float] = []
	var player_x_start: float = _player.global_position.x
	var core_x_start: float = _room.get_core().global_position.x
	for i: int in range(90):
		await _step(1)
		gaps.append(_distance())
		core_positions.append(_room.get_core().global_position.x)
		player_positions.append(_player.global_position.x)
	var tail_gaps: Array[float] = []
	var tail_cores: Array[float] = []
	var tail_players: Array[float] = []
	for i: int in range(60, 90):
		tail_gaps.append(gaps[i])
		tail_cores.append(core_positions[i])
		tail_players.append(player_positions[i])
	return {
		"gap_start": gaps[0],
		"gap_end": gaps[89],
		"end_speed": absf(_room.get_core().velocity.x),
		"jitter": _max(tail_gaps) - _min(tail_gaps),
		"player_drift": _player.global_position.x - player_x_start,
		"core_drift": _room.get_core().global_position.x - core_x_start,
		"tail_player_jitter": _max(tail_players) - _min(tail_players),
		"tail_core_jitter": _max(tail_cores) - _min(tail_cores),
	}


func _reset() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_hud.set_pause_visible(false)
	_player.reset_to_spawn("manual", false)
	await _step(8)


func _walk_to_x(target_x: float, max_frames: int = 360) -> void:
	Input.action_press(&"move_right")
	for i: int in range(max_frames):
		await _step(1)
		if _player.global_position.x >= target_x:
			break
	Input.action_release(&"move_right")
	await _step(1)


func _wait_until(predicate: Callable, max_frames: int) -> void:
	for i: int in range(max_frames):
		if bool(predicate.call()):
			return
		await _step(1)


func _distance() -> float:
	return (_player.global_position + Vector2(0.0, -15.0)).distance_to(
		_room.get_core().global_position
	)


func _min(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result: float = values[0]
	for value: float in values:
		result = minf(result, value)
	return result


func _max(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result: float = values[0]
	for value: float in values:
		result = maxf(result, value)
	return result


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _section(title: String) -> void:
	_log("")
	_log("== %s ==" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, "" if detail.is_empty() else " | " + detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, "" if detail.is_empty() else " | " + detail])


func _log(line: String) -> void:
	_lines.append(line)
	print(line)


func _write_log() -> void:
	var directory: String = ProjectSettings.globalize_path("res://tests/logs")
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/follow_near_distance.log", FileAccess.WRITE
	)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
	print("LOG: tests/logs/follow_near_distance.log")
