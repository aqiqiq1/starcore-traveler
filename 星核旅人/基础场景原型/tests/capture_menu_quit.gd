extends Node

## Capture the current first-screen menu with the new 退出游戏 row.
##
## This is an additive capture: it writes screenshots/menu_with_quit.png and
## its exact 2x companion only.  It never overwrites the older two-entry menu
## captures or the approved V1 preview.
##
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/capture_menu_quit.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const TEMP_AUDIO_PATH: String = "user://capture_menu_quit_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://capture_menu_quit_display.cfg"

var _level: Level01
var _menu: StartMenu
var _background: CloudRuinsDS03
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	if DisplayServer.window_get_size().x < 1280:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _step(6)
	_menu = _level.get_menu()
	_background = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03
	if _menu == null or _menu.get_phase_name() != "menu":
		push_error("menu quit capture: menu did not open")
		_finish(1)
		return
	await RenderingServer.frame_post_draw
	await _step(2)

	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(
		ProjectSettings.globalize_path(CAPTURE_DIR + "/menu_with_quit.png")
	)
	var two_x: Image = image.duplicate()
	two_x.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var two_x_error: Error = two_x.save_png(
		ProjectSettings.globalize_path(CAPTURE_DIR + "/menu_with_quit_2x.png")
	)
	if error != OK or two_x_error != OK:
		push_error("menu quit capture failed (%d / %d)" % [error, two_x_error])
		_finish(1)
		return
	print("CAPTURED menu_with_quit.png and menu_with_quit_2x.png bg_t=%.3f focus=%s quit=%s" % [
		_background.get_background_time(),
		str(get_viewport().gui_get_focus_owner() == _menu.get_start_button()),
		str(_menu.get_quit_button().get_global_rect()),
	])
	_write_manifest()
	_finish(0)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(
		CAPTURE_DIR + "/MANIFEST_MENU_QUIT.txt", FileAccess.WRITE
	)
	if file == null:
		push_error("could not write MANIFEST_MENU_QUIT.txt")
		return
	file.store_line("Star Core Traveler - start menu with 退出游戏")
	file.store_line("Godot: %s" % Engine.get_version_info()["string"])
	file.store_line("Display: %s  window=%s  logical=640x360" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size())
	])
	file.store_line("menu_with_quit.png | current menu: V1 title/start/settings + additive quit row; focus on 开始游戏; DS03 background animated | bg_t=%.3f" % _background.get_background_time())
	file.store_line("menu_with_quit_2x.png | exact 2x NEAREST of menu_with_quit.png")
	file.store_line("The older menu_level01_* captures and the V1 preview are not overwritten.")
	file.close()


func _step(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


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


func _finish(code: int) -> void:
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	get_tree().quit(code)
