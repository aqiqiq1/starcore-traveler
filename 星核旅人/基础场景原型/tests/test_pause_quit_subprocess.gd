extends Node

## Independent subprocess check: open the real pause page in Level 02 and click
## the real 退出游戏 button with a mouse event.  The pause button calls
## SceneTree.quit(0), so this process must end with exit code 0.
##
## Run with the GUI executable (not --headless) so the click is routed through
## the actual GUI Control tree:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/test_pause_quit_subprocess.tscn

const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const TEMP_AUDIO: String = "user://test_pause_quit_audio.cfg"
const TEMP_DISPLAY: String = "user://test_pause_quit_display.cfg"

var _level: Level02 = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	print("QUIT_TEST_READY")
	_level = LEVEL02_SCENE.instantiate() as Level02
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(8)
	await get_tree().process_frame

	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	await get_tree().process_frame
	await get_tree().process_frame

	var pause_menu: Node = _level.get_pause_menu()
	if pause_menu == null or not bool(pause_menu.call("is_open")):
		print("QUIT_TEST_FAIL: pause page did not open")
		_cleanup()
		get_tree().quit(3)
		return

	var quit_button: Control = pause_menu.call("get_quit_button") as Control
	if quit_button == null:
		print("QUIT_TEST_FAIL: quit button missing")
		_cleanup()
		get_tree().quit(4)
		return
	var center: Vector2 = quit_button.get_global_rect().get_center()
	_mouse_button(center, true)
	await get_tree().process_frame
	_mouse_button(center, false)
	await get_tree().process_frame

	# The button handler calls SceneTree.quit(0) directly.  If we get here, the
	# click did not reach the real control; fail the subprocess instead of
	# hanging.
	print("QUIT_TEST_FAIL: click did not quit the process")
	_cleanup()
	get_tree().quit(5)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _cleanup() -> void:
	get_tree().paused = false
	var global_audio: String = ProjectSettings.globalize_path(TEMP_AUDIO)
	if FileAccess.file_exists(global_audio):
		DirAccess.remove_absolute(global_audio)
	var global_display: String = ProjectSettings.globalize_path(TEMP_DISPLAY)
	if FileAccess.file_exists(global_display):
		DirAccess.remove_absolute(global_display)


func _physics(frames: int) -> void:
	for _i: int in range(frames):
		await get_tree().physics_frame
