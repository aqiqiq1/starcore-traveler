extends Node

## One real-engine capture for the V7 background integration. It is a scripted
## fixed pose near the pit, not a claim of manual continuous play. Run with the
## GUI Godot executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_background_v7.tscn

const LEVEL_SCENE: PackedScene = preload("res://scenes/level_01.tscn")
const CAPTURE_PATH: String = "res://screenshots/background_v7_level01.png"
const MANIFEST_PATH: String = "res://screenshots/MANIFEST_BACKGROUND_V7.txt"

var _level: Level01
var _player: PrototypePlayer
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))

	_level = LEVEL_SCENE.instantiate() as Level01
	_level.enable_start_menu = false
	add_child(_level)
	await _step(8)
	_player = _level.get_player()
	if _player == null:
		push_error("Background V7 capture failed: player missing")
		get_tree().quit(1)
		return

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_lines.append("Star Core Traveler - Level 01 V7 background integration capture")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_lines.append("Scripted fixed pose near the pit; not manual continuous play.")
	_lines.append("Purpose: internal check that the static V7 screen background renders under the existing level art/HUD.")

	await _wait_intro_done()
	await _place(Vector2(1174.0, 220.0))
	await get_tree().create_timer(1.45).timeout
	await _step(4)
	await _capture("background_v7_level01.png", "pit edge pose on the high platform; V7 static background behind the existing world/HUD")
	_write_manifest()
	print("BACKGROUND_V7_CAPTURE_DONE")
	get_tree().quit(0)


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_level.get_camera().reset_smoothing()
	await _step(6)


func _wait_intro_done() -> void:
	for _index: int in range(300):
		await get_tree().process_frame
		if not _level.is_intro_active():
			break
	await _step(6)


func _capture(file_name: String, note: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path("res://screenshots/" + file_name))
	if error != OK:
		push_error("Capture failed for %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_lines.append("%s | %s" % [file_name, note])


func _step(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write MANIFEST_BACKGROUND_V7.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
