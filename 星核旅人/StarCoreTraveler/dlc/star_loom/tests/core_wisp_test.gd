extends Node

## Headless assertion test for the earlier first wisp.
##
##   ... --headless --path . res://dlc/star_loom/tests/core_wisp_test.tscn
##
## Route: real walk over the arena line -> the boss starts at stage 1.  The
## very first natural request must be the 裂隙浮灵 summon even though the
## stage-1 attack pool stays ["homing"].  The first summon still creates one
## 44 px/s wisp, and a real J kills it in one hit.  The next natural request
## returns to the normal stage-1 homing pool, so this is an earlier first
## appearance, not a permanent stage-1 difficulty change.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"

var _loom: StarLoom
var _player: L3Player
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	MechanicTips.mark_seen("loom_fire_tip")
	await _run()
	await _cleanup()
	_release_all()
	print("STAR_LOOM_CORE_WISP_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _place(x: float, y: float) -> void:
	_player.global_position = Vector2(x, y)
	_player.velocity = Vector2.ZERO
	_player.set_polarity_state(false)
	_player.cancel_attack()
	_player.face_direction(1)
	_loom.get_camera().reset_smoothing()
	await _wait_physics(3)


func _load_loom() -> bool:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		return false
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = false
	_loom.show_intro_cinematic = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	await _wait_process(3)
	await _wait_physics(10)
	_player = _loom.get_player()
	return _player != null


func _cleanup() -> void:
	get_tree().paused = false
	await _wait_process(2)
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(20)
	_release_all()


func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads and exposes an L3Player")
	if _player == null:
		return

	# Real walk over the arena line: the boss starts at stage 1.
	await _place(420.0, 320.0)
	Input.action_press(&"move_right")
	var entered: bool = await _wait_until(
		func() -> bool: return _loom.is_boss_active(), 160
	)
	Input.action_release(&"move_right")
	await _wait_physics(4)
	_check(entered, "real walk starts the boss at stage 1")
	if not entered:
		return
	_check(_loom.get_stage() == 1, "the early wisp window is stage 1",
		str(_loom.get_stage()))
	_check(_loom.is_intro_summon_pending(),
		"the first natural request is the queued wisp summon")
	_check(_loom.get_attack_pool() == ["homing"],
		"the stage-1 pool is still homing-only", str(_loom.get_attack_pool()))
	_check(_loom.get_active_wisps() == 0,
		"no wisp exists before the first request")

	# Skip the 1.2 s opening grace so the test reaches the first request in a
	# few seconds; the attack order itself is unchanged.
	_loom.debug_set_boss_grace(0.0)
	_loom.debug_set_attacks_enabled(true)
	await _place(520.0, 320.0)

	var telegraphed: bool = await _wait_until(
		func() -> bool: return _loom.get_attack_state_name() == "telegraph", 240
	)
	_check(telegraphed, "the first round really starts")
	_check(_loom.get_attack_kind() == "summon",
		"the first round is the wisp summon, not homing",
		_loom.get_attack_kind())
	_check(not _loom.is_intro_summon_pending(),
		"the one-shot early summon is consumed")
	_check(_loom.get_telegraph_points().size() == 2,
		"the summon telegraph marks both rift points",
		str(_loom.get_telegraph_points().size()))
	_check(_loom.get_hud().get_event_text().contains("浮灵"),
		"the first-round HUD warning names the wisp",
		_loom.get_hud().get_event_text())
	_check(_loom.get_hud().get_event_text().contains("挥剑"),
		"the first-round warning teaches the one-hit answer",
		_loom.get_hud().get_event_text())

	var spawned: bool = await _wait_until(
		func() -> bool: return _loom.get_active_wisps() >= 1, 120
	)
	_check(spawned, "the first stage-1 summon really spawns a wisp")
	_check(_loom.get_stage() == 1,
		"the wisp is present in stage 1", str(_loom.get_stage()))
	_check(_loom.get_active_wisps() == 1,
		"the first summon creates exactly one wisp",
		str(_loom.get_active_wisps()))
	_check(_loom.get_player_hits() == 0 and _loom.get_lives() == 3,
		"the wisp reaches the player before any hit is taken",
		"hits=%d lives=%d" % [_loom.get_player_hits(), _loom.get_lives()])

	var wisp: LoomWisp = null
	for child: Node in _loom.get_node("Hazards").get_children():
		if child is LoomWisp:
			wisp = child as LoomWisp
			break
	_check(wisp != null and wisp.is_alive(),
		"the spawned wisp is alive and exposed to the test")
	if wisp != null:
		_check(wisp.get_life_left() > 0.0,
			"the wisp has its normal lifespan",
			"%.1fs" % wisp.get_life_left())
		_check(wisp.get_hit_rect().size == Vector2(28.0, 28.0),
			"the wisp keeps its normal 28x28 hit box",
			str(wisp.get_hit_rect().size))
		# One real J from just under the wisp kills it before its 28x28 body can
		# reach the player's head: the swing's 38 px reach covers the 8 px gap,
		# and the wisp only descends a few pixels during the real hit window.
		_player.global_position = Vector2(wisp.global_position.x - 8.0, 320.0)
		_player.velocity = Vector2.ZERO
		_player.face_direction(1)
		# Let the drifting wisp descend into the J hit box (the swing's top is
		# y-38).  It is still several pixels above the body when the real hit
		# window resolves, so this is a clean one-hit kill rather than a trade.
		await _wait_physics(5)
		await _swing_j()
		_check(not is_instance_valid(wisp) or not wisp.is_alive(),
			"one real J kills the early wisp")
		_check(_loom.get_player_hits() == 0 and _loom.get_lives() == 3,
			"the early wisp never has to cost a hit",
			"hits=%d lives=%d" % [_loom.get_player_hits(), _loom.get_lives()])
	var cleared: bool = await _wait_until(
		func() -> bool: return _loom.get_active_wisps() == 0, 60
	)
	_check(cleared, "the killed wisp leaves the hazards list")

	# The normal stage-1 order resumes: the next request is homing.
	var next_telegraph: bool = await _wait_until(
		func() -> bool: return _loom.get_attack_state_name() == "telegraph", 300
	)
	_check(next_telegraph, "the next stage-1 request starts")
	_check(_loom.get_attack_kind() == "homing",
		"after the early summon, stage 1 returns to homing",
		_loom.get_attack_kind())
	_check(_loom.get_stage() == 1,
		"the follow-up attack is still stage 1", str(_loom.get_stage()))
	_check(_loom.get_attack_pool() == ["homing"],
		"the stage-1 pool remains homing-only after the early summon",
		str(_loom.get_attack_pool()))
	_check(_loom.get_active_wisps() == 0,
		"no second wisp is queued by the early summon",
		str(_loom.get_active_wisps()))
	_check(_loom.get_player_hits() == 0,
		"the early wisp did not damage the player",
		str(_loom.get_player_hits()))
