extends Node

## Small formal-flow check with actual completion-page buttons:
## setup L1 completion -> press its primary button -> real Level02;
## setup L2 completion -> press "返回主界面" -> real Level01 title.
## These are independent completion-page setups, not claims of a full playthrough.
## Run:
##   Godot --headless --path . res://tests/test_level_flow_rebuild.tscn

const L1: PackedScene = preload("res://scenes/level_01.tscn")
var _pass: int = 0
var _fail: int = 0
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var l1: Level01 = L1.instantiate() as Level01
	l1.enable_start_menu = false
	l1.set("intro_max_duration", 0.05)
	add_child(l1)
	await _frames(20)
	l1.call("_on_exit_reached")
	_check(l1.is_completed(), "L1 completion handler runs")
	var l1_primary: PixelMenuButton = l1.get_hud().get_completion_primary_button()
	_check(l1_primary != null and l1_primary.text == "进入第二关", "L1 completion primary is 进入第二关")
	await _frames(3)
	l1_primary.grab_focus()
	await _frames(2)
	get_tree().current_scene = null
	await _tap_enter()
	l1.queue_free()
	var level02: Node = await _wait_scene("Level02", 150)
	_check(level02 is Level02, "actual L1 completion button enters the real Level02 scene")
	if level02 is Level02:
		var l2: Level02 = level02 as Level02
		for _i: int in range(90):
			await get_tree().physics_frame
			if l2.get_player().global_position.y >= 319.5:
				break
		print("FLOW L2 PLAYER ", l2.get_player().global_position)
		_check(l2.get_player().global_position.distance_to(Vector2(36, 320)) < 2.0, "Level02 spawn is intact")
		_check(not get_tree().paused, "Level02 starts unpaused")

		# Independent completion setup, not the route test.
		l2.debug_restore_stage(2, false)
		await _frames(4)
		var final_bay: StarCoreBayInteractable = l2.get_final_bay()
		final_bay.reset_empty()
		final_bay.start_store_core(false)
		final_bay.finish_store()
		l2.get_player().global_position = Vector2(1680, 320)
		l2.get_player().velocity = Vector2.ZERO
		await _frames(12)
		_check(l2.is_completed(), "L2 completion setup shows the result page")
		var l2_primary: PixelMenuButton = l2.get_hud().get_completion_primary_button()
		_check(l2_primary != null and l2_primary.text == "返回主界面", "L2 completion primary is 返回主界面")
		await _frames(3)
		l2_primary.grab_focus()
		await _frames(2)
		get_tree().current_scene = null
		await _tap_enter()
		l2.queue_free()
		var level01: Node = await _wait_scene("Level01", 150)
		_check(level01 is Level01, "actual L2 completion button returns to the real Level01 title")
		if level01 is Level01:
			var l1b: Level01 = level01 as Level01
			_check(l1b.get_menu() != null and l1b.get_menu().is_menu_open(), "returned title menu is open")
			_check(not get_tree().paused, "returned title is unpaused")
	_write_log()
	print("LEVEL_FLOW_REBUILD_TEST pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _tap_enter() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_ENTER
	down.keycode = KEY_ENTER
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_ENTER
	up.keycode = KEY_ENTER
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame


func _wait_scene(prefix: String, max_frames: int) -> Node:
	for _i: int in range(max_frames):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current.name.begins_with(prefix):
			await _frames(4)
			return current
	return get_tree().current_scene


func _check(ok: bool, text: String) -> void:
	if ok:
		_pass += 1
		_lines.append("PASS " + text)
	else:
		_fail += 1
		_lines.append("FAIL " + text)
		push_error("FLOW CHECK FAIL: " + text)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _write_log() -> void:
	var file: FileAccess = FileAccess.open("res://tests/logs/level_flow_rebuild.log", FileAccess.WRITE)
	if file == null:
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
