extends Node

## Headless assertion test for the restored loom approach mechanics:
##   - the trial PolarityGate blocks a wrong-phase body and passes the matching
##     phase (real movement, real Q);
##   - the reused RuneStoneField slides the stone onto the socket (real Q and
##     field sample), opens the second gate, and can be pulled back;
##   - the socket holds the stone while the player walks past it;
##   - the base LevelCheckpoint records a spawn and failure returns there;
##   - the checkpoint permanently powers the second gate, so pulling the stone
##     back after the checkpoint cannot lock the player out;
##   - R restores the gate/stone/checkpoint initial state.
##
##   ... --headless --path . res://dlc/star_loom/tests/gate_test.tscn

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
	print("STAR_LOOM_GATE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _tap_polarity() -> void:
	Input.action_press(&"polarity")
	await _wait_physics(3)
	Input.action_release(&"polarity")
	await _wait_physics(5)


func _release_all() -> void:
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"polarity", &"reset", &"pause",
	]:
		Input.action_release(action)


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


func _walk_right_until(predicate: Callable, max_frames: int) -> bool:
	Input.action_press(&"move_right")
	var reached: bool = await _wait_until(predicate, max_frames)
	Input.action_release(&"move_right")
	await _wait_physics(3)
	return reached


func _walk_left_until(predicate: Callable, max_frames: int) -> bool:
	Input.action_press(&"move_left")
	var reached: bool = await _wait_until(predicate, max_frames)
	Input.action_release(&"move_left")
	await _wait_physics(3)
	return reached


func _run() -> void:
	_check(await _load_loom(), "star_loom scene loads and exposes an L3Player")
	if _player == null:
		return
	var gate_first: PolarityGate = _loom.get_gate_first()
	var gate_second: PolarityGate = _loom.get_gate_second()
	var stone: LoomRuneStone = _loom.get_rune_stone()
	var socket: LoomRuneSocket = _loom.get_rune_socket()
	var checkpoint: LevelCheckpoint = _loom.get_checkpoint()
	_check(gate_first != null and gate_second != null and stone != null
		and socket != null and checkpoint != null,
		"all three restored mechanisms exist in the scene")
	if gate_first == null or gate_second == null or stone == null \
			or socket == null or checkpoint == null:
		return

	_check(gate_first.get_emblem_kind() == "sun"
		and gate_first.get_required_positive(),
		"first gate reads the gold sun / 辉相")
	_check(gate_second.get_emblem_kind() == "moon"
		and not gate_second.get_required_positive(),
		"second gate reads the cyan moon / 澜相")
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"both gates start solid for the cyan player")
	_check(not gate_second.is_open() and gate_second.get_collision_layer() == 1,
		"second gate starts solid before the stone is seated")
	_check(not stone.get_field().is_positive() and stone.get_field().is_activated(),
		"the rune stone starts live in 澜相")
	_check(absf(stone.global_position.x - stone.get_start_x()) < 0.5,
		"the rune stone starts at its authored position",
		"x=%.1f" % stone.global_position.x)
	_check(not socket.is_occupied() and not checkpoint.is_activated(),
		"socket and checkpoint start clear")

	# --- wrong phase blocks, Q opens, real walk passes -------------------
	var blocked: bool = await _walk_right_until(
		func() -> bool: return gate_first.get_deny_count() > 0,
		220
	)
	_check(blocked, "real walk reaches and touches the closed first gate")
	_check(_player.global_position.x < gate_first.global_position.x - 2.0,
		"wrong-phase body is stopped before the gate",
		"x=%.1f" % _player.global_position.x)
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"wrong phase keeps the gate solid")
	_check(_loom.get_hud().get_event_text().contains("同相门")
		and _loom.get_hud().get_event_text().contains("辉相"),
		"the HUD event line names the required 辉相",
		_loom.get_hud().get_event_text())

	await _tap_polarity()
	_check(_player.is_positive(), "Q switches the body to 辉相")
	_check(gate_first.is_open() and gate_first.get_collision_layer() == 0,
		"matching phase opens the gate and clears its blocker",
		"layer=%d" % gate_first.get_collision_layer())
	var passed_gate: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x > gate_first.global_position.x + 18.0,
		120
	)
	_check(passed_gate, "matching-phase body really walks through the gate",
		"x=%.1f" % _player.global_position.x)

	# Stop left of the stone and switch back to its cyan phase.  The pull from
	# the gold body is allowed to settle first.
	var reached_stone: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x >= 200.0,
		160
	)
	_check(reached_stone, "the route reaches the rune stone section",
		"x=%.1f" % _player.global_position.x)
	await _tap_polarity()
	_check(not _player.is_positive(), "Q returns the body to 澜相")

	# --- push the stone onto the socket ---------------------------------
	var socketed: bool = await _wait_until(
		func() -> bool: return stone.is_on_socket(), 420
	)
	_check(socketed, "same-phase push seats the stone on the socket",
		"stone=%.1f" % stone.global_position.x)
	_check(socket.is_occupied(), "the socket reports the stone")
	_check(gate_second.is_open() and gate_second.get_collision_layer() == 0,
		"stone in the socket opens the second gate",
		"layer=%d" % gate_second.get_collision_layer())
	await _wait_physics(2)
	_check(_loom.get_hud().get_event_text().contains("压槽")
		and _loom.get_hud().get_event_text().contains("第二道门"),
		"the HUD event line reports the stone seating and the door",
		_loom.get_hud().get_event_text())

	# --- pull it back, then push it in again ----------------------------
	await _tap_polarity()
	var pulled_off: bool = await _wait_until(
		func() -> bool: return not stone.is_on_socket(), 240
	)
	_check(pulled_off, "opposite-phase pull moves the stone back off the socket",
		"stone=%.1f" % stone.global_position.x)
	_check(not gate_second.is_open() and gate_second.get_collision_layer() == 1,
		"second gate closes again while the stone is off the socket",
		"layer=%d" % gate_second.get_collision_layer())
	await _tap_polarity()
	var resocketed: bool = await _wait_until(
		func() -> bool: return stone.is_on_socket(), 420
	)
	_check(resocketed, "same-phase push returns the stone to the socket",
		"stone=%.1f" % stone.global_position.x)
	_check(gate_second.is_open(), "second gate reopens after the stone returns")

	# --- walk past the stone; the socket holds it, then checkpoint ------
	var crossed_second: bool = await _walk_right_until(
		func() -> bool: return _player.global_position.x > gate_second.global_position.x + 12.0,
		220
	)
	_check(crossed_second, "the body walks through the opened second gate",
		"x=%.1f" % _player.global_position.x)
	_check(stone.is_on_socket(),
		"walking past the stone does not push it back out",
		"stone=%.1f" % stone.global_position.x)
	var checkpoint_on: bool = await _wait_until(
		func() -> bool: return checkpoint.is_activated(), 120
	)
	_check(checkpoint_on, "the checkpoint activates after the second gate",
		"x=%.1f" % _player.global_position.x)
	_check(_loom.get_hud().get_event_text().contains("检查点"),
		"the HUD event line confirms the checkpoint",
		_loom.get_hud().get_event_text())
	_check(checkpoint.get_state_texture() != null
		and checkpoint.get_state_texture().resource_path.ends_with("checkpoint_active.png"),
		"the checkpoint uses the base active texture")
	_check(checkpoint.get_texture_size() == Vector2(40.0, 36.0),
		"the checkpoint keeps its native 40x36 art", str(checkpoint.get_texture_size()))
	_check(absf(_loom.get_checkpoint_position().x - checkpoint.global_position.x) < 0.5,
		"the checkpoint stores its real feet position",
		"x=%.1f" % _loom.get_checkpoint_position().x)

	# --- checkpoint keeps the second gate open after a pull -------------
	# Walk back left of the stone, then pull it off.  The gate must stay open
	# because the checkpoint is now the stable progress record.
	var back_left: bool = await _walk_left_until(
		func() -> bool: return _player.global_position.x <= 300.0,
		260
	)
	_check(back_left, "the player can walk back through the open gate",
		"x=%.1f" % _player.global_position.x)
	await _tap_polarity()
	var off_after_checkpoint: bool = await _wait_until(
		func() -> bool: return not stone.is_on_socket(), 240
	)
	_check(off_after_checkpoint, "the stone can still be pulled back after the checkpoint",
		"stone=%.1f" % stone.global_position.x)
	_check(gate_second.is_open(),
		"checkpoint latch keeps the second gate open (no far-side softlock)")

	# --- the boss starts, failure returns to the checkpoint -------------
	var entered: bool = await _walk_right_until(
		func() -> bool: return _loom.is_boss_active(), 260
	)
	_check(entered, "walking on starts the loom after the approach puzzle")
	if entered:
		_loom.debug_set_attacks_enabled(false)
		_loom.debug_clear_hazards()
		_loom.debug_set_stage(2)
		await _wait_physics(60)
		for _hit_index: int in range(3):
			_loom.debug_apply_player_hit()
			await _wait_physics(2)
			if _hit_index < 2:
				await _wait_until(
					func() -> bool: return _loom.get_damage_immunity_left() <= 0.0,
					160
				)
		var recovery_started: bool = await _wait_until(
			func() -> bool: return _loom.is_recovery_active(), 80
		)
		_check(recovery_started, "three accepted hits start the failure cover")
		var recovery_ended: bool = await _wait_until(
			func() -> bool: return not _loom.is_recovery_active(), 300
		)
		_check(recovery_ended, "the failure fade finishes")
		_check(absf(_player.global_position.x - checkpoint.global_position.x) < 4.0,
			"failure respawns at the checkpoint, not the old arena spawn",
			"x=%.1f" % _player.global_position.x)
		_check(checkpoint.is_activated(),
			"the checkpoint survives the failure")
		_check(gate_second.is_open(),
			"the checkpoint-powered gate survives the failure")
		_check(_loom.get_stage() == 2,
			"failure still retries the current stage", str(_loom.get_stage()))

	# --- R restores the whole approach ----------------------------------
	_push_key(KEY_R, true)
	await _wait_physics(2)
	_push_key(KEY_R, false)
	await _wait_physics(12)
	_check(absf(_player.global_position.x - _loom.get_start_spawn().x) < 4.0,
		"R returns the body to the chapter start",
		"x=%.1f" % _player.global_position.x)
	_check(absf(stone.global_position.x - stone.get_start_x()) < 0.5,
		"R restores the stone initial position",
		"x=%.1f" % stone.global_position.x)
	_check(not socket.is_occupied() and not gate_second.is_open()
		and gate_second.get_collision_layer() == 1,
		"R closes the second gate and clears the socket")
	_check(not checkpoint.is_activated(),
		"R clears the checkpoint")
	_check(not gate_first.is_open() and gate_first.get_collision_layer() == 1,
		"R leaves the first gate solid for the reset cyan body")
