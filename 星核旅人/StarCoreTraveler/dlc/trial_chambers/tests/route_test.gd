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


func _push_click(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	get_viewport().push_input(down, true)
	await _wait_process(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	get_viewport().push_input(up, true)
	await _wait_process(2)


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
	# Gate 1: the real walk touches the crystal (first key) before the gold gate.
	var reached: bool = await _move_until_x(235.0, 400)
	if not reached:
		return false
	if not _player.is_positive():
		return false
	reached = await _move_until_x(470.0, 400)
	if not reached:
		return false
	# Gate 2: there is no crystal; Q is the second key.
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
	# The E route returns to the title scene, which starts the title BGM.  Stop
	# it before freeing the scene so the engine's exit teardown does not report
	# a false "resources still in use" error (the same teardown the DLC smoke
	# wrappers use).
	if current != null:
		var menu: Node = current.get_node_or_null("StartMenu")
		if menu != null and menu.has_method("stop_title_music_for_test"):
			menu.call("stop_title_music_for_test")
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(20)


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
	_trial.show_intro_cinematic = false
	_trial.show_mechanic_tips = false
	get_tree().root.add_child(_trial)
	# Keep this runner alive when the trial changes scenes at the end.
	get_tree().current_scene = _trial
	await _wait_process(3)
	await _wait_physics(8)

	_player = _trial.get_player()
	_guard = _trial.get_guard()
	var hud: TrialHUD = _trial.get_hud()
	_check(hud != null, "trial HUD exists")
	_check(not _player.is_positive(), "spawn is 澜相")
	_check(hud.get_title_text() == "星核试炼场", "HUD title reads 星核试炼场",
		hud.get_title_text())
	_check(hud.get_affinity_text() == "澜相", "HUD data still reports 澜相",
		hud.get_affinity_text())
	_check(not hud.is_affinity_text_visible(),
		"the header's 相 text is hidden")
	_check(hud.get_affinity_icon_positive() == false,
		"header affinity icon is the cyan moon for 澜相")
	_check(hud.get_affinity_icon_rect().size.is_equal_approx(Vector2(20.0, 20.0)),
		"header affinity moon icon is 20x20", str(hud.get_affinity_icon_rect().size))
	_check(hud.is_hit_pips_visible(), "the fixed health bar is visible in normal play")
	var health_bar: PlayerHealthBar = hud.get_hit_pips()
	_check(health_bar != null and health_bar.get_style_name() == "bar"
		and not health_bar.is_heart_style(),
		"health display is the shared red bar, not hearts")
	_check(hud.get_hit_pips_current() == 2 and hud.get_hit_pips_max() == 2,
		"normal play starts with two full segments",
		"%d / %d" % [hud.get_hit_pips_current(), hud.get_hit_pips_max()])
	_check(hud.get_hit_pips_position() == Vector2(14.0, 324.0),
		"bar is fixed at (14,324)", str(hud.get_hit_pips_position()))
	var segment_rects: Array[Rect2] = health_bar.get_segment_rects()
	_check(segment_rects.size() == 2
		and segment_rects[0].size == Vector2(14.0, 8.0)
		and segment_rects[1].position.x == 30.0,
		"bar has two 14x8 segments with a 2 px gap", str(segment_rects))
	_check(health_bar.filled_color == Color("#d95757")
		and health_bar.low_color == Color("#ff7b7b")
		and health_bar.empty_color == Color(0.13, 0.07, 0.08, 0.98),
		"bar uses the approved red / bright-red / dark-empty colours",
		"%s / %s" % [health_bar.filled_color, health_bar.low_color])
	_check(health_bar.filled_color == Color("#d95757"),
		"health fill is red #d95757")
	_check(health_bar.get_heart_rect().size == Vector2(10.0, 10.0),
		"health group has the 10x10 heart at its left", str(health_bar.get_heart_rect()))
	_check(hud.get_health_label() == null,
		"no 生命值 word label remains on the HUD")

	# --- the bar stays fixed while the player moves ------------------------
	Input.action_press(&"move_right")
	await _wait_physics(14)
	Input.action_release(&"move_right")
	await _wait_process(3)
	_check(hud.get_hit_pips_position() == Vector2(14.0, 324.0),
		"bar does not follow the player", str(hud.get_hit_pips_position()))
	_check(hud.get_hit_pips_rect().get_center().y > 300.0,
		"bar stays in the lower-left HUD corner",
		str(hud.get_hit_pips_rect()))

	var has_hit_text: bool = false
	for node: Node in hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text.contains("受击"):
			has_hit_text = true
			break
	_check(not has_hit_text, "no HUD label repeats a 受击 text count")

	# --- Esc pause: five entries, aligned with the base pause page ---------
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(_trial.is_pause_open(), "Esc opens the five-entry pause page")
	_check(get_tree().paused, "pause page pauses the tree")
	_check(hud.is_pause_visible(), "HUD pause overlay is visible")
	_check(not hud.is_hit_pips_visible(), "pause page hides the fixed health bar")
	_check(hud.get_health_label() == null,
		"pause page has no 生命值 word to hide")
	_check(hud.get_hit_pips_position() == Vector2(14.0, 324.0),
		"pause keeps the bar anchored at (14,324)", str(hud.get_hit_pips_position()))
	var pause_rect: Rect2 = hud.get_pause_panel_rect()
	_check(pause_rect.size.is_equal_approx(Vector2(360.0, 236.0)),
		"pause panel is 360x236", str(pause_rect.size))
	_check(hud.get_pause_subtitle_text() == "星核试炼场 · 旧试炼",
		"pause subtitle names the trial", hud.get_pause_subtitle_text())
	_check(hud.get_continue_button().text == "继续游戏",
		"continue button text is 继续游戏")
	_check(hud.get_restart_button().text == "重新开始本章",
		"restart button text is 重新开始本章")
	_check(hud.get_title_button().text == "返回主界面",
		"return button text is 返回主界面")
	_check(hud.get_quit_button().text == "退出游戏",
		"quit button text is 退出游戏")
	_check(hud.get_pause_controls_button().text == "操作",
		"controls button text is 操作")
	_check(hud.get_manual_button().text == "手册",
		"manual button text is 手册")
	_check(not hud.get_pause_controls_button().pressed.get_connections().is_empty(),
		"操作 button opens the in-panel table")
	_check(not hud.get_manual_button().pressed.get_connections().is_empty(),
		"手册 button opens the manual")
	_check(not hud.get_quit_button().pressed.get_connections().is_empty()
		and not hud.get_signal_connection_list("quit_requested").is_empty(),
		"quit button is wired to the chapter quit handler")
	_check(hud.get_continue_button().get_size() == Vector2(208.0, 24.0)
		and hud.get_continue_button().position == Vector2(76.0, 56.0),
		"continue row is 208x24 at (76,56)")
	_check(hud.get_restart_button().position == Vector2(76.0, 90.0)
		and hud.get_title_button().position == Vector2(76.0, 124.0)
		and hud.get_quit_button().position == Vector2(76.0, 158.0)
		and hud.get_pause_controls_button().position == Vector2(76.0, 192.0)
		and hud.get_manual_button().position == Vector2(184.0, 192.0),
		"pause rows step by 34 px and split the last row")
	_check(hud.get_pause_note_text() == "返回主界面不保存本章进度",
		"pause footnote is the base note", hud.get_pause_note_text())
	_check(hud.get_continue_button().has_focus(),
		"continue button owns keyboard focus")
	await _tap_key(KEY_ENTER)
	await _wait_process(5)
	_check(not _trial.is_pause_open(), "Enter on 继续游戏 closes the pause page")
	_check(not get_tree().paused, "resume unpauses the tree")
	_check(hud.is_hit_pips_visible(), "resume shows the health bar again")
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
	_check(hud.get_hit_pips_current() == 2 and hud.get_hit_pips_max() == 2,
		"two full segments before the first accepted hit",
		"%d / %d" % [hud.get_hit_pips_current(), hud.get_hit_pips_max()])
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	_check(hud.get_hit_pips_current() == 1,
		"first accepted hit removes one bar segment",
		str(hud.get_hit_pips_current()))
	_check(hud.is_hit_pulse_active() and is_equal_approx(hud.get_hit_pulse_duration(), 1.0),
		"hit starts the one-second bar pulse",
		"left=%.2f dur=%.2f" % [hud.get_hit_pulse_left(), hud.get_hit_pulse_duration()])
	_check(not hud.get_event_text().contains("受击"),
		"the event line no longer writes a hit-count sentence", hud.get_event_text())
	_guard.player_struck.emit(1)
	await _wait_physics(3)
	_check(hud.get_hit_pips_current() == 0,
		"second accepted hit empties the health bar",
		str(hud.get_hit_pips_current()))
	var began: bool = await _wait_until(
		func() -> bool: return _trial.is_recovery_active(), 30
	)
	_check(began, "two accepted hits start the recovery transition")
	_check(not hud.is_hit_pips_visible(), "failure recovery hides the health bar")
	_check(not _trial.is_footsteps_allowed(), "failure recovery disables footsteps")
	_check(_trial.get_footsteps().get_active_voice_count() == 0,
		"no footstep tail survives into the failure cover")
	var finished: bool = await _wait_until(
		func() -> bool: return not _trial.is_recovery_active(), 180
	)
	await _wait_physics(6)
	_check(finished, "recovery finishes without staying black")
	_check(hud.is_hit_pips_visible(), "recovery end shows the health bar again")
	_check(_trial.is_footsteps_allowed(), "footsteps are re-enabled after the failure cover")
	_check(absf(_player.global_position.x - _trial.get_arena_spawn().x) < 2.0,
		"failure returns the player to the arena entrance",
		"x=%.2f" % _player.global_position.x)
	_check(_trial.get_player_hits() == 0, "failure clears the hit count")
	_check(hud.get_hit_pips_current() == 2,
		"failure recovery refills both bar segments", str(hud.get_hit_pips_current()))
	_check(hud.get_event_text() == "失败 · 试炼场送你回入口 · 守卫重新凝聚",
		"failure line matches the parity spec", hud.get_event_text())
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
	_check(not hud.is_hit_pips_visible(), "completion page hides the health bar")
	var completion_text: String = _trial.get_hud().get_completion_text()
	var expression: RegEx = RegEx.new()
	expression.compile("^试炼完成 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(completion_text) != null,
		"completion text is 试炼完成 · 用时 mm:ss", completion_text)
	_check(_trial.get_elapsed_seconds() > 0.0, "completion time is real",
		"%.2f s" % _trial.get_elapsed_seconds())
	var completion_rect: Rect2 = hud.get_completion_panel_rect()
	_check(
		completion_rect.position.is_equal_approx(Vector2(120.0, 75.0))
		and completion_rect.size.is_equal_approx(Vector2(400.0, 210.0)),
		"completion panel is 400x210 at (120,75)",
		str(completion_rect)
	)
	_check(hud.get_completion_subtitle_text() == "试炼场的门重新合拢，星核记住了你的相性。",
		"completion subtitle is the trial epilogue", hud.get_completion_subtitle_text())
	_check(hud.get_completion_note_text() == "本章结算 · 暂停菜单可查看操作",
		"completion footnote names the real pause control table",
		hud.get_completion_note_text())
	var completion_primary: PixelMenuButton = hud.get_completion_primary_button()
	var completion_replay: PixelMenuButton = hud.get_completion_replay_button()
	_check(completion_primary.text == "返回主界面"
		and completion_primary.variant == PixelMenuButton.Variant.STONE
		and completion_primary.get_size() == Vector2(180.0, 28.0)
		and completion_primary.position == Vector2(110.0, 86.0),
		"completion primary is 返回主界面 STONE 180x28 at (110,86)")
	_check(completion_replay.text == "重玩本关"
		and completion_replay.variant == PixelMenuButton.Variant.OPTION
		and completion_replay.get_size() == Vector2(180.0, 24.0)
		and completion_replay.position == Vector2(110.0, 126.0),
		"completion secondary is 重玩本关 OPTION 180x24 at (110,126)")
	_check(completion_primary.has_focus(), "completion primary owns focus")
	await _try_save_completion_shot()

	# --- Esc opens the pause page over the completion page ----------------
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(_trial.is_pause_open() and hud.is_pause_visible(),
		"Esc opens the pause page from completion")
	_check(hud.is_completion_visible(), "completion stays behind the pause page")
	_check(hud.get_continue_button().has_focus(), "pause continue gets focus again")
	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(not _trial.is_pause_open(), "second Esc closes the pause page")
	_check(completion_primary.has_focus(), "completion focus returns after pause")

	# --- 重玩本关 really restarts the chapter -----------------------------
	await _push_click(completion_replay.get_global_rect().get_center())
	await _wait_process(6)
	_check(not _trial.is_completed(), "重玩本关 clears completion")
	_check(not hud.is_completion_visible(), "重玩本关 hides the completion page")
	_check(hud.is_hit_pips_visible(), "重玩本关 shows the health bar again")
	_check(not get_tree().paused, "重玩本关 leaves the tree unpaused")
	_check(absf(_player.global_position.x - _trial.get_start_spawn().x) < 2.0,
		"重玩本关 returns to the trial entrance",
		"x=%.2f" % _player.global_position.x)

	# --- complete again (state-only) so E can be checked ------------------
	_trial.get_guard().debug_force_death()
	_trial.get_guard().defeated.emit()
	await _wait_process(6)
	_player.global_position = Vector2(1204.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(8)
	_check(_trial.is_completed(), "second completion page reached for the E check")
	await _wait_process(4)

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
