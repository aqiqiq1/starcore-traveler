extends Node

## Route probe for the rebuilt L2. Starts with the real safe first transport:
## E release at the start bay, Q to the core's polarity, let the real field move
## the same core toward the relay bay, then E store. No player/core teleports in
## this segment.

const L2: PackedScene = preload("res://scenes/level_02.tscn")
var _level: Level02
var _player: PrototypePlayer
var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("ROUTE CHECK FAIL: " + text)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = L2.instantiate() as Level02
	add_child(_level)
	await _frames(10)
	_check(_level.get_node_or_null("Guard") == null, "no Guard node")
	_check(not _level.get_core().is_active(), "core begins in the start bay")
	_player = _level.get_player()
	_player.reset_performed.connect(func(reason: String, count: int) -> void:
		print("PLAYER RESET reason=%s count=%d pos=%s" % [reason, count, str(_player.global_position)])
	)
	_level.get_link().link_reset.connect(func() -> void: print("LINK RESET"))
	print("START player=", _player.global_position, " core=", _level.get_core().global_position)
	await _walk_to_x(100.0, 300)
	await _tap_action(&"interact")
	await _physics(20)
	print("AFTER RELEASE core=", _level.get_core().global_position, " active=", _level.get_core().is_active(), " polarity=", _level.get_core().is_positive())
	_check(_level.get_core().is_active() and not _level.get_core().is_positive(), "first E release produced the CYAN moving core")
	_check(_level.get_hud().get_phase_text().contains("中继仓"), "safe first transport HUD names the relay bay")
	# Player is GOLD +; release core is CYAN -. Switch to CYAN so the same sign
	# repels the core to the right while the player stays on its left.
	await _tap_action(&"polarity")
	print("PLAYER polarity=", _player.is_positive())
	for i: int in range(12):
		await _physics(10)
		print("CORE t=%d x=%.1f v=%.1f dist=%.1f" % [
			(i + 1) * 10,
			_level.get_core().global_position.x,
			_level.get_core().velocity.x,
			_player.global_position.distance_to(_level.get_core().global_position),
		])
	print("CORE STOPPED x=", _level.get_core().global_position.x)
	# Attract the stopped core toward the relay instead of pushing it past the
	# seat: opposite polarity, then walk to the bay.
	await _tap_action(&"polarity")
	await _walk_to_x(340.0, 400)
	for i: int in range(6):
		await _physics(10)
		print("PULL t=%d player=%.1f core=%.1f dist=%.1f" % [
			(i + 1) * 10, _player.global_position.x, _level.get_core().global_position.x,
			_player.global_position.distance_to(_level.get_core().global_position),
		])
	await _walk_to_x(352.0, 200)
	await _physics(20)
	await _walk_to_x(370.0, 120)
	await _physics(20)
	print("PLAYER near relay=", _player.global_position, " core=", _level.get_core().global_position)
	await _tap_action(&"interact")
	await _physics(20)
	print("RELAY locked=", _level.get_relay_bay().is_locked(), " stable=", _level.get_stable_stage(), " completed=", _level.is_completed())
	_check(_level.get_relay_bay().is_locked() and _level.get_stable_stage() == 1, "first transport stores in the relay bay and sets stable 1")
	_check(not _level.is_completed(), "relay store does not complete the level")

	# Segment B: release the same core from the relay and push it into the
	# 20 px low corridor. The player must then jump onto the 48 px pier top.
	await _walk_to_x(360.0, 120)
	await _tap_action(&"interact")
	await _physics(20)
	print("RELAY RELEASE core=", _level.get_core().global_position, " active=", _level.get_core().is_active())
	await _walk_to_x(250.0, 240)
	await _tap_action(&"polarity")
	print("PUSH polarity=", _player.is_positive(), " core_positive=", _level.get_core().is_positive(), " player=", _player.global_position.x, " core=", _level.get_core().global_position.x)
	# Keep roughly 60 px to the core's left. Holding still inside the 40 px
	# inner radius would produce no force; walking past the core would erase the
	# push. This is a real same-sign push through the low corridor.
	for i: int in range(240):
		var desired: float = clampf(_level.get_core().global_position.x - 60.0, 240.0, 452.0)
		if _player.global_position.x < desired - 2.0:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		elif _player.global_position.x > desired + 2.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await get_tree().physics_frame
		if i % 20 == 0:
			print("PUSH t=%d player=%.1f core=%.1f dist=%.1f" % [
				i, _player.global_position.x, _level.get_core().global_position.x,
				_player.global_position.distance_to(_level.get_core().global_position),
			])
		if _level.get_core().global_position.x >= 560.0:
			break
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(30)
	print("PUSH END player=", _player.global_position, " core=", _level.get_core().global_position, " ground=", _player.is_on_floor())

	# Jump right onto the entry pier/deck.
	Input.action_press(&"jump")
	Input.action_press(&"move_right")
	await _physics(10)
	Input.action_release(&"jump")
	await _physics(20)
	Input.action_release(&"move_right")
	await _physics(40)
	print("JUMP END player=", _player.global_position, " ground=", _player.is_on_floor(), " core=", _level.get_core().global_position)
	_check(_player.global_position.y < 270.0 and _player.is_on_floor(), "player jumps onto the 268 pier top")
	_check(_level.get_core().global_position.x > 520.0, "core is inside the low corridor")

	# Segment B seam: stay left of the core and keep the force line crossing a
	# real 10 px gap. Same polarity pushes the core right. The target is solved
	# from the deck plane and the core's current position, not teleported.
	var gaps: Array[float] = [539.0, 571.0, 603.0, 635.0, 667.0]
	for i: int in range(300):
		var core_pos: Vector2 = _level.get_core().global_position
		var player_center_y: float = _player.global_position.y - 15.0
		var frac: float = 0.0
		if absf(core_pos.y - player_center_y) > 0.1:
			frac = clampf((271.5 - player_center_y) / (core_pos.y - player_center_y), 0.0, 0.9)
		var gap_center: float = -1.0
		var best: float = 1e20
		for gap: float in gaps:
			if gap <= core_pos.x - 10.0 and absf(gap - (core_pos.x - 28.0)) < best:
				best = absf(gap - (core_pos.x - 28.0))
				gap_center = gap
		var target: float = _player.global_position.x
		if gap_center > 0.0 and frac < 0.95:
			target = clampf((gap_center - frac * core_pos.x) / (1.0 - frac), 515.0, 700.0)
		if _player.global_position.x < target - 2.0:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		elif _player.global_position.x > target + 2.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await get_tree().physics_frame
		if i % 30 == 0:
			print("SEAM t=%d player=%.1f/%.1f target=%.1f core=%.1f" % [
				i, _player.global_position.x, _player.global_position.y, target, _level.get_core().global_position.x
			])
		if _level.get_core().global_position.x > 680.0:
			break
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	print("SEAM END player=", _player.global_position, " core=", _level.get_core().global_position)
	_check(_level.get_core().global_position.x > 650.0, "same core is pulled through the real deck seams")

	# Drop off the right end, then attract the same core to the linked bay.
	Input.action_press(&"move_right")
	await _physics(40)
	Input.action_release(&"move_right")
	await _physics(20)
	print("DROP player=", _player.global_position, " core=", _level.get_core().global_position)
	# Opposite polarity now: stand right of the core and walk toward the linked bay.
	await _tap_action(&"polarity")
	for i: int in range(240):
		var desired: float = clampf(_level.get_core().global_position.x + 60.0, 740.0, 1000.0)
		if _player.global_position.x < desired - 2.0:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		elif _player.global_position.x > desired + 2.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await get_tree().physics_frame
		if _player.global_position.x >= 1000.0:
			break
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(50)
	print("LINK PULL player=", _player.global_position, " core=", _level.get_core().global_position)
	await _tap_action(&"interact")
	await _physics(20)
	print("LINK STORE locked=", _level.get_linked_bay().is_locked(), " stable=", _level.get_stable_stage(), " rune=", _level.get_rune_field().is_activated())
	for i: int in range(180):
		await get_tree().physics_frame
		if _level.get_rune_field().is_activated():
			break
	print("LINK RUNE active=", _level.get_rune_field().is_activated(), " positive=", _level.get_rune_field().is_positive(), " record=", _level.get_link().get_record_positive())
	_check(_level.get_linked_bay().is_locked() and _level.get_stable_stage() == 2, "linked store sets stable 2 without completing")
	_check(not _level.is_completed(), "linked store does not complete the level")
	_check(_level.get_rune_field().is_activated(), "linked record activates the rune after the real pulse")

	# Segment C/D: take the same core out, push it into the 20 px corridor under
	# the 80 px sill, then use the active rune to climb the lip and pull the core
	# through to the final bay.
	if _player.is_positive():
		await _tap_action(&"polarity")  # same as the CYAN rune: stay grounded
	await _walk_to_x(920.0, 160)
	await _tap_action(&"polarity")      # opposite to release a CYAN core
	await _tap_action(&"interact")
	for i: int in range(40):
		await get_tree().physics_frame
		if _level.get_core().is_active():
			break
	await _tap_action(&"polarity")      # back to same-as-rune CYAN for the push
	await _physics(2)
	print("C RELEASE player=", _player.global_position, " core=", _level.get_core().global_position, " core_positive=", _level.get_core().is_positive())
	print("C PUSH polarity=", _player.is_positive())
	var dbg: Dictionary = _level.compute_field(
		_player.global_position + Vector2(0, -15), _level.get_core().global_position,
		_player.is_positive(), _level.get_core().is_positive()
	)
	print("C FIELD status=", dbg.get("status"), " core_accel=", dbg.get("core_acceleration"), " player_accel=", dbg.get("player_acceleration"), " blocked=", dbg.get("blocked"))
	for i: int in range(220):
		var desired: float = clampf(_level.get_core().global_position.x - 60.0, 940.0, 1074.0)
		if _player.global_position.x < desired - 2.0:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		elif _player.global_position.x > desired + 2.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await get_tree().physics_frame
		if i % 40 == 0:
			print("C PUSH t=%d player=%.1f/%.1f core=%.1f active=%s cp=%s stage=%s" % [
				i, _player.global_position.x, _player.global_position.y,
				_level.get_core().global_position.x, str(_level.get_core().is_active()),
				str(_level.get_core().is_positive()), _level.get_link().get_link_stage_label(),
			])
		if _level.get_core().global_position.x >= 1168.0:
			break
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(20)
	print("C PUSH END player=", _player.global_position, " core=", _level.get_core().global_position)
	_check(_level.get_core().global_position.x >= 1160.0, "same core is pushed into the 20 px sill corridor")
	_check(_level.get_rune_field().is_activated(), "rune remains active after taking the core out")

	# Stand left of the lip, switch opposite the rune, and let the real field lift.
	await _walk_to_x(1028.0, 120)
	print("C PRE-CLIMB player=", _player.global_position, " polarity=", _player.is_positive(), " rune=", _level.get_rune_field().is_positive())
	if _player.is_positive() == _level.get_rune_field().is_positive():
		await _tap_action(&"polarity")
	var climbed: bool = false
	Input.action_press(&"jump")
	await _physics(2)
	Input.action_release(&"jump")
	for i: int in range(240):
		# Counter the rune's rightward component until the feet clear the lip.
		Input.action_press(&"move_left")
		await get_tree().physics_frame
		if _player.global_position.y < 235.0:
			climbed = true
			break
	Input.action_release(&"move_left")
	print("C LIFT player=", _player.global_position, " lifted=", climbed)
	if climbed:
		Input.action_press(&"move_right")
		for i: int in range(90):
			await get_tree().physics_frame
			if _player.global_position.x >= 1090.0:
				break
		Input.action_release(&"move_right")
		# Same polarity as the rune now repels downward onto the wall top.
		await _tap_action(&"polarity")
		await _physics(80)
	print("C CLIMB END player=", _player.global_position, " ground=", _player.is_on_floor(), " core=", _level.get_core().global_position)
	_check(_player.global_position.y <= 242.0 and _player.is_on_floor() and _player.global_position.x >= 1080.0, "real rune lift lands the player on the 80 px sill")
	await _walk_to_x(1260.0, 200)
	await _physics(20)
	print("C DROP player=", _player.global_position, " core=", _level.get_core().global_position)

	# Opposite polarity: stand right of the core and draw it to the final bay.
	if _player.is_positive() == _level.get_core().is_positive():
		await _tap_action(&"polarity")
	for i: int in range(260):
		var desired: float = clampf(_level.get_core().global_position.x + 60.0, 1250.0, 1600.0)
		if _player.global_position.x < desired - 2.0:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		elif _player.global_position.x > desired + 2.0:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
		await get_tree().physics_frame
		if _player.global_position.x >= 1600.0:
			break
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _physics(40)
	print("D PULL player=", _player.global_position, " core=", _level.get_core().global_position)
	await _tap_action(&"interact")
	await _physics(20)
	print("D STORE final=", _level.get_final_bay().is_locked(), " completed=", _level.is_completed())
	_check(_level.get_final_bay().is_locked(), "final bay locks only at the final store")
	_check(not _level.is_completed(), "final store alone does not complete before the exit")
	await _walk_to_x(1680.0, 240)
	await _physics(20)
	print("D EXIT completed=", _level.is_completed(), " player=", _player.global_position)
	_check(_level.is_completed(), "player reaching the exit completes the level")
	_check(_level.get_hud().is_completion_visible(), "completion page is visible")
	_check(_level.get_hud().get_completion_primary_button().text == "返回主界面", "completion offers return to title, not a fake L3 jump")
	print("ROUTE_PROBE_B_DONE")

	# R on the completion page is a full restart, not a reset to the final store.
	_level.get_hud().replay_requested.emit()
	await _frames(20)
	await _physics(10)
	_check(not _level.is_completed(), "R clears completion")
	_check(_level.get_stable_stage() == 0, "R clears stable progress")
	_check(_level.get_bays()[0].is_locked() and not _level.get_core().is_active(), "R restores the core to the start bay")
	_check(not _level.get_rune_field().is_activated(), "R clears the rune")
	_write_log()
	print("LEVEL02_ROUTE_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _walk_to_x(target: float, max_frames: int) -> void:
	var guard: int = 0
	while absf(_player.global_position.x - target) > 3.0 and guard < max_frames:
		var action: StringName = &"move_right" if _player.global_position.x < target else &"move_left"
		Input.action_press(action)
		await get_tree().physics_frame
		Input.action_release(action)
		guard += 1
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await get_tree().physics_frame


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/level02_rebuild_route.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
