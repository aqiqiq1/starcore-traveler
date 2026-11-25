extends Node

## Title-menu entry test.  Verifies the new 试炼场 button is reachable by both
## keyboard focus + Enter and a real mouse click, and that either path loads
## res://dlc/trial_chambers/trial_chambers.tscn through the production handler.
##
##   ... --headless --path . res://dlc/trial_chambers/tests/title_test.tscn

const LEVEL_01: String = "res://scenes/level_01.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	await _cleanup()
	print("TRIAL_TITLE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _push_click(position: Vector2) -> void:
	# in_local_coords=true: position is in the 640x360 viewport space, not the
	# (possibly 2x) OS window space.
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	get_viewport().push_input(down, true)
	await _wait_process(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	get_viewport().push_input(up, true)


func _load_level_01() -> Node:
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	if packed == null:
		return null
	var level: Node = packed.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	await _wait_physics(4)
	return level


func _wait_for_scene(path: String, max_frames: int) -> bool:
	for _index: int in range(max_frames):
		var current: Node = get_tree().current_scene
		if current != null and current.scene_file_path == path:
			return true
		await get_tree().process_frame
	return false


func _drop_current_scene() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		await _wait_process(4)


func _cleanup() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	await _drop_current_scene()
	await _wait_process(2)


func _run() -> void:
	# Let the Engine finish setting up this test scene's own children before a
	# sibling level_01 is added to the root.
	await _wait_process(2)
	# --- keyboard path ----------------------------------------------------
	var level: Node = await _load_level_01()
	_check(level != null, "level_01 loads for keyboard test")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	var trial_button: PixelMenuButton = menu.get_trial_button()
	_check(trial_button != null, "menu exposes the 试炼场 button")
	if trial_button == null:
		return
	_check(trial_button.text == "试炼场", "button text is 试炼场", trial_button.text)
	_check(trial_button.variant == PixelMenuButton.Variant.STONE,
		"button uses STONE variant", str(trial_button.variant))
	_check(trial_button.get_size() == Vector2(112.0, 20.0),
		"button is 112x20", str(trial_button.get_size()))
	var rect: Rect2 = trial_button.get_global_rect()
	_check(rect.position.y > 232.0, "button sits below the Quit row",
		"y=%.1f" % rect.position.y)
	_check(Rect2(Vector2.ZERO, Vector2(640.0, 360.0)).encloses(rect),
		"button lies inside the 640x360 menu", str(rect))
	_check(trial_button.focus_mode == Control.FOCUS_ALL, "button is keyboard focusable")
	_check(trial_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"button accepts mouse input")

	# Focus chain: start -> settings -> quit -> trial -> rift -> start
	# (rift is skipped when its DLC folder is absent).
	var start_button: Button = menu.get_start_button()
	var settings_button: Button = menu.get_settings_button()
	var quit_button: Button = menu.get_quit_button()
	var rift_button: PixelMenuButton = menu.get_rift_button()
	_check(start_button.get_node(start_button.focus_next) == settings_button,
		"start focus_next is settings")
	_check(settings_button.get_node(settings_button.focus_next) == quit_button,
		"settings focus_next is quit")
	_check(quit_button.get_node(quit_button.focus_next) == trial_button,
		"quit focus_next reaches the trial button")
	var trial_next: Control = start_button
	if rift_button != null and rift_button.visible:
		trial_next = rift_button
	_check(trial_button.get_node(trial_button.focus_next) == trial_next,
		"trial focus_next reaches the next visible entry")
	_check(trial_button.get_node(trial_button.focus_previous) == quit_button,
		"trial focus_previous is quit")
	_check(quit_button.focus_neighbor_bottom != NodePath()
		and quit_button.get_node(quit_button.focus_neighbor_bottom) == trial_button,
		"Down from quit reaches the trial button")

	trial_button.grab_focus()
	await _wait_process(3)
	_check(trial_button.has_focus(), "trial button can take keyboard focus")
	_push_key(KEY_ENTER, true)
	await _wait_physics(1)
	_push_key(KEY_ENTER, false)
	var keyboard_ok: bool = await _wait_for_scene(TRIAL, 120)
	_check(keyboard_ok, "Enter on the focused trial button opens the trial scene",
		"current=%s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "null"))
	await _drop_current_scene()

	# --- mouse path -------------------------------------------------------
	var level2: Node = await _load_level_01()
	_check(level2 != null, "level_01 loads again for mouse test")
	if level2 == null:
		return
	var menu2: StartMenu = level2.get_node_or_null("StartMenu") as StartMenu
	_check(menu2 != null and menu2.is_menu_open(), "title menu reopens")
	if menu2 == null:
		return
	var trial_button2: PixelMenuButton = menu2.get_trial_button()
	await _push_click(trial_button2.get_global_rect().get_center())
	var mouse_ok: bool = await _wait_for_scene(TRIAL, 120)
	_check(mouse_ok, "mouse click on 试炼场 opens the trial scene",
		"current=%s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "null"))
	await _drop_current_scene()

	# --- existing rows still work ----------------------------------------
	var level3: Node = await _load_level_01()
	var menu3: StartMenu = level3.get_node_or_null("StartMenu") as StartMenu
	if menu3 != null:
		var start_button3: Button = menu3.get_start_button()
		start_button3.grab_focus()
		await _wait_process(2)
		_push_key(KEY_ENTER, true)
		await _wait_physics(1)
		_push_key(KEY_ENTER, false)
		await _wait_process(4)
		_check(menu3.get_start_request_count() == 1,
			"existing 开始游戏 row still triggers the opening")
		_check(menu3.get_phase_name() != "menu",
			"start no longer leaves the menu idle", menu3.get_phase_name())
	await _drop_current_scene()

	var level4: Node = await _load_level_01()
	var menu4: StartMenu = level4.get_node_or_null("StartMenu") as StartMenu
	if menu4 != null:
		var settings4: Button = menu4.get_settings_button()
		await _push_click(settings4.get_global_rect().get_center())
		await _wait_process(4)
		_check(menu4.is_settings_open(), "existing 设置 row still opens settings")
		_push_key(KEY_ESCAPE, true)
		await _wait_physics(1)
		_push_key(KEY_ESCAPE, false)
		await _wait_process(4)
		_check(not menu4.is_settings_open(), "Esc still closes settings")
