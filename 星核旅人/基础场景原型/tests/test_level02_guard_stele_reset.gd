extends Node

## Focused regression for one integration leak:
## completion suspends the stele for F safety, and a real R restart must undo
## that suspension through the shared Level02._reset_room_state path.
##
## Run only this test:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##       res://tests/test_level02_guard_stele_reset.tscn
##
## Setup is explicit: the target bay is locked through its own public bay API
## so the completion page can be reached immediately. Everything after that is
## the real Level02 completion gate, a real R key, real walking and a real F key.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const LOG_PATH: String = "res://tests/logs/level02_guard_stele_reset_test.log"

var _level: Level02
var _player: PrototypePlayer
# Historical TutorialStele-focused suite; L2 now uses GuideEcho. Dynamic type
# keeps this archival script parseable without claiming current runtime coverage.
var _stele
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_log("=== Level 02 guard/stele reset focused regression ===")
	_log("Godot %s  display=%s" % [
		Engine.get_version_info()["string"], DisplayServer.get_name()
	])

	_level = LEVEL_SCENE.instantiate() as Level02
	add_child(_level)
	await _step(4)
	_player = _level.get_player()
	_stele = _level.get_start_stele()

	# SETUP ONLY (logged): lock the target bay directly through its public
	# store API so the exit gate can complete without replaying transport.
	var target = _level.get_target_bay()
	_check(target.start_store_core(true), "setup: target bay accepts a store")
	target.finish_store()
	_check(target.is_locked(), "setup: target bay is locked",
		str(target.is_locked()))
	_player.global_position = Vector2(600.0, 320.0)
	_player.velocity = Vector2.ZERO
	for _i: int in range(12):
		await get_tree().physics_frame
		if _level.is_completed():
			break
	_check(_level.is_completed(),
		"completion gate reaches the real result state",
		"completed=%s" % str(_level.is_completed()))
	_check(_stele.is_suspended(),
		"completion suspends the stele for F safety",
		"suspended=%s" % str(_stele.is_suspended()))
	_check(_stele.get_page_index() == -1 and not _stele.is_prompt_visible(),
		"completion closes the stele prompt",
		"page=%d visible=%s" % [
			_stele.get_page_index(), str(_stele.is_prompt_visible())
		])

	# F on the completion page must not page the suspended stele.
	await _tap_key(KEY_F)
	_check(_stele.get_page_index() == -1 and not _stele.is_prompt_visible(),
		"real F cannot page the stele behind the completion page",
		"page=%d visible=%s" % [
			_stele.get_page_index(), str(_stele.is_prompt_visible())
		])

	# Real R restart must clear the suspension through _reset_room_state.
	await _tap_key(KEY_R)
	await _step(6)
	_check(not _level.is_completed(), "real R leaves the completion state")
	_check(not _stele.is_suspended(),
		"real R clears the completion stele suspension",
		"suspended=%s" % str(_stele.is_suspended()))
	_check(_player.global_position == _level.get_spawn_position(),
		"real R returns the player to spawn", str(_player.global_position))

	# Walk back to x=80 with real input; proximity should open page 1.
	Input.action_press(&"move_right")
	for _i: int in range(120):
		await get_tree().physics_frame
		if _player.global_position.x >= 80.0:
			break
	Input.action_release(&"move_right")
	await _step(6)
	_check(_stele.is_focused(),
		"walking to x=80 focuses the start stele",
		"player=%s" % str(_player.global_position))
	_check(_stele.get_page_index() == 0 and _stele.is_prompt_visible(),
		"the stele opens page 1 after the reset",
		"page=%d visible=%s" % [
			_stele.get_page_index(), str(_stele.is_prompt_visible())
		])

	# A real F press must advance exactly one page.
	var page_before: int = _stele.get_page_index()
	await _tap_key(KEY_F)
	await _step(2)
	_check(_stele.get_page_index() == page_before + 1,
		"real F advances the restored stele page",
		"%d -> %d" % [page_before, _stele.get_page_index()])
	_check(_stele.is_prompt_visible(),
		"the restored stele prompt remains visible while reading")

	_finish()


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame
	await get_tree().physics_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _check(condition: bool, label: String, details: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
	else:
		_fail_count += 1
		_log("[FAIL] %s%s" % [label, ("  (" + details + ")") if details != "" else ""])
		printerr("[FAIL] %s %s" % [label, details])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	if get_tree().paused:
		get_tree().paused = false
	var summary: String = "TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count]
	_log("")
	_log(summary)
	_log("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	get_tree().quit(0 if _fail_count == 0 else 1)
