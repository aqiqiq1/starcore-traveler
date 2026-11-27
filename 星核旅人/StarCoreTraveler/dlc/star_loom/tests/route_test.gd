extends Node

## Full clear route for 星核织机.
##
##   ... --headless --path . res://dlc/star_loom/tests/route_test.tscn
##
## Real walk from the left spawn to the hall entrance, then three real stages:
## every node break and every core true hit is a real physical J through
## attack_hit_window; stage changes happen through the chapter's own
## 3-true-hit rule, not debug_set_stage.  Node orbit angles are parked so the
## test is deterministic (debug placement only); hazards are switched off for
## this route because the mechanics test already owns the attack/hit coverage.
## Finishes on the completion page and presses E back to level_01.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _loom: StarLoom
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# The one remaining teaching popup owns its own test; the route must not
	# be paused by the fire tip.  Marking it seen is test isolation, not a
	# gameplay bypass.
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	await _cleanup()
	_release_all()
	print("STAR_LOOM_ROUTE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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


func _release_all() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause",
	]:
		Input.action_release(action)


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(3)
	Input.action_release(&"polarity")
	await _wait_physics(5)


func _place(x: float, y: float, positive: bool) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(positive)
	_player.cancel_attack()
	_loom.get_camera().reset_smoothing()
	await _wait_physics(3)


func _wait_attack_ready() -> void:
	await _wait_until(
		func() -> bool: return not _player.is_attacking() and _player.get_attack_cooldown() <= 0.0,
		90
	)


func _swing_j() -> void:
	_push_key(KEY_J, true)
	await _wait_physics(7)
	_push_key(KEY_J, false)
	await _wait_physics(2)
	await _wait_attack_ready()


## The exposed core is raised; every true hit in the route must be a real jump
## swing through the same attack hit window.
func _jump_swing_j() -> void:
	Input.action_press(&"jump")
	await _wait_physics(8)
	await _swing_j()
	Input.action_release(&"jump")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 90)


func _park_node(index: int, positive: bool) -> void:
	var target: LoomNode = _loom.get_nodes()[index]
	var other: LoomNode = _loom.get_nodes()[1 - index]
	for node: LoomNode in _loom.get_nodes():
		node.set_orbit_enabled(false)
		node.set_phase_timer_enabled(false)
	target.debug_set_angle(PI * 0.5)
	target.debug_set_phase(positive)
	other.debug_set_angle(-PI * 0.5)
	await _wait_physics(2)


func _park_all_nodes_neutral() -> void:
	for node: LoomNode in _loom.get_nodes():
		node.set_orbit_enabled(false)
		node.set_phase_timer_enabled(false)


func _break_stage_nodes() -> bool:
	await _park_node(0, true)
	await _place(660.0, 320.0, false)
	await _swing_j()
	var a_dead: bool = not _loom.get_nodes()[0].is_alive()
	await _park_node(1, false)
	await _place(660.0, 320.0, true)
	await _swing_j()
	var b_dead: bool = not _loom.get_nodes()[1].is_alive()
	return a_dead and b_dead


func _hit_core_three_times() -> bool:
	for _index: int in range(3):
		await _place(660.0, 320.0, not _loom.get_core().get_phase())
		var before_hits: int = _loom.get_core_hits()
		var before_stage: int = _loom.get_stage()
		await _jump_swing_j()
		var advanced: bool = (
			_loom.get_core_hits() > before_hits
			or _loom.get_stage() > before_stage
			or _loom.is_completed()
		)
		if not advanced:
			return false
	return true


func _cleanup() -> void:
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	# The route ends on the level_01 title.  Let the title BGM/audio thread
	# release its OGG before the headless exit.
	await _wait_process(20)
	_release_all()


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	_check(packed != null, "star_loom scene loads")
	if packed == null:
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(3)
	await _wait_physics(8)
	_player = _loom.get_player()
	_check(_player != null, "route has a real L3Player")
	if _player == null:
		return

	# Real walk through the restored approach: sun gate -> rune stone -> moon
	# gate -> checkpoint.  Every step is a real key/action and the player's own
	# body, not a teleport.
	var gate_first: PolarityGate = _loom.get_gate_first()
	var gate_second: PolarityGate = _loom.get_gate_second()
	var stone: LoomRuneStone = _loom.get_rune_stone()
	var checkpoint: LevelCheckpoint = _loom.get_checkpoint()
	Input.action_press(&"move_right")
	await _wait_until(
		func() -> bool: return gate_first.get_deny_count() > 0, 320
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(_player.global_position.x < gate_first.global_position.x - 2.0,
		"wrong-phase body is really blocked by the sun gate",
		"x=%.1f" % _player.global_position.x)
	_check(not gate_first.is_open(), "sun gate is closed for the cyan body")
	await _tap_polarity()
	_check(_player.is_positive() and gate_first.is_open(),
		"Q opens the sun gate for the matching 辉相 body")
	Input.action_press(&"move_right")
	var through_first: bool = await _wait_until(
		func() -> bool: return _player.global_position.x > gate_first.global_position.x + 18.0,
		160
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(through_first, "the body walks through the sun gate",
		"x=%.1f" % _player.global_position.x)

	Input.action_press(&"move_right")
	await _wait_until(
		func() -> bool: return _player.global_position.x >= 200.0, 180
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	await _tap_polarity()
	_check(not _player.is_positive(),
		"Q returns the body to 澜相 for the cyan rune stone")
	var socketed: bool = await _wait_until(
		func() -> bool: return stone.is_on_socket(), 420
	)
	_check(socketed, "same-phase push seats the rune stone on the socket",
		"stone=%.1f" % stone.global_position.x)
	_check(_loom.get_rune_socket().is_occupied() and gate_second.is_open(),
		"the seated stone opens the moon gate")

	# Real walk into the hall: the socket holds the stone as the body passes,
	# and the checkpoint records the spawn before the arena line.
	Input.action_press(&"move_right")
	var entered: bool = await _wait_until(
		func() -> bool: return _loom.is_boss_active(), 500
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(entered, "real walk reaches the entrance and starts the boss")
	_check(_player.global_position.x >= _loom.get_arena_enter_x(),
		"player crossed the entrance line", "x=%.1f" % _player.global_position.x)
	_check(checkpoint.is_activated(),
		"the checkpoint records the spawn before the arena",
		"x=%.1f" % _loom.get_checkpoint_position().x)
	_loom.debug_set_attacks_enabled(false)
	_loom.debug_set_boss_grace(0.0)

	_park_all_nodes_neutral()
	for stage_expected: int in range(1, 4):
		_check(_loom.get_stage() == stage_expected,
			"route reaches stage %d" % stage_expected, str(_loom.get_stage()))
		_check(_loom.get_core_hits() == 0,
			"stage %d starts at 0 core damage" % stage_expected)
		_check(await _break_stage_nodes(),
			"stage %d both nodes break from real J" % stage_expected)
		_check(_loom.is_core_exposed(),
			"stage %d core is exposed" % stage_expected)
		_check(await _hit_core_three_times(),
			"stage %d lands three real core true hits" % stage_expected)
		if stage_expected < 3:
			_check(_loom.get_stage() == stage_expected + 1,
				"stage %d advances after the third true hit" % stage_expected,
				str(_loom.get_stage()))
			_check(_loom.get_nodes_alive_count() == 2,
				"stage %d respawns both nodes" % (stage_expected + 1))

	var completed: bool = await _wait_until(
		func() -> bool: return _loom.is_completed(), 180
	)
	_check(completed, "the full route completes all three stages")
	if completed:
		var hud: LoomHUD = _loom.get_hud()
		_check(hud.is_completion_visible(), "completion page is visible")
		_check(hud.get_completion_text().begins_with("织机停转 · 用时"),
			"completion title is correct", hud.get_completion_text())
		_check(_loom.get_elapsed_seconds() > 3.0,
			"completion timer is a real fight time",
			"%.1fs" % _loom.get_elapsed_seconds())
		_push_key(KEY_E, true)
		await _wait_physics(2)
		_push_key(KEY_E, false)
		var title_ok: bool = await _wait_until(
			func() -> bool:
				var current: Node = get_tree().current_scene
				return (
					current != null
					and current.scene_file_path == LEVEL_01
					and current.get_node_or_null("StartMenu") != null
				),
			180
		)
		_check(title_ok, "E returns to level_01 with the title menu")
		if title_ok:
			var menu: StartMenu = get_tree().current_scene.get_node_or_null("StartMenu") as StartMenu
			_check(menu != null and menu.is_menu_open(),
				"the returned title menu is open")
