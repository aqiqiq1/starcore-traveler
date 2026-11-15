extends Node

## Minimal real-GUI regression for the Window/DisplayOptions mode-domain bug.
##
## Starts from a confirmed fullscreen config, stages/applies a windowed change,
## then cancels with the mouse, Esc, timeout and scene release.  Every rollback
## must return to real Window.MODE_FULLSCREEN with the confirmed config still
## fullscreen.  A final normal windowed confirm leaves a clean test state.
##
## Run with the GUI executable.  All display/audio paths are temporary and the
## original Window state and Master volume are restored before quitting.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const TEMP_AUDIO_PATH: String = "user://test_display_mode_map_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://test_display_mode_map_display.cfg"

var _level: Level01
var _menu: StartMenu
var _pass_count: int = 0
var _fail_count: int = 0
var _log_lines: Array[String] = []
var _original_master_db: float = 0.0
var _original_master_mute: bool = false
var _original_window_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_original_master_db = AudioServer.get_bus_volume_db(0)
	_original_master_mute = AudioServer.is_bus_mute(0)
	_original_window_state = _capture_window_state()
	_remove_temp_audio()
	_remove_temp_display()
	_log("Star Core Traveler - display mode mapping regression")
	_log("Godot %s  display=%s" % [Engine.get_version_info()["string"], DisplayServer.get_name()])
	if DisplayServer.get_name() == "headless":
		_log("SKIP: this regression requires a real GUI window")
	else:
		await _run_cases()
	await _finish()


func _run_cases() -> void:
	_section("MOUSE CANCEL FROM CONFIRMED FULLSCREEN")
	await _setup_fullscreen()
	var pos_mouse: Vector2i = get_window().position
	await _open_settings()
	await _click_logical(_slider_point(0.37))
	await _settle(3)
	var volume: int = _menu.get_volume_percent()
	var master_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))
	await _apply_windowed_pending()
	_check(_menu.is_display_pending(), "mouse-cancel case reaches pending")
	_check(get_window().mode == Window.MODE_WINDOWED, "mouse-cancel pending is really windowed", str(get_window().mode))
	await _click_logical(_menu.get_pending_cancel_button().get_global_rect().get_center())
	await _settle(5)
	_check(not _menu.is_display_pending(), "mouse cancel clears pending")
	_check(
		get_window().mode == Window.MODE_FULLSCREEN,
		"mouse cancel restores real Window.MODE_FULLSCREEN",
		str(get_window().mode)
	)
	_check(get_window().position == pos_mouse, "mouse cancel restores fullscreen position", "%s -> %s" % [str(pos_mouse), str(get_window().position)])
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "mouse cancel keeps 640x360 viewport", str(get_viewport().get_visible_rect().size))
	_check(_menu.get_display_controller().get_active_mode() == DisplayOptions.Mode.FULLSCREEN, "mouse cancel keeps active mode fullscreen")
	_check(_config_mode() == "fullscreen", "mouse cancel keeps confirmed config fullscreen")
	_check(_menu.get_volume_percent() == volume, "mouse cancel keeps volume", str(_menu.get_volume_percent()))
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")) - master_db) < 0.01, "mouse cancel keeps Master dB")

	_section("ESC CANCEL FROM CONFIRMED FULLSCREEN")
	await _setup_fullscreen()
	var pos_esc: Vector2i = get_window().position
	await _open_settings()
	await _apply_windowed_pending()
	await _tap_key(KEY_ESCAPE)
	await _settle(5)
	_check(not _menu.is_display_pending(), "Esc cancel clears pending")
	_check(get_window().mode == Window.MODE_FULLSCREEN, "Esc cancel restores real fullscreen", str(get_window().mode))
	_check(get_window().position == pos_esc, "Esc cancel restores fullscreen position", "%s -> %s" % [str(pos_esc), str(get_window().position)])
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "Esc cancel keeps 640x360 viewport")
	_check(_menu.get_display_controller().get_active_mode() == DisplayOptions.Mode.FULLSCREEN, "Esc cancel keeps active fullscreen")
	_check(_config_mode() == "fullscreen", "Esc cancel keeps config fullscreen")

	_section("TIMEOUT FROM CONFIRMED FULLSCREEN (TEST SHORT DEADLINE)")
	await _setup_fullscreen()
	var pos_timeout: Vector2i = get_window().position
	var controller: DisplaySettingsController = _menu.get_display_controller()
	_check(is_equal_approx(controller.get_pending_timeout_seconds(), 10.0), "production timeout remains 10 s", "%.1f" % controller.get_pending_timeout_seconds())
	controller.pending_timeout_seconds = 0.6
	_log("TEST OVERRIDE: timeout shortened to 0.6 s for this regression; production remains 10.0 s")
	await _open_settings()
	await _apply_windowed_pending()
	await get_tree().create_timer(1.0).timeout
	await _settle(4)
	_check(not _menu.is_display_pending(), "short-deadline timeout clears pending")
	_check(get_window().mode == Window.MODE_FULLSCREEN, "timeout restores real fullscreen", str(get_window().mode))
	_check(get_window().position == pos_timeout, "timeout restores fullscreen position", "%s -> %s" % [str(pos_timeout), str(get_window().position)])
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "timeout keeps 640x360 viewport")
	_check(_menu.get_display_controller().get_active_mode() == DisplayOptions.Mode.FULLSCREEN, "timeout keeps active fullscreen")
	_check(_config_mode() == "fullscreen", "timeout keeps config fullscreen")
	controller.pending_timeout_seconds = 10.0

	_section("SCENE RELEASE FROM CONFIRMED FULLSCREEN")
	await _setup_fullscreen()
	var pos_release: Vector2i = get_window().position
	await _open_settings()
	await _apply_windowed_pending()
	await _free_level()
	await _settle(4)
	_check(get_window().mode == Window.MODE_FULLSCREEN, "scene release restores real fullscreen", str(get_window().mode))
	_check(get_window().position == pos_release, "scene release restores fullscreen position", "%s -> %s" % [str(pos_release), str(get_window().position)])
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "scene release keeps 640x360 viewport")
	_check(_config_mode() == "fullscreen", "scene release keeps config fullscreen")

	_section("NORMAL WINDOWED CONFIRM FOR CLEANUP")
	await _setup_fullscreen()
	await _open_settings()
	await _click_logical(_menu.get_display_mode_button(false).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)
	_check(get_window().mode == Window.MODE_WINDOWED, "normal confirm really leaves fullscreen", str(get_window().mode))
	await _click_logical(_menu.get_pending_confirm_button().get_global_rect().get_center())
	await _settle(5)
	_check(not _menu.is_display_pending(), "normal confirm clears pending")
	_check(get_window().mode == Window.MODE_WINDOWED, "normal confirm keeps windowed", str(get_window().mode))
	_check(get_window().size == Vector2i(1280, 720), "normal confirm restores 1280x720", str(get_window().size))
	_check(_config_mode() == "windowed" and _config_size() == Vector2i(1280, 720), "normal confirm persists windowed 1280x720")
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "normal confirm keeps 640x360 viewport")


func _setup_fullscreen() -> void:
	await _free_level()
	_write_display_config("fullscreen", Vector2i(1280, 720))
	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _physics(6)
	_menu = _level.get_menu()
	_check(get_window().mode == Window.MODE_FULLSCREEN, "setup starts in real fullscreen", str(get_window().mode))
	_check(get_viewport().get_visible_rect().size == Vector2(640.0, 360.0), "setup keeps 640x360 viewport")
	_check(_menu.get_display_controller().get_active_mode() == DisplayOptions.Mode.FULLSCREEN, "setup active mode is fullscreen")
	_check(_config_mode() == "fullscreen", "setup config is fullscreen")


func _apply_windowed_pending() -> void:
	await _click_logical(_menu.get_display_mode_button(false).get_global_rect().get_center())
	await _settle(2)
	await _click_logical(_menu.get_apply_button().get_global_rect().get_center())
	await _settle(5)


func _open_settings() -> void:
	for _attempt: int in range(2):
		await _click_logical(_menu.get_settings_button().get_global_rect().get_center())
		await _settle(4)
		if _menu.is_settings_open():
			return


func _click_logical(logical_position: Vector2) -> void:
	DisplayServer.window_move_to_foreground(get_window().get_window_id())
	get_window().grab_focus()
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, true)
	await get_tree().process_frame
	await _mouse_button_logical(logical_position, false)


func _mouse_button_logical(logical_position: Vector2, pressed: bool) -> void:
	var window_size: Vector2i = get_window().size
	var content: Rect2i = DisplayOptions.content_rect(window_size)
	var scale: float = float(content.size.x) / 640.0
	var physical: Vector2 = Vector2(content.position) + logical_position * scale
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = physical
	event.global_position = physical
	get_viewport().push_input(event, false)


func _slider_point(ratio: float) -> Vector2:
	var rect: Rect2 = _menu.get_slider().get_global_rect()
	return Vector2(
		rect.position.x + 2.5 + (rect.size.x - 5.0) * clampf(ratio, 0.0, 1.0),
		rect.get_center().y
	)


func _tap_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _settle(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _physics(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _free_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null
	_menu = null


func _write_display_config(mode: String, size: Vector2i) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "version", 1)
	config.set_value("display", "mode", mode)
	config.set_value("display", "window_width", size.x)
	config.set_value("display", "window_height", size.y)
	config.save(TEMP_DISPLAY_PATH)


func _config_mode() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMP_DISPLAY_PATH) != OK:
		return ""
	return String(config.get_value("display", "mode", ""))


func _config_size() -> Vector2i:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TEMP_DISPLAY_PATH) != OK:
		return Vector2i.ZERO
	return Vector2i(
		int(config.get_value("display", "window_width", 0)),
		int(config.get_value("display", "window_height", 0))
	)


func _remove_temp_audio() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_AUDIO_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _remove_temp_display() -> void:
	var global: String = ProjectSettings.globalize_path(TEMP_DISPLAY_PATH)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)


func _capture_window_state() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {}
	var window: Window = get_window()
	return {
		"mode": window.mode,
		"size": window.size,
		"position": window.position,
		"content_scale_size": window.content_scale_size,
		"content_scale_mode": window.content_scale_mode,
		"content_scale_aspect": window.content_scale_aspect,
		"content_scale_stretch": window.content_scale_stretch,
		"content_scale_factor": window.content_scale_factor,
	}


func _restore_window_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var window: Window = get_window()
	window.mode = int(state.get("mode", Window.MODE_WINDOWED))
	window.size = state.get("size", window.size)
	window.position = state.get("position", window.position)
	window.content_scale_size = state.get("content_scale_size", Vector2i(640, 360))
	window.content_scale_mode = int(state.get("content_scale_mode", Window.CONTENT_SCALE_MODE_VIEWPORT))
	window.content_scale_aspect = int(state.get("content_scale_aspect", Window.CONTENT_SCALE_ASPECT_KEEP))
	window.content_scale_stretch = int(state.get("content_scale_stretch", Window.CONTENT_SCALE_STRETCH_INTEGER))
	window.content_scale_factor = float(state.get("content_scale_factor", 1.0))


func _section(title: String) -> void:
	_log("")
	_log("-- %s --" % title)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		_pass_count += 1
		_log("[PASS] %s  (%s)" % [label, detail])
	else:
		_fail_count += 1
		_log("[FAIL] %s  (%s)" % [label, detail])


func _log(line: String) -> void:
	_log_lines.append(line)
	print(line)


func _finish() -> void:
	await _free_level()
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	_log("")
	_log("TEST_SUMMARY pass=%d fail=%d" % [_pass_count, _fail_count])
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var file: FileAccess = FileAccess.open(
		"res://tests/logs/display_mode_mapping_%s.log" % stamp, FileAccess.WRITE
	)
	if file != null:
		for line: String in _log_lines:
			file.store_line(line)
		file.close()
	print("RESULT: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	get_tree().quit(0 if _fail_count == 0 else 1)
