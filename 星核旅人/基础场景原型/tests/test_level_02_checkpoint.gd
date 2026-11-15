extends Node

## Checkpoint and reset semantics for the rebuilt L2.
## Run:
##   Godot --headless --path . res://tests/test_level_02_checkpoint.tscn

const L2: PackedScene = preload("res://scenes/level_02.tscn")
var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []
var _level: Level02
var _player: PrototypePlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_core_out_restores_relay()
	await _test_fall_restores_linked()
	await _test_same_bay_phase_update()
	await _test_no_rune_jump_fails()
	await _test_pause_freeze_resume()
	await _test_final_takeout_closes_gate()
	await _test_r_during_pulse()
	await _test_gate_requires_link()
	_write_log()
	print("LEVEL02_CHECKPOINT_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _new_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
		await _frames(4)
	_level = L2.instantiate() as Level02
	add_child(_level)
	await _frames(10)
	_player = _level.get_player()


func _test_core_out_restores_relay() -> void:
	await _new_level()
	_level.debug_restore_stage(1, true)
	await _physics(4)
	# Release the same core from the relay (setup to this segment), then force
	# it out of bounds. The stable relay state must come back without replaying
	# the start.
	_player.global_position = Vector2(330, 320)
	await _tap(&"interact")
	await _physics(24)
	_check(_level.get_core().is_active(), "core is active before out-of-bounds")
	_level.get_core().global_position = Vector2(1800, 312)
	await _physics(20)
	_check(_level.get_stable_stage() == 1, "core out keeps stable relay stage")
	_check(_level.get_relay_bay().is_locked(), "core out restores the core to the relay bay")
	_check(_player.global_position.is_equal_approx(Vector2(400, 320)), "core out restores the relay respawn")
	_check(not _level.get_rune_field().is_activated(), "relay restore leaves the rune inactive")


func _test_fall_restores_linked() -> void:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	_check(_level.get_linked_bay().is_locked() and _level.get_rune_field().is_activated(), "linked setup is stable")
	_player.global_position = Vector2(700, 500)
	await _physics(20)
	_check(_level.get_stable_stage() == 2, "fall keeps stable linked stage")
	_check(_level.get_linked_bay().is_locked(), "fall restores the core to the linked bay")
	_check(_level.get_rune_field().is_activated(), "fall restores the linked rune")
	_check(_level.get_rune_field().is_positive() == false, "fall restores the recorded CYAN polarity")
	_check(_player.global_position.is_equal_approx(Vector2(830, 320)), "fall restores the linked respawn")


func _test_same_bay_phase_update() -> void:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	_check(_level.get_stable_positive() == false, "linked stable begins CYAN")
	_player.global_position = Vector2(920, 320)
	_player.velocity = Vector2.ZERO
	_player.clear_input_buffers()
	await _physics(4)
	if _player.is_positive():
		await _tap(&"polarity")  # CYAN, same as the current rune
	_check(_player.is_positive() == false, "player CYAN before the re-store")
	await _tap(&"interact")      # release: core becomes GOLD
	for _i: int in range(40):
		await get_tree().physics_frame
		if _level.get_core().is_active():
			break
	_check(_level.get_core().is_active() and _level.get_core().is_positive(), "same linked bay releases a GOLD core")
	for _i: int in range(90):
		await get_tree().physics_frame
		if absf(_level.get_core().global_position.x - 960.0) <= 22.0:
			break
	await _tap(&"interact")      # store the GOLD core back into the same bay
	await _physics(30)
	_check(_level.get_linked_bay().is_locked(), "same bay re-locks after the second store")
	_check(_level.get_linked_bay().get_recorded_positive(), "same bay now records GOLD")
	_check(_level.get_stable_stage() == 2 and _level.get_stable_positive(), "same stable stage updates to the new GOLD phase")
	for _i: int in range(180):
		await get_tree().physics_frame
		if (
			_level.get_rune_field().is_activated()
			and _level.get_rune_field().is_positive() == _level.get_link().get_record_positive()
			and not _level.get_link().is_field_pending()
		):
			break
	_check(_level.get_rune_field().is_activated() and _level.get_rune_field().is_positive(), "rune commits GOLD")
	# Death after the same-bay update must restore the latest phase, not CYAN.
	_player.global_position = Vector2(700, 500)
	await _physics(20)
	_check(_level.get_stable_stage() == 2 and _level.get_stable_positive(), "death restores stable GOLD phase")
	_check(_level.get_linked_bay().is_locked() and _level.get_linked_bay().get_recorded_positive(), "death restores the GOLD bay record")
	_check(_level.get_rune_field().is_activated() and _level.get_rune_field().is_positive(), "death restores the active GOLD rune")
	await _physics(120)
	_check(_level.get_rune_field().is_positive(), "no old CYAN pulse lands after restore")
	# A store in an earlier bay may not downgrade the linked checkpoint.
	_level.call("_set_stable", 1, false)
	_check(_level.get_stable_stage() == 2 and _level.get_stable_positive(), "earlier-bay update cannot downgrade stage 2")


func _test_no_rune_jump_fails() -> void:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	# Remove the rune (test setup) while leaving the same 80 px sill and the
	# core in the linked bay, then attempt the normal jump from the left.
	_level.get_link().reset_link()
	_player.global_position = Vector2(1028, 320)
	_player.velocity = Vector2.ZERO
	await _physics(4)
	Input.action_press(&"jump")
	Input.action_press(&"move_right")
	await _physics(10)
	Input.action_release(&"jump")
	await _physics(50)
	Input.action_release(&"move_right")
	await _physics(20)
	_check(_player.global_position.y > 245.0, "without the rune, the player cannot reach the 240 sill")
	_check(not _level.get_rune_field().is_activated(), "no-rune control really has an inactive rune")


func _test_pause_freeze_resume() -> void:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	await _tap_key(KEY_ESCAPE)
	await _physics(2)
	_check(get_tree().paused, "Esc pause freezes the tree")
	var player_before: Vector2 = _player.global_position
	var core_before: Vector2 = _level.get_core().global_position
	await _physics(10)
	_check(_player.global_position.is_equal_approx(player_before), "player stays frozen while paused")
	_check(_level.get_core().global_position.is_equal_approx(core_before), "core stays frozen while paused")
	await _tap_key(KEY_ESCAPE)
	await _physics(4)
	_check(not get_tree().paused, "second Esc resumes the tree")
	_check(_level.get_rune_field().is_activated(), "pause resume does not clear the linked rune")


func _test_final_takeout_closes_gate() -> void:
	_level.debug_restore_stage(2, false)
	await _physics(4)
	var final_bay: StarCoreBayInteractable = _level.get_final_bay()
	final_bay.reset_empty()
	final_bay.start_store_core(false)
	final_bay.finish_store()
	_check(_level.can_exit_now(), "final store opens the exit gate")
	_player.global_position = Vector2(1540, 320)
	_player.velocity = Vector2.ZERO
	await _physics(4)
	await _tap(&"interact")
	await _physics(24)
	_check(not final_bay.is_locked(), "E takes the final core back out")
	_check(not _level.can_exit_now(), "taking the final core out closes the exit gate")
	_check(not _level.is_completed(), "final takeout never completes the level")

	# Gate rule: being at the exit before the final bay locks must not complete;
	# a later final lock while the player is already inside still opens it.
	_player.global_position = Vector2(1680, 320)
	await _physics(6)
	_check(not _level.is_completed(), "exit first with an unlocked final bay does not complete")
	final_bay.start_store_core(false)
	final_bay.finish_store()
	await _physics(6)
	_check(_level.is_completed(), "final lock while already at the exit completes on the normal gate check")


func _test_r_during_pulse() -> void:
	await _new_level()
	# Setup only: arm a real record/pulse directly, then R before it lands.
	_level.get_linked_bay().reset_empty()
	_level.get_linked_bay().start_store_core(false)
	_level.get_linked_bay().finish_store()
	await _physics(4)
	_check(_level.get_link().has_pending_pulse(), "pulse is in flight before R")
	_level.get_hud().replay_requested.emit()
	await _physics(120)
	_check(_level.get_stable_stage() == 0, "R clears stable progress")
	_check(_level.get_bays()[0].is_locked(), "R returns the core to the start bay")
	_check(not _level.get_rune_field().is_activated(), "R clears the rune even after a pending pulse")
	_check(not _level.get_link().has_record(), "R clears the record")
	_check(not _level.is_completed(), "R leaves the level incomplete")
	_check(_player.global_position.is_equal_approx(Vector2(36, 320)), "R returns the player to spawn")


func _test_gate_requires_link() -> void:
	# Fresh R state: no linked record and an inactive rune. A final bay that is
	# locked by setup must not open the exit contract.
	var final_bay: StarCoreBayInteractable = _level.get_final_bay()
	final_bay.reset_empty()
	final_bay.start_store_core(false)
	final_bay.finish_store()
	_check(final_bay.is_locked(), "gate setup has a locked final bay")
	_check(not _level.get_link().has_record(), "gate setup has no linked record")
	_check(not _level.get_rune_field().is_activated(), "gate setup rune is not activated")
	_player.global_position = Vector2(1680, 320)
	_player.velocity = Vector2.ZERO
	await _physics(10)
	_check(not _level.is_exit_gate_ready(), "final lock alone is not an open gate")
	_check(not _level.can_exit_now(), "can_exit_now requires the linked learning state")
	_check(not _level.is_completed(), "final lock without link/rune cannot complete")


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("CHECKPOINT FAIL: " + text)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _tap_key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/level02_rebuild_checkpoint.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
