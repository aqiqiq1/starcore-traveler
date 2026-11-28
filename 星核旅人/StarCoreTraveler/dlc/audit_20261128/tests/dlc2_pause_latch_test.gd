extends Node

## Focused DLC2 assertion for the post-skip pause latch.
##
## DLC3 is covered by GLOBAL_AUDIT_TEST; this keeps the same input path honest
## for 裂隙工坊 without changing the shared 67-check count.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://dlc/audit_20261128/tests/dlc2_pause_latch_test.tscn

const RIFT_PATH: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const PROGRESS: String = "user://dlc2_pause_latch_audit.cfg"

var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_remove_progress()
	await _run()
	await _cleanup()
	print("DLC2_PAUSE_LATCH_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	var line: String = label + ("" if detail.is_empty() else " [" + detail + "]")
	if condition:
		print("PASS: " + line)
		return
	_failures.append(line)
	print("FAIL: " + line)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _tap_key(code: int) -> void:
	_push_key(code, true)
	await _wait_physics(1)
	_push_key(code, false)
	await _wait_process(2)


func _remove_progress() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))


func _run() -> void:
	var packed: PackedScene = load(RIFT_PATH) as PackedScene
	_check(packed != null, "rift scene loads")
	if packed == null:
		return
	var rift: Node = packed.instantiate()
	rift.set("show_intro_cinematic", true)
	rift.set("show_intro_guide", false)
	rift.set("chapter_progress_path", PROGRESS)
	get_tree().root.add_child(rift)
	get_tree().current_scene = rift
	await _wait_process(5)
	await _wait_physics(2)

	_check(bool(rift.call("is_intro_active")), "rift intro starts")
	var cinematic: Node = rift.call("get_intro_cinematic")
	_check(cinematic != null, "rift exposes its opening cinematic")
	if cinematic == null:
		return

	_push_key(KEY_SPACE, true)
	await _wait_seconds(0.75)
	_check(bool(cinematic.call("is_skipped")), "long Space skips the rift film")
	_check(bool(cinematic.call("is_awaiting_release")),
		"rift keeps the held Space latch until release")

	await _tap_key(KEY_ESCAPE)
	await _wait_process(5)
	var paused: bool = bool(rift.call("is_pause_open"))
	var latch_cleared: bool = not bool(cinematic.call("is_awaiting_release"))
	var handoff_done: bool = not bool(rift.call("is_intro_active"))
	_check(paused and latch_cleared and handoff_done,
		"Esc opens the rift pause page and clears the Space latch",
		"paused=%s latch_cleared=%s handoff=%s" % [
			str(paused), str(latch_cleared), str(handoff_done)
		])

	var player: Node = rift.call("get_player")
	var toggles_before: int = int(player.call("get_polarity_toggle_count"))
	Input.action_press(&"jump")
	Input.action_press(&"polarity")
	_push_key(KEY_SPACE, false)
	await _tap_key(KEY_ESCAPE)
	await _wait_physics(5)
	_check(not bool(rift.call("is_pause_open")), "rift pause closes on the second Esc")
	_check(not bool(rift.call("is_intro_active")),
		"rift control returns after the paused skip hand-off")
	_check(not get_tree().paused, "rift tree is unpaused after the hand-off")
	_check((player.call("get_state_name") as String) != "jump",
		"held jump at the rift paused hand-off did not start a jump",
		player.call("get_state_name") as String)
	_check(int(player.call("get_polarity_toggle_count")) == toggles_before,
		"held polarity at the rift paused hand-off did not toggle")
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	await _wait_process(4)


func _cleanup() -> void:
	Input.action_release(&"jump")
	Input.action_release(&"polarity")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	get_tree().paused = false
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null:
		current.queue_free()
		await _wait_process(6)
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	_remove_progress()
	await _wait_process(16)
