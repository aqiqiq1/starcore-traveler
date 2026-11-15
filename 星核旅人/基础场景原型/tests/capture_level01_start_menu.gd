extends Node

## Real-engine captures for the integrated start menu. Run with the GUI Godot
## executable (not --headless):
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_level01_start_menu.tscn
##
## Every capture is a scripted fixed-time frame from the running engine, not a
## manual playthrough. The settings capture uses the real slider and Master bus,
## but points persistence at a temporary user:// file and restores the user's
## Master volume at the end.

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const TEMP_AUDIO_PATH: String = "user://capture_start_menu_audio.cfg"
const TEMP_DISPLAY_PATH: String = "user://capture_start_menu_display.cfg"

var _level: Level01
var _menu: StartMenu
var _player: PrototypePlayer
var _hud: Level01HUD
var _world: Node2D
var _menu_camera: Camera2D
var _background: CloudRuinsDS03
var _lines: Array[String] = []
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

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x < 1280:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_level = LEVEL_SCENE.instantiate() as Level01
	var temp_menu: StartMenu = _level.get_node("StartMenu") as StartMenu
	temp_menu.audio_settings_path = TEMP_AUDIO_PATH
	temp_menu.display_settings_path = TEMP_DISPLAY_PATH
	add_child(_level)
	await _step(6)
	_menu = _level.get_menu()
	_player = _level.get_player()
	_hud = _level.get_hud()
	_world = _level.get_node("World") as Node2D
	_menu_camera = _level.get_menu_camera()
	_background = _level.get_node("Background/CloudRuinsDS03") as CloudRuinsDS03

	_lines.append("Star Core Traveler - integrated start menu captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s  window=%s  logical=640x360" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size())
	])
	_lines.append("These are scripted fixed-time frames from the running engine; not manual continuous play.")
	_lines.append("Audio persistence uses %s and Master is restored after the run." % TEMP_AUDIO_PATH)
	_lines.append("")

	# 1. Initial pure background menu (focus accent on 开始游戏).
	await _capture(
		"menu_level01_initial.png",
		"initial menu: DS03 background + V1 title/start/settings only; World, player and HUD hidden",
		"phase=menu"
	)

	# 2. Settings, opened by real mouse; slider moved to 55% through a real drag.
	await _mouse_click(_menu.get_settings_button().get_global_rect().get_center())
	await _step(3)
	var slider_rect: Rect2 = _menu.get_slider().get_global_rect()
	var target_x: float = slider_rect.position.x + slider_rect.size.x * 0.55
	await _mouse_click(Vector2(target_x, slider_rect.get_center().y))
	await _step(3)
	await _capture(
		"menu_level01_settings.png",
		"settings modal: real Master volume slider at %d%%, 返回 button, animated DS03 background" % _menu.get_volume_percent(),
		"phase=menu settings=open volume=%d%%" % _menu.get_volume_percent()
	)

	# 3. Close settings, then start with a real mouse click.
	await _tap_key(KEY_ESCAPE)
	await _step(3)
	await _mouse_click(_menu.get_start_button().get_global_rect().get_center())
	await _step(2)
	_lines.append("start request via real mouse: count=%d phase=%s" % [
		_menu.get_start_request_count(), _menu.get_phase_name()
	])

	var mid_done: bool = false
	var settled_done: bool = false
	var guard: int = 0
	while _menu.get_phase_name() != "done" and guard < 1200:
		guard += 1
		await get_tree().process_frame
		var phase: String = _menu.get_phase_name()
		var center: Vector2 = _menu_camera.get_screen_center_position()
		if phase == "camera_pan" and not mid_done and center.y >= 150.0:
			await _capture(
				"menu_level01_camera_mid.png",
				"mid camera pan: real World revealed under the moving temporary camera",
				"phase=camera_pan camera=%s player_visible=%s hud_visible=%s" % [
					str(center), str(_player.visible), str(_hud.visible)
				]
			)
			mid_done = true
		if phase == "settle" and not settled_done:
			await _capture(
				"menu_level01_camera_settled_before_entry.png",
				"camera fully down, 0.15 s settle before the existing opening auto-run",
				"phase=settle camera=%s intro=%s player_visible=%s hud_visible=%s" % [
					str(_menu_camera.get_screen_center_position()),
					str(_level.is_intro_active()), str(_player.visible), str(_hud.visible)
				]
			)
			settled_done = true

	_lines.append("transition reached=%s mid_capture=%s settle_capture=%s" % [
		_menu.get_phase_name(), str(mid_done), str(settled_done)
	])
	if not mid_done:
		push_error("capture: never reached the mid camera frame")
	if not settled_done:
		push_error("capture: never reached the settle frame")

	# 4. Playable frame after the original intro hands control back.
	await _wait_intro_done()
	await get_tree().create_timer(0.8).timeout
	await _step(2)
	await _capture(
		"menu_level01_playable.png",
		"playable level after the original intro: player, HUD, terrain and DS03 background",
		"phase=done intro=%s camera=%s player=%s hud_visible=%s" % [
			str(_level.is_intro_active()), str(_level.get_camera().get_screen_center_position()),
			str(_player.global_position), str(_hud.visible)
		]
	)

	_write_manifest()
	print("MENU_CAPTURE_DONE mid=%s settle=%s intro=%s" % [
		str(mid_done), str(settled_done), str(_level.is_intro_active())
	])
	_finish()


func _capture(file_name: String, note: String, state: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(
		ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	)
	var two_x: Image = image.duplicate()
	two_x.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var two_x_name: String = file_name.replace(".png", "_2x.png")
	var two_x_error: Error = two_x.save_png(
		ProjectSettings.globalize_path(CAPTURE_DIR + "/" + two_x_name)
	)
	if error != OK or two_x_error != OK:
		push_error("capture failed for %s (%d / %d)" % [file_name, error, two_x_error])
	else:
		print("CAPTURED %s and %s bg_t=%.3f camera=%s" % [
			file_name, two_x_name, _background.get_background_time(), state
		])
	_lines.append("%s | %s | bg_t=%.3f | %s" % [
		file_name, note, _background.get_background_time(), state
	])
	_lines.append("%s | exact 2x NEAREST of %s" % [two_x_name, file_name])


func _step(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _wait_intro_done() -> void:
	for _i: int in range(420):
		if not _level.is_intro_active():
			break
		await get_tree().process_frame
	await _step(4)


func _mouse_click(pos: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _tap_key(code: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release: InputEventKey = InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(
		CAPTURE_DIR + "/MANIFEST_MENU_LEVEL01.txt", FileAccess.WRITE
	)
	if file == null:
		push_error("could not write MANIFEST_MENU_LEVEL01.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()


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


func _finish() -> void:
	AudioServer.set_bus_mute(0, _original_master_mute)
	AudioServer.set_bus_volume_db(0, _original_master_db)
	_remove_temp_audio()
	_remove_temp_display()
	_restore_window_state(_original_window_state)
	get_tree().quit(0)
