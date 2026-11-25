extends Node

## Title-menu entry test for 星核织机 (scene present).
##
##   ... --headless --path . res://dlc/star_loom/tests/title_test.tscn
##
## Verifies the 星核织机 button's size / style / position, the 6-item focus ring
## (start -> settings -> quit -> trial -> rift -> loom -> start), keyboard and
## mouse activation, and that the three original rows still work.  The
## missing-scene branch is covered by title_missing_test.tscn, run with
## star_loom.tscn temporarily renamed.

const LEVEL_01: String = "res://scenes/level_01.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	await _cleanup()
	print("STAR_LOOM_TITLE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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
		await _wait_process(8)


func _cleanup() -> void:
	Input.action_release(&"move_right")
	await _drop_current_scene()
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(20)


func _run() -> void:
	await _wait_process(2)
	_check(ResourceLoader.exists(LOOM), "star_loom scene file exists on disk")
	_check(StartMenu.is_loom_entry_available(), "availability helper reports the entry")
	_check(not StartMenu.is_loom_entry_available("res://dlc/star_loom/__missing__.tscn"),
		"availability helper rejects a missing path")

	# --- keyboard path ----------------------------------------------------
	var level: Node = await _load_level_01()
	_check(level != null, "level_01 loads for the keyboard test")
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	var loom_button: PixelMenuButton = menu.get_loom_button()
	var rift_button: PixelMenuButton = menu.get_rift_button()
	_check(loom_button != null, "menu exposes the 星核织机 button")
	if loom_button == null:
		return
	_check(loom_button.visible, "loom entry is visible while the scene exists")
	_check(not loom_button.disabled, "loom entry is enabled while the scene exists")
	_check(loom_button.text == "星核织机", "button text is 星核织机", loom_button.text)
	_check(loom_button.variant == PixelMenuButton.Variant.STONE,
		"button uses STONE variant", str(loom_button.variant))
	_check(loom_button.get_size() == Vector2(112.0, 20.0),
		"button is 112x20", str(loom_button.get_size()))
	var rect: Rect2 = loom_button.get_global_rect()
	_check(rect.position.y > rift_button.get_global_rect().position.y,
		"button sits below the 裂隙工坊 row", "y=%.1f" % rect.position.y)
	_check(absf(rect.position.y - 286.0) < 0.5, "button sits at y=286",
		"y=%.1f" % rect.position.y)
	_check(Rect2(Vector2.ZERO, Vector2(640.0, 360.0)).encloses(rect),
		"button lies inside the 640x360 menu", str(rect))
	_check(loom_button.focus_mode == Control.FOCUS_ALL, "button is keyboard focusable")
	_check(loom_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"button accepts mouse input")

	# Title hierarchy tint: all three DLC rows share the same modulate and stay
	# fully focusable; the base start row is not tinted.
	var trial_row: PixelMenuButton = menu.get_trial_button()
	_check(trial_row.modulate.is_equal_approx(StartMenu.DLC_ROW_MODULATE),
		"trial row uses the shared DLC modulate", str(trial_row.modulate))
	_check(rift_button.modulate.is_equal_approx(StartMenu.DLC_ROW_MODULATE),
		"rift row uses the shared DLC modulate", str(rift_button.modulate))
	_check(loom_button.modulate.is_equal_approx(StartMenu.DLC_ROW_MODULATE),
		"loom row uses the shared DLC modulate", str(loom_button.modulate))
	_check(
		trial_row.focus_mode == Control.FOCUS_ALL
		and rift_button.focus_mode == Control.FOCUS_ALL
		and loom_button.focus_mode == Control.FOCUS_ALL,
		"all three tinted DLC rows remain keyboard focusable"
	)
	_check(not menu.get_start_button().modulate.is_equal_approx(StartMenu.DLC_ROW_MODULATE),
		"the base 开始游戏 row keeps its untinted hierarchy")

	# Focus ring: start -> settings -> quit -> trial -> rift -> loom -> start.
	var start_button: Button = menu.get_start_button()
	var settings_button: Button = menu.get_settings_button()
	var quit_button: Button = menu.get_quit_button()
	var trial_button: PixelMenuButton = menu.get_trial_button()
	_check(start_button.get_node(start_button.focus_next) == settings_button,
		"start focus_next is settings")
	_check(settings_button.get_node(settings_button.focus_next) == quit_button,
		"settings focus_next is quit")
	_check(quit_button.get_node(quit_button.focus_next) == trial_button,
		"quit focus_next reaches the trial button")
	_check(trial_button.get_node(trial_button.focus_next) == rift_button,
		"trial focus_next reaches the rift button")
	_check(rift_button.get_node(rift_button.focus_next) == loom_button,
		"rift focus_next reaches the loom button")
	_check(loom_button.get_node(loom_button.focus_next) == start_button,
		"loom focus_next loops back to start")
	_check(loom_button.get_node(loom_button.focus_previous) == rift_button,
		"loom focus_previous is the rift button")
	_check(quit_button.focus_neighbor_bottom != NodePath()
		and quit_button.get_node(quit_button.focus_neighbor_bottom) == trial_button,
		"Down from quit reaches the trial button")
	_check(trial_button.get_node(trial_button.focus_neighbor_bottom) == rift_button,
		"Down from trial reaches the rift button")
	_check(rift_button.get_node(rift_button.focus_neighbor_bottom) == loom_button,
		"Down from rift reaches the loom button")
	_check(loom_button.get_node(loom_button.focus_neighbor_bottom) == start_button,
		"Down from loom loops to start")
	# Six focusable rows in total: start, settings, quit, trial, rift, loom.
	var ring: Array[Control] = [start_button, settings_button, quit_button,
		trial_button, rift_button, loom_button]
	var ring_ok: bool = true
	for index: int in range(ring.size()):
		var current: Control = ring[index]
		if current.get_node(current.focus_next) != ring[(index + 1) % ring.size()]:
			ring_ok = false
	_check(ring_ok, "the title focus ring has all six entries")

	loom_button.grab_focus()
	await _wait_process(3)
	_check(loom_button.has_focus(), "loom button can take keyboard focus")
	_push_key(KEY_ENTER, true)
	await _wait_physics(1)
	_push_key(KEY_ENTER, false)
	var keyboard_ok: bool = await _wait_for_scene(LOOM, 180)
	_check(keyboard_ok, "Enter on the focused loom button opens the chapter",
		"current=%s" % (
			get_tree().current_scene.scene_file_path
			if get_tree().current_scene != null else "null"
		))
	await _drop_current_scene()

	# --- mouse path -------------------------------------------------------
	var level2: Node = await _load_level_01()
	_check(level2 != null, "level_01 loads again for the mouse test")
	if level2 != null:
		var menu2: StartMenu = level2.get_node_or_null("StartMenu") as StartMenu
		_check(menu2 != null and menu2.is_menu_open(), "title menu reopens")
		if menu2 != null:
			var loom2: PixelMenuButton = menu2.get_loom_button()
			await _push_click(loom2.get_global_rect().get_center())
			var mouse_ok: bool = await _wait_for_scene(LOOM, 180)
			_check(mouse_ok, "mouse click on 星核织机 opens the chapter",
				"current=%s" % (
					get_tree().current_scene.scene_file_path
					if get_tree().current_scene != null else "null"
				))
			await _drop_current_scene()

	# --- original rows still work ----------------------------------------
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
	await _drop_current_scene()
