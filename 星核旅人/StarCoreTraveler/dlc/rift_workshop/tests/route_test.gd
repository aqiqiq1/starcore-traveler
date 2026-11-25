extends Node

## Headless full-route test for dlc/rift_workshop.
##
##   ... --headless --path . res://dlc/rift_workshop/tests/route_test.tscn
##
## A real player-input route: walk (with automatic jump at the 40 px terrace
## step) through both inversion curtains and both gates, press Q on the two
## bridge landings, cross all three phase bridges, record the checkpoint, drop
## into the arena, defeat both guards with the guard's own true-damage
## resolution, touch the finish, read the completion page and press E back to
## the title.  No teleport is used for the traversal itself; only the guard
## fight uses the existing debug_force_gravity() hook (same precedent as the
## trial chapter's route test) so the 3 s gravity cycle does not make the run
## depend on wall-clock timing.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _rift: RiftWorkshop
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []
var _legs: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	Input.action_release(&"polarity")
	Input.action_release(&"jump")
	print("RIFT_ROUTE legs=%s" % ", ".join(_legs))
	print("RIFT_ROUTE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _force_true_hit(guard: L3Guard, other: L3Guard) -> bool:
	other.set_suspended(true)
	# Wait out of every guard's alert band: the arena spawn is the approved
	# retry point and sits just outside the gold guard's pursuit bound.
	_player.global_position = _rift.get_arena_spawn()
	_player.velocity = Vector2.ZERO
	var active: bool = await _wait_until(
		func() -> bool: return guard.get_state_name() == "ACTIVE", 700
	)
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
	_player.global_position = _rift.get_arena_spawn()
	_player.velocity = Vector2.ZERO
	await _wait_physics(4)
	return dealt


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)


# --- main flow -------------------------------------------------------------

func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	_rift = packed.instantiate() as RiftWorkshop
	_rift.show_intro_guide = false
	get_tree().root.add_child(_rift)
	get_tree().current_scene = _rift
	await _wait_process(3)
	await _wait_physics(8)
	_player = _rift.get_player()
	_check(_player != null, "chapter exposes an L3Player")
	if _player == null:
		return
	_check(not _player.is_positive(), "spawn is 澜相")

	# --- room 1: walk the corridor, both curtains flip automatically -----
	var reached: bool = await _walk_with_auto_jump(585.0, 2200)
	await _wait_until(func() -> bool: return _player.is_on_floor(), 120)
	_legs.append("corridor(585)=%.1f" % _player.global_position.x)
	_check(reached, "real walk reaches the terrace start",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	_check(_rift.get_field_a().get_trigger_count() >= 1,
		"first curtain fired while walking",
		"triggers=%d" % _rift.get_field_a().get_trigger_count())
	_check(_rift.get_field_b().get_trigger_count() >= 1,
		"second curtain fired while walking",
		"triggers=%d" % _rift.get_field_b().get_trigger_count())
	_check(not _player.is_positive(), "corridor ends in 澜相 (cyan gate passed)")
	_check(absf(_player.global_position.y - 280.0) < 2.0,
		"player stands on the raised terrace", "y=%.2f" % _player.global_position.y)
	_check(_rift.get_bridge_a().is_solid() == false,
		"gold bridge is not solid for the arriving 澜相 player")
	_check(_rift.get_hud().get_objective_text().contains("光桥"),
		"HUD asks for the bridges", _rift.get_hud().get_objective_text())

	# --- room 2: three bridges, Q on each landing ------------------------
	await _tap_polarity()
	_check(_player.is_positive(), "Q turns the player 辉相 for the gold bridge")
	await _wait_physics(2)
	_check(_rift.get_bridge_a().is_solid(), "gold bridge materialised")
	var ok: bool = await _move_until_x(770.0, 600)
	_legs.append("bridge1(770)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(ok and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across gold bridge 1 to landing A",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])

	await _tap_polarity()
	_check(not _player.is_positive(), "Q turns the player 澜相 for the cyan bridge")
	await _wait_physics(2)
	_check(_rift.get_bridge_b().is_solid(), "cyan bridge materialised")
	ok = await _move_until_x(880.0, 600)
	_legs.append("bridge2(880)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(ok and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across cyan bridge 2 to landing B",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])

	await _tap_polarity()
	_check(_player.is_positive(), "Q turns the player 辉相 for the second gold bridge")
	await _wait_physics(2)
	_check(_rift.get_bridge_c().is_solid(), "second gold bridge materialised")
	ok = await _move_until_x(1000.0, 600)
	_legs.append("bridge3(1000)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(ok and absf(_player.global_position.y - 280.0) < 2.0,
		"walked across gold bridge 3 to the end terrace",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])

	# --- checkpoint and arena entry --------------------------------------
	ok = await _move_until_x(1040.0, 600)
	_legs.append("checkpoint(1040)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(ok and _rift.is_checkpoint_active(), "walking over the marker records the checkpoint",
		"x=%.2f" % _player.global_position.x)
	ok = await _move_until_x(1096.0, 400)
	_legs.append("arena(1096)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	_check(ok and _rift.is_arena_entered(), "walking into the arena wakes the twin guards",
		"x=%.2f y=%.2f" % [_player.global_position.x, _player.global_position.y])
	# The 0.8 s opening hover must end before the fight is judged.
	await _wait_until(func() -> bool: return not _rift.is_arena_intro_active(), 120)
	await _wait_physics(20)
	_check(_rift.get_hud().get_objective_text().contains("双生守卫"),
		"HUD switches to the twin guard objective",
		_rift.get_hud().get_objective_text())

	# --- twin guard fight (real hit resolution) --------------------------
	var gold: L3Guard = _rift.get_guard_gold()
	var cyan: L3Guard = _rift.get_guard_cyan()
	for _index: int in range(3):
		var hit_ok: bool = await _force_true_hit(gold, cyan)
		_check(hit_ok, "gold guard hit %d resolved" % (_index + 1),
			"marks=%d" % gold.get_true_marks_taken())
		if not hit_ok:
			break
	await _wait_until(func() -> bool: return _rift.is_gold_defeated(), 400)
	_check(_rift.is_gold_defeated(), "gold guard defeated",
		"guards=%d" % _rift.get_guards_defeated())
	for _index: int in range(3):
		var hit_ok: bool = await _force_true_hit(cyan, gold)
		_check(hit_ok, "cyan guard hit %d resolved" % (_index + 1),
			"marks=%d" % cyan.get_true_marks_taken())
		if not hit_ok:
			break
	await _wait_until(func() -> bool: return _rift.is_cyan_defeated(), 400)
	_check(_rift.is_both_defeated(), "both guards defeated",
		"guards=%d" % _rift.get_guards_defeated())
	_check(_rift.get_finish_sprite().modulate.r > 0.9,
		"finish core becomes bright")

	# --- finish / completion / title -------------------------------------
	ok = await _move_until_x(1545.0, 900)
	_legs.append("finish(1545)=%.1f/%.1f" % [_player.global_position.x, _player.global_position.y])
	await _wait_physics(10)
	# The finish radius locks the player on contact, so the walk helper may stop
	# short of its target; completion itself is the real assertion.
	_check(_rift.is_completed(), "walking into the finish closes the rift",
		"x=%.2f" % _player.global_position.x)
	_check(_rift.get_hud().is_completion_visible(), "completion page is visible")
	var completion_text: String = _rift.get_hud().get_completion_text()
	var expression: RegEx = RegEx.new()
	expression.compile("^裂隙封闭 · 用时 [0-9]{2}:[0-9]{2}$")
	_check(expression.search(completion_text) != null,
		"completion text is 裂隙封闭 · 用时 mm:ss", completion_text)
	_check(_rift.get_elapsed_seconds() > 0.0, "completion time is real",
		"%.2f s" % _rift.get_elapsed_seconds())
	print("RIFT_ROUTE_COMPLETION_TEXT %s" % completion_text)

	_push_key(KEY_E, true)
	await _wait_physics(2)
	_push_key(KEY_E, false)
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
