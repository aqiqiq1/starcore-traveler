extends Node

## Focused check that the pause page's 返回标题 entry really returns to the
## title scene (the 继续 entry is covered in route_test).
##
##   ... --headless --path . res://dlc/trial_chambers/tests/pause_title_test.tscn

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	print("TRIAL_PAUSE_TITLE_TEST checks=%d failures=%d" % [_checks, _failures.size()])
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


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(2)
	_push_key(code, false)
	await _wait_physics(2)


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
	await _wait_process(3)


func _run() -> void:
	var trial: TrialChambers = (load(TRIAL_SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	get_tree().root.add_child(trial)
	get_tree().current_scene = trial
	await _wait_process(3)
	await _wait_physics(6)

	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	_check(trial.is_pause_open(), "Esc opens the pause page")
	var hud: TrialHUD = trial.get_hud()
	_check(hud.get_continue_button().has_focus(), "继续 starts focused")

	# Move focus to 返回标题 and activate it with the real key path.
	await _tap_key(KEY_DOWN)
	await _wait_process(3)
	_check(hud.get_title_button().has_focus(), "Down moves focus to 返回标题")
	await _tap_key(KEY_ENTER)
	var changed: bool = false
	for _index: int in range(120):
		var current: Node = get_tree().current_scene
		if current != null and current != trial:
			changed = true
			break
		await get_tree().process_frame
	await _wait_process(4)
	var current: Node = get_tree().current_scene
	var path: String = current.scene_file_path if current != null else ""
	_check(changed and path == LEVEL_01, "pause 返回标题 returns to level_01.tscn", path)
	_check(not get_tree().paused, "returning clears the tree pause")
