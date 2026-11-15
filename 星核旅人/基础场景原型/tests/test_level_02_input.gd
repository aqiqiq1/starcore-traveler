extends Node

## Focused input regression for the rebuilt L2: real InputEventKey goes through
## the level's raw forwarding (left Shift location, same-direction double tap),
## plus pause/focus cancellation, the F stele smoke and R-after-completion.
## Run:
##   Godot --headless --path . res://tests/test_level_02_input.tscn

const L2: PackedScene = preload("res://scenes/level_02.tscn")
var _level: Level02
var _player: PrototypePlayer
var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = L2.instantiate() as Level02
	add_child(_level)
	await _frames(10)
	_player = _level.get_player()
	await _test_stele_smoke()
	await _test_walk_run_shift()
	await _test_double_tap()
	await _test_pause_focus_clear()
	await _test_r_after_completion_moves()
	_write_log()
	print("LEVEL02_INPUT_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _test_stele_smoke() -> void:
	# Historical input test; L2 now uses GuideEcho. Dynamic access only.
	var stele = _level.get_start_stele()
	_check(stele != null and stele.get_page_count() == 4, "L2 StartStele has four short pages")
	_check(stele != null and not stele.auto_open_on_focus, "L2 stele is F-only (no auto page)")
	_player.global_position = Vector2(60, 320)
	_player.velocity = Vector2.ZERO
	await _physics(6)
	_check(stele.is_prompt_visible(), "near stele shows the F reading prompt")
	_check(stele.get_page_index() == -1, "approaching does not auto-open a page")
	await _tap_key(KEY_F)
	await _physics(2)
	_check(stele.get_page_index() == 0, "F opens page 1")
	_check(not stele.get_current_page_text().is_empty(), "page 1 has transport text")
	await _tap_key(KEY_ESCAPE)
	await _physics(2)
	_check(get_tree().paused and stele.is_suspended(), "pause suspends the stele")
	await _tap_key(KEY_ESCAPE)
	await _physics(4)
	_check(not get_tree().paused and not stele.is_suspended(), "pause resume unsuspends the stele")
	_check(stele.get_page_index() == -1 and stele.is_prompt_visible(), "resume returns to the F prompt")
	_level.get_hud().replay_requested.emit()
	await _frames(12)
	await _physics(4)
	_check(stele.get_page_index() == -1, "R clears the stele page")
	_check(_player.global_position.distance_to(Vector2(36, 320)) < 2.0, "R returns to spawn")


func _test_walk_run_shift() -> void:
	await _reset_player()
	await _key(KEY_D, true)
	await _physics(20)
	_check(absf(_player.get_target_speed() - 100.0) < 0.1, "D walks at 100")
	_check(_player.velocity.x > 80.0, "walk produces real movement")
	await _key(KEY_D, false)
	await _physics(4)

	await _reset_player()
	_player.global_position = Vector2(200, 320)
	await _physics(2)
	await _key(KEY_A, true)
	await _physics(20)
	_check(absf(_player.get_target_speed() + 100.0) < 0.1, "A walks at 100")
	_check(_player.velocity.x < -80.0, "A produces real left movement")
	await _key(KEY_A, false)
	await _physics(4)

	await _reset_player()
	await _key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _key(KEY_D, true)
	await _physics(20)
	_check(absf(_player.get_target_speed() - 160.0) < 0.1, "left Shift+D targets 160")
	_check(_player.is_sprint_intent(), "left Shift sets sprint intent")
	await _key(KEY_D, false)
	await _key(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await _physics(4)

	await _reset_player()
	await _key(KEY_SHIFT, true, KEY_LOCATION_RIGHT)
	await _key(KEY_D, true)
	await _physics(20)
	_check(absf(_player.get_target_speed() - 100.0) < 0.1, "right Shift does not run")
	_check(not _player.is_sprint_intent(), "right Shift leaves sprint off")
	await _key(KEY_D, false)
	await _key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)
	await _physics(4)


func _test_double_tap() -> void:
	await _reset_player()
	await _key(KEY_D, true)
	await _physics(2)
	await _key(KEY_D, false)
	await _physics(2)
	await _key(KEY_D, true)
	await _physics(4)
	_check(_player.is_double_tap_run_locked(), "same-direction double tap locks run")
	_check(absf(_player.get_target_speed() - 160.0) < 0.1, "double tap targets 160")
	await _key(KEY_D, false)
	await _physics(4)


func _test_pause_focus_clear() -> void:
	await _reset_player()
	await _key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _key(KEY_D, true)
	await _physics(10)
	_check(_player.is_sprint_intent(), "run latch is active before pause")
	await _tap_key(KEY_ESCAPE)
	await _physics(2)
	_check(get_tree().paused, "Esc paused the level")
	await _tap_key(KEY_ESCAPE)
	await _physics(4)
	_check(not _player.is_sprint_intent(), "pause/resume clears the Shift latch")
	await _key(KEY_D, false)
	await _key(KEY_SHIFT, false, KEY_LOCATION_LEFT)

	await _reset_player()
	await _key(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await _key(KEY_D, true)
	await _physics(10)
	_check(_player.is_sprint_intent(), "run latch is active before focus loss")
	_level.call("_on_window_focus_exited")
	await _physics(4)
	_check(not _player.is_sprint_intent(), "focus loss clears the Shift latch")
	_check(not _player.is_double_tap_run_locked(), "focus loss clears double-tap lock")
	await _key(KEY_D, false)
	await _key(KEY_SHIFT, false, KEY_LOCATION_LEFT)


func _test_r_after_completion_moves() -> void:
	# Independent completion setup, not a claim of a full route.
	_level.debug_restore_stage(2, false)
	await _physics(4)
	var final_bay: StarCoreBayInteractable = _level.get_final_bay()
	final_bay.reset_empty()
	final_bay.start_store_core(false)
	final_bay.finish_store()
	_player.global_position = Vector2(1680, 320)
	_player.velocity = Vector2.ZERO
	await _physics(8)
	_check(_level.is_completed(), "completion setup reaches the result page")
	_level.get_hud().replay_requested.emit()
	await _frames(12)
	await _physics(4)
	_check(not _level.is_completed(), "R closes the result page")
	await _key(KEY_D, true)
	await _physics(20)
	_check(absf(_player.get_target_speed() - 100.0) < 0.1, "R after completion restores normal walking")
	_check(_player.velocity.x > 80.0, "R after completion really moves")
	await _key(KEY_D, false)
	await _physics(4)


func _reset_player() -> void:
	for action: StringName in [&"move_left", &"move_right", &"jump", &"polarity", &"interact"]:
		Input.action_release(action)
	_player.reset_movement_input_state()
	_player.clear_input_buffers()
	_player.global_position = Vector2(36, 320)
	_player.velocity = Vector2.ZERO
	await _physics(3)


func _key(key: Key, pressed: bool, location: int = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _tap_key(key: Key) -> void:
	await _key(key, true)
	await _key(key, false)
	await _physics(2)


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("INPUT FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/level02_rebuild_input.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
