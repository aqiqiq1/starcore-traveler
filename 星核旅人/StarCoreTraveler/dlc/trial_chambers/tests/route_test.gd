extends Node

## Full trial route test: spawn -> gold gate -> cyan gate -> arena -> guard
## defeat -> completion -> title.  R restart and two-hit failure retry are also
## exercised.  The real trial scene is the SceneTree's current scene while this
## small runner stays as a persistent root child, so the final change back to
## level_01.tscn can be observed.
##
## Run headless for logic:
##   ... --headless --path . res://dlc/trial_chambers/tests/route_test.tscn
## Run without --headless to also save out/route_completion.png (640x360).

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT_DIR: String = "res://dlc/trial_chambers/tests/out"

var _trial: TrialChambers
var _player: L3Player
var _guard: L3Guard
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	print("TRIAL_ROUTE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(2)
	_push_key(code, false)
	await _wait_physics(2)


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(1)
	Input.action_release(&"polarity")
	await _wait_physics(4)


func _move_until_x(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return _player.global_position.x >= target


func _walk_with_auto_jump(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	var last_x: float = _player.global_position.x
	var stall: int = 0
	for _index: int in range(max_frames):
		if _player.global_position.x >= target:
			Input.action_release(&"move_right")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
		if _player.is_on_floor() and absf(_player.global_position.x - last_x) < 0.15:
			stall += 1
		else:
			stall = 0
		last_x = _player.global_position.x
		if stall >= 6:
			stall = 0
			Input.action_press(&"jump")
			await _wait_physics(1)
			Input.action_release(&"jump")
	Input.action_release(&"move_right")
	await _wait_physics(2)
	return _player.global_position.x >= target


func _run_route_to_arena() -> bool:
	# Gate 1: the player is cyan and the gold gate is solid until Q.
	var reached: bool = await _move_until_x(240.0, 400)
	if not reached:
		return false
	await _tap_polarity()
	if not _player.is_positive():
		return false
	reached = await _move_until_x(470.0, 400)
	if not reached:
		return false
	# Gate 2: switch back to cyan before the cyan gate.
	await _tap_polarity()
	if _player.is_positive():
		return false
	reached = await _walk_with_auto_jump(825.0, 1400)
	if not reached:
		return false
	await _wait_physics(10)
	return true


func _wait_guard_state(state_name: String, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if _guard.get_state_name() == state_name:
			return true
		await get_tree().physics_frame
	return _guard.get_state_name() == state_name


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


func _force_one_true_hit(hit_index: int) -> bool:
	# Stand outside the guard's alert range while it finishes any previous
	# scatter/reassembly, so no unplanned slam can add a player hit.
	_player.global_position = Vector2(860.0, 320.0)
	_player.velocity = Vector2.ZERO
	var active: bool = await _wait_guard_state("ACTIVE", 900)
	if not active:
		return false
	var before: int = _guard.get_true_marks_taken()
	_player.global_position = Vector2(_guard.global_position.x - 22.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.face_direction(1)
	_player.cancel_attack()
	_player.set_polarity_state(not _guard.is_positive())
	await _wait_physics(1)
	_guard.set_suspended(false)
	_guard.debug_force_gravity()
	await _wait_physics(2)
	if hit_index == 1:
		await _tap_key(KEY_J)
	else:
		_player.request_attack()
	var dealt: bool = await _wait_until(
		func() -> bool: return _guard.get_true_marks_taken() > before, 40
	)
	if not dealt:
		return false
	_player.cancel_attack()
	# Leave the arena's inner range while the shell scatters/reassembles.
	_player.global_position = Vector2(880.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(4)
	return true


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)


func _try_save_completion_shot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join("route_completion.png"))
	print("SHOT route_completion.png size=%dx%d error=%d" % [
		image.get_width(), image.get_height(), error
	])


# --- main flow -------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_check(packed != null, "trial scene loads")
	if packed == null:
		return
	_trial = packed.instantiate() as TrialChambers
	_trial.show_intro_guide = false
	get_tree().root.add_child(_trial)
	# Keep this runner alive when the trial changes scenes at the end.
	get_tree().current_scene = _trial
	await _wait_process(3)
	await _wait_physics(8)

	_player = _trial.get_player()
	_guard = _trial.get_guard()
	_check(_trial.get_hud() != null, "trial HUD exists")
	_check(not _player.is_positive(), "spawn is 澜相")
	_check(_trial.get_hud().get_title_text() == "星核试炼场", "HUD title reads 星核试炼场",
		_trial.get_hud().get_title_text())
	_check(_trial.get_hud().get_affinity_text() == "澜相", "HUD shows 澜相",
		_trial.get_hud().get_affinity_text())

	# --- Esc pause is only 继续 / 返回标题 --------------------------------
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(_trial.is_pause_open(), "Esc opens the simple pause page")
	_check(get_tree().paused, "pause page pauses the tree")
	_check(_trial.get_hud().is_pause_visible(), "HUD pause overlay is visible")
	_check(_trial.get_hud().get_continue_button() != null
		and _trial.get_hud().get_title_button() != null,
		"pause page exposes 继续 and 返回标题")
	_check(_trial.get_hud().get_continue_button().text == "继续",
		"continue button text is 继续")
	_check(_trial.get_hud().get_title_button().text == "返回标题",
		"title button text is 返回标题")
	_check(_trial.get_hud().get_continue_button().has_focus(),
		"continue button owns keyboard focus")
	await _tap_key(KEY_ENTER)
	await _wait_process(5)
	_check(not _trial.is_pause_open(), "Enter on 继续 closes the pause page")
	_check(not get_tree().paused, "resume unpauses the tree")
	Input.action_press(&"move_right")
	await _wait_physics(10)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > 45.0, "player can move after resuming",
		"x=%.2f" % _player.global_position.x)

	# --- R restart before the run: no soft lock ---------------------------
	await _tap_key(KEY_R)
	await _wait_process(4)
	_check(_trial.get_elapsed_seconds() < 1.0, "R resets the timer",
		"%.2f" % _trial.get_elapsed_seconds())
	_check(absf(_player.global_position.x - 40.0) < 2.0, "R returns to spawn",
		"x=%.2f" % _player.global_position.x)
	_check(not _player.is_positive(), "R restores 澜相")
	_check(not _trial.is_completed(), "R clears completion")
	_check(not _trial.is_pause_open(), "R leaves no pause lock")
	_check(not _trial.get_hud().is_completion_visible(), "R hides the completion page")
	Input.action_press(&"move_right")
	await _wait_physics(12)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > 45.0, "player can move after R",
		"x=%.2f" % _player.global_position.x)

	# --- gates and transition --------------------------------------------
	var route_ok: bool = await _run_route_to_arena()
	_check(route_ok, "real walk + Q passes both gates and reaches the arena",
		"x=%.2f" % _player.global_position.x)
	_check(_trial.is_arena_entered(), "arena entry flag set", str(_trial.is_arena_entered()))
	_check(_trial.get_hud().get_objective_text().begins_with("目标：击败守卫"),
		"HUD objective switches to the guard", _trial.get_hud().get_objective_text())

	# --- two-hit failure returns to the arena entrance --------------------
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	var began: bool = await _wait_until(
		func() -> bool: return _trial.is_recovery_active(), 30
	)
	_check(began, "two accepted hits start the recovery transition")
	var finished: bool = await _wait_until(
		func() -> bool: return not _trial.is_recovery_active(), 180
	)
	await _wait_physics(6)
	_check(finished, "recovery finishes without staying black")
	_check(absf(_player.global_position.x - _trial.get_arena_spawn().x) < 2.0,
		"failure returns the player to the arena entrance",
		"x=%.2f" % _player.global_position.x)
	_check(_trial.get_player_hits() == 0, "failure clears the hit count")
	_check(_guard.get_state_name() == "ACTIVE", "guard resets to ACTIVE after failure",
		_guard.get_state_name())
	Input.action_press(&"move_right")
	await _wait_physics(12)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > _trial.get_arena_spawn().x + 4.0,
		"player can move after the arena failure", "x=%.2f" % _player.global_position.x)

	# --- R during the run, then do the real route again -------------------
	await _tap_key(KEY_R)
	await _wait_process(4)
	_check(absf(_player.global_position.x - 40.0) < 2.0, "R restarts the whole trial",
		"x=%.2f" % _player.global_position.x)
	route_ok = await _run_route_to_arena()
	_check(route_ok, "route is repeatable after R", "x=%.2f" % _player.global_position.x)

	# --- three real true-damage hit resolutions --------------------------
	for hit_index: int in range(1, 4):
		var hit_ok: bool = await _force_one_true_hit(hit_index)
		_check(hit_ok, "true-damage hit %d resolved" % hit_index,
			"marks=%d" % _guard.get_true_marks_taken())
		if not hit_ok:
			break
	var defeated: bool = await _wait_until(
		func() -> bool: return _trial.is_guard_defeated(), 600
	)
	await _wait_physics(10)
	_check(_guard.is_defeated(), "guard reaches defeated state")
	_check(defeated and _trial.is_guard_defeated(), "trial receives guard defeated signal")
	_check(_trial.get_finish_sprite().modulate.r > 0.9,
		"finish point becomes bright after the guard defeat")

	# --- completion page --------------------------------------------------
	# Completion locks the player as soon as the finish radius is touched
	# (finish x=1218, range 18), so the walk target stays at its outer edge.
	var reached_finish: bool = await _move_until_x(1196.0, 500)
	_check(reached_finish, "player reaches the finish point",
		"x=%.2f" % _player.global_position.x)
	await _wait_physics(8)
	_check(_trial.is_completed(), "touching the finish completes the trial")
	_check(_trial.get_hud().is_completion_visible(), "completion page is visible")
	var completion_text: String = _trial.get_hud().get_completion_text()
	var expression: RegEx = RegEx.new()
	expression.compile("^试炼完成 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(completion_text) != null,
		"completion text is 试炼完成 · 用时 mm:ss", completion_text)
	_check(_trial.get_elapsed_seconds() > 0.0, "completion time is real",
		"%.2f s" % _trial.get_elapsed_seconds())
	await _try_save_completion_shot()

	# --- E returns to the title menu -------------------------------------
	await _tap_key(KEY_E)
	var changed: bool = await _wait_until(
		func() -> bool:
			return get_tree().current_scene != null \
				and get_tree().current_scene != _trial, 120
	)
	await _wait_process(6)
	var current: Node = get_tree().current_scene
	var current_path: String = ""
	if current != null and current is Node and current.scene_file_path != "":
		current_path = current.scene_file_path
	_check(changed and current_path == "res://scenes/level_01.tscn",
		"E returns to level_01.tscn title", current_path)
	if current != null:
		_check(current.has_node("StartMenu"), "returned scene contains the title menu")
