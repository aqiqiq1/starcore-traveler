extends Node

## Small real-GUI capture for the new pause page / completion page / level-02
## pause page.  It is intentionally limited to three frames; it is not a full
## route capture.
##
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . \
##       res://tests/capture_level_flow_pause.tscn

const LEVEL01_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const LEVEL02_SCENE: PackedScene = preload("res://scenes/level_02.tscn")
const CAPTURE_DIR: String = "res://screenshots"
const TEMP_AUDIO: String = "user://capture_level_flow_pause_audio.cfg"
const TEMP_DISPLAY: String = "user://capture_level_flow_pause_display.cfg"

var _level: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)

	# 1) Level 01 pause page with the per-level control rows.
	_level = LEVEL01_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _wait_intro_done()
	await _tap_key(KEY_ESCAPE)
	await _settle(3)
	await _capture("level_flow_pause_01_level01_pause.png")

	# 1b) The shared settings page hosted inside the pause page (still paused).
	var pause_menu: Node = _level.get_pause_menu()
	pause_menu.call("open_settings")
	await _settle(3)
	await _capture("level_flow_pause_04_settings.png")
	await _tap_key(KEY_ESCAPE)  # back to the pause root
	await _settle(2)

	# 2) Level 01 completion page with 进入第二关.
	await _tap_key(KEY_ESCAPE)  # resume
	await _settle(2)
	_level.get_exit().player_reached_exit.emit()
	await _settle(4)
	await _capture("level_flow_pause_02_level01_completion.png")
	await _free_level()

	# 3) Level 02 pause page adds the E release/store row.
	_level = LEVEL02_SCENE.instantiate() as Level02
	_level.pause_audio_settings_path = TEMP_AUDIO
	_level.pause_display_settings_path = TEMP_DISPLAY
	get_tree().root.add_child(_level)
	await _physics(8)
	await _tap_key(KEY_ESCAPE)
	await _settle(3)
	await _capture("level_flow_pause_03_level02_pause.png")
	await _free_level()

	_remove_temp(TEMP_AUDIO)
	_remove_temp(TEMP_DISPLAY)
	print("CAPTURE_DONE")
	get_tree().quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	await _settle(2)
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(path)
	print("%s -> %s" % ["OK" if error == OK else "ERROR %d" % error, path])


func _wait_intro_done() -> void:
	for _i: int in range(300):
		await get_tree().process_frame
		if _level != null and not _level.is_intro_active():
			break
	await _physics(6)


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	_send_key(key, false)
	await get_tree().process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _free_level() -> void:
	get_tree().paused = false
	if is_instance_valid(_level):
		if get_tree().current_scene == _level:
			get_tree().current_scene = null
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = null


func _settle(frames: int) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for _i: int in range(frames):
		await get_tree().physics_frame


func _remove_temp(path: String) -> void:
	var global: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global):
		DirAccess.remove_absolute(global)
