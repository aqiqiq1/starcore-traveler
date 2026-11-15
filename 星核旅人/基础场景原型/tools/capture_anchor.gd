extends Node

## Actual engine viewport captures for the anchor trial room.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/capture_anchor.tscn
## Two images are fixed showcase poses; the run images come from a scripted
## physics sequence (real input/actions + real physics), not a manual playthrough
## and not a pre-rendered composite. The manifest labels each mode.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _game: PrototypeMain
var _player: PrototypePlayer
var _room: AnchorRoom
var _hud: PrototypeHUD
var _capture_label: Label
var _manifest: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_player()
	_hud = _game.get_hud()
	_room = _game.get_anchor_room()
	_build_capture_overlay()

	_manifest.append("Star Core Traveler - anchor trial engine captures")
	_manifest.append("Godot: %s" % Engine.get_version_info()["string"])
	_manifest.append("Display: %s  renderer: %s" % [
		DisplayServer.get_name(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_manifest.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_manifest.append("Images are captured from the running engine viewport, not pre-rendered art.")
	_manifest.append("FIXED POSE = player physics disabled for the still; SCRIPTED RUN = real physics")
	_manifest.append("driven by the same input actions and physics ticks as the acceptance tests.")
	_manifest.append("The F2 anchor reuses the shared 32x32 RuneStoneVisual concept-derived")
	_manifest.append("sleep/gold/cyan states (96->32 NEAREST) at the unchanged (320,200)")
	_manifest.append("position; no collision, force or route changed.")
	_manifest.append("")

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await get_tree().process_frame
		await get_tree().process_frame

	_game.enter_anchor_room()
	await _step(8)
	_player.global_position = _game.get_anchor_room().get_spawn_position()
	_player.velocity = Vector2.ZERO
	_player.show_showcase(&"idle", 0, 1, true)
	await _step(2)
	await _capture("anchor_01_entry.png", "ENGINE CAPTURE 640x360  |  FIXED POSE: ANCHOR ROOM ENTRY  |  CONCEPT-DERIVED 96->32 STONE / GOLD + / OUT OF RANGE  |  F2 BACK")

	# Fixed pose for F3 range/LOS/force direction.
	_player.global_position = Vector2(220.0, 230.0)
	_player.velocity = Vector2.ZERO
	_player.show_showcase(&"jump", 1, 1, false)
	_player.set_debug_enabled(true)
	_hud.set_debug_visible(true)
	await _step(2)
	await _capture("anchor_02_field_debug.png", "ENGINE CAPTURE 640x360  |  FIXED POSE: CYAN ATTRACT + F3  |  CONCEPT-DERIVED STONE / RANGE 160 / LOS / FORCE ARROW")

	# Scripted physics run from the start ledge.
	_player.set_debug_enabled(false)
	_hud.set_debug_visible(false)
	_player.reset_to_spawn("capture", false)
	await _step(4)
	if _player.is_positive():
		await _tap_action(&"polarity")
	_player.global_position = Vector2(160.0, 288.0)
	_player.velocity = Vector2(160.0, 0.0)
	await _step(1)
	_key_down(KEY_D)
	_key_down(KEY_SHIFT, KEY_LOCATION_LEFT)
	Input.action_press(&"jump")
	await _step(1)
	Input.action_release(&"jump")
	await _step(1)

	var max_vx: float = 0.0
	var attracted_frame: int = -1
	for frame: int in range(1, 101):
		if frame == 40:
			Input.action_press(&"polarity")
		await _step(1)
		if frame == 40:
			Input.action_release(&"polarity")
		max_vx = maxf(max_vx, absf(_player.velocity.x))
		if attracted_frame < 0 and frame == 10:
			attracted_frame = frame
			await _capture("anchor_03_attract_run.png", "ENGINE CAPTURE 640x360  |  SCRIPTED PHYSICS RUN frame %d  |  CYAN ATTRACT  |  VX %.0f" % [frame, _player.velocity.x])
		if _room.is_success():
			break
	await _step(2)
	await _capture("anchor_04_success.png", "ENGINE CAPTURE 640x360  |  SCRIPTED PHYSICS RUN  |  LANDED ON WIDE LEDGE  |  FIELD STILL LIVE / GOLD")
	_key_up(KEY_D)
	_key_up(KEY_SHIFT, KEY_LOCATION_LEFT)

	_manifest.append("anchor_01_entry.png | FIXED POSE | anchor room at spawn, idle frame | concept-derived 96->32 stone / GOLD / OUT OF RANGE")
	_manifest.append("anchor_02_field_debug.png | FIXED POSE | player at (220,230), CYAN | concept-derived stone, F3 range circle, LOS line, force arrow")
	_manifest.append("anchor_03_attract_run.png | SCRIPTED RUN | jump frame 10, CYAN | actual physics")
	_manifest.append("anchor_04_success.png | SCRIPTED RUN | after landing | success banner; HUD field remains live")
	_manifest.append("Scripted run: start (160,288) vx=160, jump, Q->GOLD at frame 40, max_vx=%.1f" % max_vx)
	_manifest.append("The two run stills are not a video; continuous behaviour is covered by the 316 headless assertions.")
	_write_manifest()
	print("CAPTURE_ANCHOR_DONE shots=4 success=%s max_vx=%.1f" % [str(_room.is_success()), max_vx])
	get_tree().quit(0)


func _capture(file_name: String, caption: String) -> void:
	_capture_label.text = caption
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(absolute_path)
	if error != OK:
		printerr("CAPTURE FAILED %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])


func _build_capture_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CaptureOverlay"
	layer.layer = 20
	add_child(layer)

	var root: Control = Control.new()
	root.size = Vector2(640.0, 360.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel: Panel = Panel.new()
	panel.position = Vector2(7.0, 48.0)
	panel.size = Vector2(560.0, 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.04, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.75, 0.70, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	_capture_label = Label.new()
	_capture_label.position = Vector2(12.0, 50.0)
	_capture_label.size = Vector2(550.0, 12.0)
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_label.add_theme_font_size_override("font_size", 8)
	_capture_label.add_theme_color_override("font_color", Color("#e9efeb"))
	root.add_child(_capture_label)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_ANCHOR.txt", FileAccess.WRITE)
	if file == null:
		printerr("Could not write MANIFEST_ANCHOR.txt")
		return
	for line: String in _manifest:
		file.store_line(line)
	file.close()


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await _step(1)
	Input.action_release(action)
	await _step(1)


func _send_key(key: Key, pressed: bool, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.location = location
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_down(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, true, location)


func _key_up(key: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	_send_key(key, false, location)


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame

