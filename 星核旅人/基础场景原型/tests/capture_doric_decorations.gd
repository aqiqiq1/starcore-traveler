extends Node

## Real-engine captures of the static Doric-column decorations. These are
## scripted fixed poses, not a claim of manual continuous play. Run with the GUI
## Godot executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/capture_doric_decorations.tscn

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

	_lines.append("Star Core Traveler - Doric column decoration engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s" % DisplayServer.get_name())
	_lines.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_lines.append("These are scripted fixed poses from the running engine root viewport, not manual continuous play.")
	_lines.append("The four column PNGs are the approved V4 local-detail revision, copied byte-identically.")
	_lines.append("01: opening courtyard, tall column behind the player and narrative stele.")
	_lines.append("02: high-platform stretch with low base/fallen remnants, checkpoint and pit stone.")
	_lines.append("03: far bank tall/broken/fallen group, with the exit kept clear.")
	_lines.append("")

	await _wait_intro_done()
	await _place(Vector2(300.0, 300.0))
	await get_tree().create_timer(1.7).timeout
	await _step(2)
	await _capture("doric_01_entry.png", "opening courtyard: tall column, player and narrative stele")

	await _place(Vector2(1080.0, 220.0))
	await get_tree().create_timer(1.2).timeout
	await _step(4)
	await _capture("doric_02_walkway.png", "high-platform walkway: low remnants, checkpoint and pit rune stone")

	await _place(Vector2(1730.0, 300.0))
	await get_tree().create_timer(1.2).timeout
	await _step(4)
	await _capture("doric_03_far_bank.png", "far bank: tall/broken/fallen group before the clear exit")

	_write_manifest()
	print("DORIC_CAPTURE_DONE decorations=%d" % _count_decorations())
	get_tree().quit(0)


func _count_decorations() -> int:
	var root: Node = _level.get_node_or_null("World/Decorations")
	return root.get_child_count() if root != null else -1


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
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_DORIC.txt", FileAccess.WRITE)
	if file == null:
		push_error("Could not write MANIFEST_DORIC.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
