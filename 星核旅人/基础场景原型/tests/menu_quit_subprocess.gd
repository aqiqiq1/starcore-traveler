extends Node

## Isolated process-exit probe for the start-menu 退出游戏 entry.
##
## The runner launches this as its own Godot process.  The menu is driven by
## real mouse or keyboard input; the script never calls the quit handler or
## SceneTree.quit() on the success path.  It writes a ready marker file before
## input so the runner can distinguish "input sent" from "process exited", and
## a watchdog self-quits with a non-zero code if the accepted quit never
## happens.
##
## Usage (runner passes the absolute marker paths):
##   Godot ... --headless --path . res://tests/menu_quit_subprocess.tscn -- \
##       --mode=mouse --ready=<file> --failure=<file>

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const TEMP_AUDIO_PATH: String = "user://menu_quit_probe_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://menu_quit_probe_display.cfg"
const WATCHDOG_SECONDS: float = 12.0

var _level: Level01
var _menu: StartMenu
var _mode: String = "mouse"
var _ready_path: String = ""
var _failure_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	if _mode != "mouse" and _mode != "keyboard":
		_fail(2, "unknown mode %s" % _mode)
		return
	await get_tree().process_frame
	_remove_temp_audio()
	_remove_temp_display()
	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	for _i: int in range(6):
		await get_tree().physics_frame
	for _i: int in range(3):
		await get_tree().process_frame
	_menu = _level.get_menu()
	if _menu == null or _menu.get_phase_name() != "menu":
		_fail(3, "start menu did not reach the menu phase")
		return
	if _menu.get_quit_button() == null or _menu.get_quit_button().disabled:
		_fail(3, "quit entry is missing or disabled at menu start")
		return

	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if _mode == "keyboard" and focus_owner != _menu.get_start_button():
		_fail(3, "keyboard probe starts without focus on start: %s" % str(focus_owner))
		return
	var ready_text: String = (
		"READY mode=%s pid=%d phase=%s quit_enabled=%s focus=%s quit_rect=%s"
		% [
			_mode, OS.get_process_id(), _menu.get_phase_name(),
			str(not _menu.get_quit_button().disabled), str(focus_owner),
			str(_menu.get_quit_button().get_global_rect()),
		]
	)
	_write_marker(_ready_path, ready_text)
	print("MENU_QUIT_READY %s" % ready_text)

	_watchdog()
	if _mode == "mouse":
		await _activate_mouse()
	else:
		await _activate_keyboard()

	# The accepted quit is expected to end the process.  If execution resumes,
	# the watchdog still cleans up with a non-zero exit code.
	for _i: int in range(120):
		await get_tree().process_frame


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr("--mode=".length())
		elif arg.begins_with("--ready="):
			_ready_path = arg.substr("--ready=".length())
		elif arg.begins_with("--failure="):
			_failure_path = arg.substr("--failure=".length())


func _watchdog() -> void:
	await get_tree().create_timer(WATCHDOG_SECONDS).timeout
	if is_inside_tree():
		_fail(4, "watchdog fired: accepted %s quit did not end the process" % _mode)


func _activate_mouse() -> void:
	var centre: Vector2 = _menu.get_quit_button().get_global_rect().get_center()
	_mouse_move(centre)
	await get_tree().process_frame
	_mouse_button(centre, true)
	await get_tree().process_frame
	_mouse_button(centre, false)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_menu) and not _menu.is_quit_locked():
		_fail(6, "mouse press/release did not activate the quit handler")


func _activate_keyboard() -> void:
	# Initial focus is 开始游戏.  Down reaches 设置, then 退出游戏; Enter accepts.
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_DOWN)
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != _menu.get_quit_button():
		_fail(5, "keyboard focus did not reach quit: %s" % str(owner))
		return
	await _tap_key(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_menu) and not _menu.is_quit_locked():
		_fail(7, "Enter on the focused quit entry did not activate the handler")


func _fail(code: int, message: String) -> void:
	_write_marker(_failure_path, "FAIL %s" % message)
	print("MENU_QUIT_FAIL %s" % message)
	get_tree().quit(code)


func _write_marker(path: String, text: String) -> void:
	if path.is_empty():
		return
	var folder: String = path.get_base_dir()
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("menu quit probe: could not write marker %s" % path)
		return
	file.store_string(text)
	file.close()


func _mouse_move(pos: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event, true)


func _tap_key(code: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var release: InputEventKey = InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _remove_temp_audio() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_AUDIO_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _remove_temp_display() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_DISPLAY_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)
