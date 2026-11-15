extends Node

## Real-engine screenshots for level 01. These are scripted fixed poses, not a
## claim of manual continuous play. Run with the GUI Godot executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_level01.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _level: Level01
var _player: PrototypePlayer
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _step(8)
	_player = _level.get_player()
	if _player == null:
		push_error("Capture setup failed: player missing")
		get_tree().quit(1)
		return

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_lines.append("Star Core Traveler - Level 01 engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_lines.append("These are scripted fixed poses from the running engine root viewport, not manual continuous play.")
	_lines.append("01: opening courtyard, narrative stele and formal Chinese HUD.")
	_lines.append("02: high-platform checkpoint and the wide pit with the second rune stone.")
	_lines.append("03: exit gate and the first-level completion/replay panel.")
	_lines.append("")

	await _wait_intro_done()
	await _place(Vector2(300.0, 300.0))
	await get_tree().create_timer(1.7).timeout
	await _step(2)
	await _capture("level_01_01_start.png", "opening courtyard, narrative stele, 辉相 HUD")

	await _place(Vector2(1174.0, 220.0))
	await get_tree().create_timer(1.7).timeout
	await _step(4)
	await _capture("level_01_02_pit.png", "checkpoint at the high platform edge, wide pit and rune stone ahead")

	await _place(Vector2(1838.0, 300.0))
	await _step(10)
	if not _level.is_completed():
		# The area trigger is the real path; this is only a capture fallback if
		# the scripted pose did not overlap the trigger on this frame.
		_level.get_exit().player_reached_exit.emit()
		await _step(6)
	await _capture("level_01_03_complete.png", "exit gate and 第一关完成 replay panel")

	_write_manifest()
	print("LEVEL01_CAPTURE_DONE completed=%s count=%d" % [
		str(_level.is_completed()), _level.get_completion_count()
	])
	get_tree().quit(0)


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _step(4)


func _wait_intro_done() -> void:
	for i: int in range(300):
		await get_tree().process_frame
		if not _level.is_intro_active():
			break
	await _step(6)


func _capture(file_name: String, note: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])


func _step(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_LEVEL01.txt", FileAccess.WRITE)
	if file == null:
		push_error("Could not write MANIFEST_LEVEL01.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
