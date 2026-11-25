extends Node

## Headless mechanics test for dlc/rift_workshop.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/mechanics_test.tscn
##
## Covers: inversion field one-flip-per-entry, phase bridge solid/gone +
## anti-crush + safe lower shelf, wisp phase/pulse/push-pull/J-kill, checkpoint
## fall recovery, arena twin guards (both defeated by real hit resolution),
## failure retry, R restart without a soft lock, completion text and E -> title.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	print("RIFT_MECHANICS_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_until(predicate: Callable, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())


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


func _move_until_x_left(target: float, max_frames: int) -> bool:
	Input.action_press(&"move_left")
	for _index: int in range(max_frames):
		if _player.global_position.x <= target:
			Input.action_release(&"move_left")
			await _wait_physics(2)
			return true
		await get_tree().physics_frame
	Input.action_release(&"move_left")
	await _wait_physics(2)
	return _player.global_position.x <= target


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_rift.get_camera().reset_smoothing()
	await _wait_physics(3)


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)


func _wait_guard_active(guard: L3Guard, max_frames: int) -> bool:
	return await _wait_until(
		func() -> bool: return guard.get_state_name() == "ACTIVE", max_frames
	)


func _force_true_hit(guard: L3Guard, other: L3Guard) -> bool:
	other.set_suspended(true)
	_player.global_position = Vector2(guard.global_position.x - 90.0, 320.0)
	_player.velocity = Vector2.ZERO
	var active: bool = await _wait_guard_active(guard, 600)
	if not active:
		return false
	var before: int = guard.get_true_marks_taken()
	guard.set_suspended(false)
	_player.global_position = Vector2(guard.global_position.x - 22.0, 320.0)
	_player.velocity = Vector2.ZERO
	_player.face_direction(1)
	_player.cancel_attack()
	_player.set_polarity_state(not guard.is_positive())
	await _wait_physics(1)
	guard.debug_force_gravity()
	await _wait_physics(2)
	_player.request_attack()
	var dealt: bool = await _wait_until(
		func() -> bool: return guard.get_true_marks_taken() > before, 60
	)
	_player.cancel_attack()
	_player.global_position = Vector2(guard.global_position.x - 90.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(4)
	return dealt


# --- main flow -------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(8)

	_player = _rift.get_player()
	_check(_player != null, "chapter exposes an L3Player")
	if _player == null:
		return
	_check(_rift.get_hud() != null, "rift HUD exists")
	_check(not _player.is_positive(), "spawn is 澜相")
	_check(_rift.get_hud().get_title_text() == "裂隙工坊", "HUD title reads 裂隙工坊",
		_rift.get_hud().get_title_text())
	_check(_rift.get_hud().get_objective_text().begins_with("目标："),
		"HUD shows an objective", _rift.get_hud().get_objective_text())
	_check(_rift.get_wisps().size() == 4, "four PolarityWisps exist",
		str(_rift.get_wisps().size()))
	_check(_rift.get_guard_gold().is_positive()
		and not _rift.get_guard_cyan().is_positive(),
		"twin guards start in opposite phases")
	_check(_rift.get_bridge_a().get_required_positive()
		and not _rift.get_bridge_b().get_required_positive()
		and _rift.get_bridge_c().get_required_positive(),
		"bridges alternate gold / cyan / gold")

	# --- Esc pause: only 继续 / 返回标题 ---------------------------------
	await _tap_key(KEY_ESCAPE)
	await _wait_process(4)
	_check(_rift.is_pause_open(), "Esc opens the simple pause page")
	_check(_rift.get_hud().is_pause_visible(), "HUD pause overlay is visible")
	_check(_rift.get_hud().get_continue_button().text == "继续"
		and _rift.get_hud().get_title_button().text == "返回标题",
		"pause page exposes 继续 and 返回标题")
	await _tap_key(KEY_ENTER)
	await _wait_process(4)
	_check(not _rift.is_pause_open(), "Enter on 继续 closes the pause page")
	_check(not get_tree().paused, "resume unpauses the tree")

	# --- room 1: inversion field -----------------------------------------
	var field_a: RiftInversionField = _rift.get_field_a()
	await _place(120.0, 320.0, false)
	await _wait_physics(6)
	_check(field_a.get_trigger_count() == 0, "field is armed before entry",
		str(field_a.get_trigger_count()))
	var walked: bool = await _move_until_x(165.0, 240)
	_check(walked, "player can walk into the inversion field",
		"x=%.2f" % _player.global_position.x)
	_check(field_a.get_trigger_count() == 1, "entry flips the phase exactly once",
		"triggers=%d" % field_a.get_trigger_count())
	_check(_player.is_positive(), "field flipped the player to 辉相")
	_check(field_a.is_player_inside(), "player body is inside the 24 px curtain")
	# Stay inside: the field must not keep flipping the body frame by frame.
	Input.action_release(&"move_right")
	await _wait_physics(60)
	_check(field_a.get_trigger_count() == 1,
		"standing inside does not flip again", "triggers=%d" % field_a.get_trigger_count())
	_check(_player.is_positive(), "phase stays 辉相 while inside")
	# Q inside the curtain is the player's own switch; still no extra field flip.
	await _tap_polarity()
	_check(not _player.is_positive(), "Q inside the field switches to 澜相")
	_check(field_a.get_trigger_count() == 1, "Q inside does not count as a field entry",
		str(field_a.get_trigger_count()))
	await _tap_polarity()
	# Leave to the far side, then come back: the same curtain is reusable.
	var left: bool = await _move_until_x(235.0, 240)
	_check(left, "player can leave the field", "x=%.2f" % _player.global_position.x)
	_check(not field_a.is_player_inside(), "field reads the player as outside")
	await _move_until_x_left(160.0, 240)
	_check(field_a.get_trigger_count() == 2, "re-entry flips again",
		"triggers=%d" % field_a.get_trigger_count())
	_check(not _player.is_positive(), "second entry returns to 澜相")

	# Real gates follow the field: gold gate opens for a 辉相 player.
	await _place(240.0, 320.0, true)
	await _wait_physics(4)
	_check(not _rift.get_node("GateGold").call("is_blocking"),
		"gold gate is open for 辉相")
	await _place(240.0, 320.0, false)
	await _wait_physics(4)
	_check(_rift.get_node("GateGold").call("is_blocking"),
		"gold gate is solid for 澜相")

	# --- room 2: phase bridge --------------------------------------------
	var bridge_a: RiftPhaseBridge = _rift.get_bridge_a()
	await _place(710.0, 280.0, true)
	await _wait_physics(20)
	_check(bridge_a.is_solid(), "gold bridge is solid for a 辉相 player")
	_check(bridge_a.get_collision_layer() == 1, "solid bridge uses collision layer 1",
		str(bridge_a.get_collision_layer()))
	_check(_player.is_on_floor(), "player stands on the matching bridge",
		"y=%.2f" % _player.global_position.y)
	# Switching phase removes the deck; the player falls to the safe shelf.
	await _place(710.0, 280.0, false)
	await _wait_physics(2)
	_check(not bridge_a.is_solid(), "bridge disappears on the other phase")
	_check(bridge_a.get_collision_layer() == 0, "gone bridge uses collision layer 0",
		str(bridge_a.get_collision_layer()))
	var landed: bool = await _wait_until(
		func() -> bool: return _player.is_on_floor() and _player.global_position.y >= 330.0,
		180
	)
	_check(landed, "falling lands on the safe lower shelf, no kill line",
		"y=%.2f" % _player.global_position.y)
	_check(not _rift.is_recovery_active(), "safe shelf needs no recovery fade")
	await _move_until_x(760.0, 120)
	_check(_player.global_position.x > 720.0, "player can walk on the safe shelf",
		"x=%.2f" % _player.global_position.x)
	# Anti-crush: do not re-solidify inside the body.
	await _place(710.0, 285.0, false)
	await _wait_physics(1)
	_player.set_polarity_state(true)
	await _wait_physics(1)
	_check(bridge_a.get_deferred_reform_count() > 0 or not bridge_a.is_solid(),
		"re-materialising waits for the body to clear")
	await _wait_physics(12)
	_check(bridge_a.is_solid(), "bridge solidifies after the body falls clear",
		bridge_a.get_state_name())
	# Restore a clean, standable state.
	await _place(710.0, 280.0, true)
	await _wait_physics(20)
	_check(_player.is_on_floor() and _player.global_position.y < 300.0,
		"player can stand on the bridge again after retry",
		"y=%.2f" % _player.global_position.y)

	# --- room 2: checkpoint + fall recovery ------------------------------
	var checkpoint: LevelCheckpoint = _rift.get_checkpoint()
	await _place(1030.0, 280.0, false)
	await _wait_physics(8)
	_check(_rift.is_checkpoint_active(), "stepping on the marker records the checkpoint")
	_check(checkpoint.is_activated(), "checkpoint art switches to active")
	_player.global_position = Vector2(1030.0, 500.0)
	_player.velocity = Vector2.ZERO
	var began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 60
	)
	_check(began, "falling below the kill line starts the recovery fade")
	var finished: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 240
	)
	await _wait_physics(4)
	_check(finished, "fall recovery finishes without staying black")
	_check(absf(_player.global_position.x - _rift.get_checkpoint_position().x) < 3.0,
		"fall recovery returns to the recorded checkpoint",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])

	# --- room 3: wisp behaviour ------------------------------------------
	var wisp: RiftPolarityWisp = _rift.get_wisps()[2]
	_check(wisp.phase_period == 2.2, "wisp phase period is 2.2 s",
		"%.2f" % wisp.phase_period)
	_check(wisp.pulse_period == 3.0, "wisp pulse period is 3.0 s",
		"%.2f" % wisp.pulse_period)
	await _place(760.0, 280.0, wisp.is_positive())
	var pulse_before: int = wisp.get_pulse_count()
	var pulsed: bool = await _wait_until(
		func() -> bool: return wisp.get_pulse_count() > pulse_before, 260
	)
	_check(pulsed, "wisp pulses within its 3 s period")
	var mode_one: String = wisp.get_last_pulse_mode()
	_check(mode_one == "pull", "same phase at the pulse becomes a pull",
		mode_one + " force=%.1f" % wisp.get_last_pulse_force())
	_check(wisp.get_last_pulse_force() > 0.0, "pulse reports a real force",
		"%.1f" % wisp.get_last_pulse_force())
	await _wait_physics(1)
	_check(_player.velocity.x > 0.0, "pull velocity points toward the wisp",
		"vx=%.1f" % _player.velocity.x)
	# Now stand on the other phase so the next pulse pushes.
	_player.set_polarity_state(not wisp.is_positive())
	pulse_before = wisp.get_pulse_count()
	await _wait_until(
		func() -> bool: return wisp.get_pulse_count() > pulse_before, 260
	)
	var mode_two: String = wisp.get_last_pulse_mode()
	_check(mode_two == "push", "opposite phase at the pulse becomes a push", mode_two)
	await _wait_physics(1)
	_check(_player.velocity.x < 0.0, "push velocity points away from the wisp",
		"vx=%.1f" % _player.velocity.x)
	# One J hit destroys it (no phase requirement, no true damage).
	await _place(760.0, 280.0, wisp.is_positive())
	await _wait_physics(2)
	_push_key(KEY_J, true)
	await _wait_physics(2)
	_push_key(KEY_J, false)
	var killed: bool = await _wait_until(
		func() -> bool: return not wisp.is_alive(), 40
	)
	_check(killed, "one J hit dissolves the wisp")
	_check(_rift.get_wisps()[0].is_alive(), "other wisps stay alive",
		"wisp0 alive=%s" % str(_rift.get_wisps()[0].is_alive()))

	# --- R restart clears all progress without a soft lock ---------------
	await _tap_key(KEY_R)
	await _wait_process(4)
	await _wait_physics(4)
	_check(absf(_player.global_position.x - _rift.get_start_spawn().x) < 2.0,
		"R returns to the start", "x=%.2f" % _player.global_position.x)
	_check(not _player.is_positive(), "R restores 澜相")
	_check(_rift.get_elapsed_seconds() < 1.0, "R resets the timer",
		"%.2f" % _rift.get_elapsed_seconds())
	_check(not _rift.is_checkpoint_active(), "R clears the checkpoint")
	_check(_rift.get_wisps()[2].is_alive(), "R respawns defeated wisps")
	_check(_rift.get_guards_defeated() == 0, "R restores both guards")
	_check(not _rift.is_completed(), "R clears completion")
	_check(not _rift.is_pause_open(), "R leaves no pause lock")
	Input.action_press(&"move_right")
	await _wait_physics(12)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > 45.0, "player can move after R",
		"x=%.2f" % _player.global_position.x)

	# --- arena failure retry ---------------------------------------------
	await _place(1095.0, 320.0, false)
	await _wait_physics(6)
	_check(_rift.is_arena_entered(), "arena entry flag set")
	_check(not _rift.get_guard_gold().is_suspended()
		and not _rift.get_guard_cyan().is_suspended(),
		"both guards wake on arena entry")
	_check(_rift.get_hud().get_objective_text().begins_with("目标：击败双生守卫"),
		"HUD objective switches to the twin guards",
		_rift.get_hud().get_objective_text())
	_rift.get_guard_gold().player_struck.emit(1)
	await _wait_physics(3)
	_rift.get_guard_cyan().player_struck.emit(1)
	await _wait_physics(3)
	var retry_began: bool = await _wait_until(
		func() -> bool: return _rift.is_recovery_active(), 40
	)
	_check(retry_began, "two accepted hits start the recovery transition")
	var retry_done: bool = await _wait_until(
		func() -> bool: return not _rift.is_recovery_active(), 240
	)
	await _wait_physics(6)
	_check(retry_done, "combat recovery finishes without staying black")
	_check(absf(_player.global_position.x - _rift.get_arena_spawn().x) < 2.0,
		"failure returns the player to the arena entrance",
		"x=%.2f" % _player.global_position.x)
	_check(_rift.get_player_hits() == 0, "failure clears the hit count")
	_check(_rift.get_guard_gold().get_state_name() == "ACTIVE"
		and _rift.get_guard_cyan().get_state_name() == "ACTIVE",
		"both guards reset to ACTIVE after failure")
	Input.action_press(&"move_right")
	await _wait_physics(12)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > _rift.get_arena_spawn().x + 4.0,
		"player can move after the arena failure", "x=%.2f" % _player.global_position.x)

	# --- both guards defeated by real hit resolution ---------------------
	await _tap_key(KEY_R)
	await _wait_process(4)
	await _place(1095.0, 320.0, false)
	await _wait_physics(6)
	var gold: L3Guard = _rift.get_guard_gold()
	var cyan: L3Guard = _rift.get_guard_cyan()
	var gold_hits: bool = true
	for _index: int in range(3):
		gold_hits = await _force_true_hit(gold, cyan)
		_check(gold_hits, "gold guard true hit %d resolved" % (_index + 1),
			"marks=%d" % gold.get_true_marks_taken())
		if not gold_hits:
			break
	await _wait_until(func() -> bool: return _rift.is_gold_defeated(), 400)
	_check(gold.is_defeated(), "gold guard is defeated")
	_check(_rift.is_gold_defeated(), "chapter records the gold guard")
	_check(not _rift.is_both_defeated(), "one guard is not enough to open the finish")
	_check(_rift.get_finish_sprite().modulate.r < 0.9, "finish stays dim with one guard")
	var cyan_hits: bool = true
	for _index: int in range(3):
		cyan_hits = await _force_true_hit(cyan, gold)
		_check(cyan_hits, "cyan guard true hit %d resolved" % (_index + 1),
			"marks=%d" % cyan.get_true_marks_taken())
		if not cyan_hits:
			break
	await _wait_until(func() -> bool: return _rift.is_cyan_defeated(), 400)
	_check(cyan.is_defeated(), "cyan guard is defeated")
	_check(_rift.is_both_defeated(), "both guards defeated opens the finish")
	_check(_rift.get_finish_sprite().modulate.r > 0.9,
		"finish point becomes bright after both defeats")

	# --- completion page -------------------------------------------------
	_player.global_position = Vector2(1550.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _wait_physics(30)
	_check(_rift.is_completed(), "touching the finish completes the chapter",
		"x=%.2f" % _player.global_position.x)
	_check(_rift.get_hud().is_completion_visible(), "completion page is visible")
	var completion_text: String = _rift.get_hud().get_completion_text()
	var expression: RegEx = RegEx.new()
	expression.compile("^裂隙封闭 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(completion_text) != null,
		"completion text is 裂隙封闭 · 用时 mm:ss", completion_text)
	_check(_rift.get_elapsed_seconds() > 0.0, "completion time is real",
		"%.2f s" % _rift.get_elapsed_seconds())

	# --- E returns to the title menu -------------------------------------
	await _tap_key(KEY_E)
	var changed: bool = await _wait_until(
		func() -> bool:
			return get_tree().current_scene != null \
				and get_tree().current_scene != _rift, 180
	)
	await _wait_process(6)
	var current: Node = get_tree().current_scene
	var current_path: String = ""
	if current != null:
		current_path = current.scene_file_path
	_check(changed and current_path == LEVEL_01,
		"E returns to level_01.tscn title", current_path)
	if current != null:
		_check(current.has_node("StartMenu"), "returned scene contains the title menu")
		var menu: StartMenu = current.get_node_or_null("StartMenu") as StartMenu
		if menu != null:
			var rift_button: PixelMenuButton = menu.get_rift_button()
			_check(rift_button != null and rift_button.visible,
				"title shows the 裂隙工坊 entry while the DLC exists")
			_check(rift_button != null and rift_button.text == "裂隙工坊",
				"entry text is 裂隙工坊")
