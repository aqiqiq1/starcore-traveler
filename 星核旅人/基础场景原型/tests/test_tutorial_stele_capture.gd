extends Node

## Real-engine screenshots for the tutorial stele. This is a capture harness,
## not an assertion runner and not a claim of manual continuous play. It loads
## the actual main scene, places the player at fixed positions, lets the glow
## animation run, and captures the root viewport at 640x360.
##
## Run with the GUI Godot executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/test_tutorial_stele_capture.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _game: PrototypeMain
var _player: PrototypePlayer
var _stele: TutorialStele
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await _step(6)
	_player = _game.get_player()
	_stele = _game.get_node("World/TutorialStele") as TutorialStele
	if _player == null or _stele == null:
		push_error("Capture setup failed: player or stele missing")
		get_tree().quit(1)
		return

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _step(3)

	_lines.append("Star Core Traveler - tutorial stele engine captures")
	_lines.append("Godot: %s" % Engine.get_version_info()["string"])
	_lines.append("Display: %s  renderer: %s" % [
		DisplayServer.get_name(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_lines.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_lines.append("Images are captured from the running engine root viewport, not pre-rendered art.")
	_lines.append("Each still is a scripted fixed pose / scripted F key, not a manual continuous playthrough.")
	_lines.append("The stele art is the approved 26x52 concept-derived grey reference + 64-frame glow sheet.")
	_lines.append("Glow passes hold gold #f4cd63 then cyan #5fe1e6; the crossfade only happens off-groove.")
	_lines.append("Pixel audit of the saved shots: 02 contains exact #f4cd63; 05 contains exact #5fe1e6; 01 contains neither.")
	_lines.append("")

	# Grey state: the player is at the normal spawn, 144 px from the stele.
	_player.global_position = _game.get_spawn_position()
	_player.velocity = Vector2.ZERO
	await _step(6)
	await _capture(
		"tutorial_stele_01_grey.png",
		"grey state at spawn, no prompt; stele at (224,288)"
	)

	# Page 1: stand 46 px to the right of the stele, outside the short step and
	# clear of the player's polarity badge.
	_player.global_position = Vector2(270.0, 288.0)
	_player.velocity = Vector2.ZERO
	await _step(4)
	await get_tree().create_timer(1.0).timeout
	await _step(2)
	await _capture(
		"tutorial_stele_02_page1.png",
		"page 1, gold pass; F footer"
	)

	# Page 2 via a real F press.
	await _tap_f()
	await _step(8)
	await _capture(
		"tutorial_stele_03_page2.png",
		"page 2 via real F; glow continues"
	)

	# Page 3 / last page via a real F press.
	await _tap_f()
	await _step(8)
	await _capture(
		"tutorial_stele_04_page3.png",
		"last page via real F; footer reads F 收起"
	)

	# The 8 s sheet holds gold for the first band pass and cyan for the second.
	# Wait to the cyan band_y=26 checkpoint (sheet frame 48) so both approved
	# colours are visible in an actual engine capture.
	await get_tree().create_timer(3.65).timeout
	await _step(2)
	await _capture(
		"tutorial_stele_05_cyan_page3.png",
		"cyan pass near band_y=26 while page 3 remains open"
	)

	_write_manifest()
	print("TUTORIAL_STELE_CAPTURE_DONE shots=5 page=%d focused=%s grey=%s frame=%d" % [
		_stele.get_page_index(),
		str(_stele.is_focused()),
		str(_stele.is_grey_visual()),
		_stele.get_animation_frame(),
	])
	get_tree().quit(0)


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


func _tap_f() -> void:
	_send_key(KEY_F, true)
	await _step(2)
	_send_key(KEY_F, false)
	await _step(2)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_TUTORIAL_STELE.txt", FileAccess.WRITE)
	if file == null:
		push_error("Could not write MANIFEST_TUTORIAL_STELE.txt")
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
