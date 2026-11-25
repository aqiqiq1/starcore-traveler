extends Node

## Missing-DLC branch test.
##
## Run with rift_workshop.tscn temporarily renamed (see tests/run_missing_entry.ps1):
##   ... --headless --path . res://dlc/rift_workshop/tests/title_missing_test.tscn
##
## Asserts that hiding the entry does not disturb the base menu: the button
## exists but is invisible and disabled, the focus ring falls back to
## quit -> trial -> start (or the original three-row ring), and the start row
## still works.

const LEVEL_01: String = "res://scenes/level_01.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	await _cleanup()
	print("RIFT_TITLE_MISSING_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(4)


func _run() -> void:
	await _wait_process(2)
	_check(not ResourceLoader.exists(RIFT), "rift scene file is absent for this run")
	_check(not StartMenu.is_rift_entry_available(),
		"availability helper reports the entry as missing")
	var packed: PackedScene = load(LEVEL_01) as PackedScene
	_check(packed != null, "level_01 loads with the DLC scene absent")
	if packed == null:
		return
	var level: Node = packed.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(4)
	await _wait_physics(4)
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	_check(menu != null and menu.is_menu_open(), "title menu is open")
	if menu == null:
		return
	var rift_button: PixelMenuButton = menu.get_rift_button()
	_check(rift_button != null, "hidden entry still exists as a node")
	if rift_button == null:
		return
	_check(not rift_button.visible, "missing DLC hides the 裂隙工坊 button")
	_check(rift_button.disabled, "missing DLC leaves the button disabled")
	_check(rift_button.focus_mode == Control.FOCUS_NONE,
		"hidden button cannot take focus", str(rift_button.focus_mode))

	# Focus ring skips the hidden entry.
	var start_button: Button = menu.get_start_button()
	var settings_button: Button = menu.get_settings_button()
	var quit_button: Button = menu.get_quit_button()
	var trial_button: PixelMenuButton = menu.get_trial_button()
	_check(start_button.get_node(start_button.focus_next) == settings_button,
		"start focus_next is still settings")
	_check(settings_button.get_node(settings_button.focus_next) == quit_button,
		"settings focus_next is still quit")
	if trial_button != null and trial_button.visible:
		_check(quit_button.get_node(quit_button.focus_next) == trial_button,
			"quit focus_next still reaches the trial button")
		_check(trial_button.get_node(trial_button.focus_next) == start_button,
			"trial focus_next loops back to start, skipping the hidden entry")
	else:
		_check(quit_button.get_node(quit_button.focus_next) == start_button,
			"quit focus_next loops to start")

	# The base opening row itself is exercised by title_test.tscn with the DLC
	# present; here it only has to remain enabled and focusable while the entry
	# is hidden (pressing it would start the 2.2 s title tween and the test
	# would quit mid-tween, which leaks the tween at process exit).
	_check(start_button.visible and not start_button.disabled,
		"existing 开始游戏 row stays visible and enabled")
	start_button.grab_focus()
	await _wait_process(3)
	_check(start_button.has_focus(), "existing start row still takes focus")
	await _wait_process(3)
