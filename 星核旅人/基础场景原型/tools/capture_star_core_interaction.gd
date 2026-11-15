extends Node

## Actual engine viewport captures for the star-core bay interaction sandbox.
## Run with the GUI executable:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_star_core_interaction.tscn
##
## The opening still is a scripted setup; the transport/capture/re-release stills
## come from a real 60 Hz input/physics run (E, Q, D). They are scripted stills,
## not a human playthrough and not a pre-rendered composite.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _game: PrototypeMain
var _player: PrototypePlayer
var _hud: PrototypeHUD
var _room: StarCoreInteractionRoom
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
	_room = _game.get_interaction_room()
	_build_capture_overlay()

	_manifest.append("Star Core Traveler - star-core bay interaction engine captures")
	_manifest.append("Godot: %s" % Engine.get_version_info()["string"])
	_manifest.append("Display: %s  renderer: %s" % [
		DisplayServer.get_name(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_manifest.append("Window: %s  logical viewport: 640x360" % str(DisplayServer.window_get_size()))
	_manifest.append("Images are captured from the running engine viewport, not pre-rendered art.")
	_manifest.append("SCRIPTED STILLS: real InputMap actions and real 60 Hz physics; not human play.")
	_manifest.append("")

	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size == Vector2i(640, 360):
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await get_tree().process_frame
		await get_tree().process_frame

	_game.enter_interaction_room()
	await _step(6)
	_player.global_position = Vector2(84.0, 320.0)
	_player.velocity = Vector2.ZERO
	await _step(2)

	Input.action_press(&"interact")
	await _step(1)
	Input.action_release(&"interact")
	await _step(5)
	await _capture(
		"interaction_01_opening.png",
		"ENGINE CAPTURE 640x360 | SCRIPTED STILL: LID OPENING | E SNAPSHOT CYAN - | CORE STILL IN BAY"
	)

	await _step(18)
	if not _room.get_core().is_active():
		await _step(10)
	# No Q: GOLD player and CYAN core attract; the core follows to the right.
	Input.action_press(&"move_right")
	for i: int in range(55):
		await _step(1)
	await _capture(
		"interaction_02_transport.png",
		"ENGINE CAPTURE 640x360 | SCRIPTED PHYSICS RUN | PLAYER GOLD + / CORE CYAN - | HETEROPOLAR FOLLOW | VX %.0f" % _room.get_core().velocity.x
	)

	for i: int in range(320):
		await _step(1)
		if _player.global_position.x >= 500.0:
			break
	Input.action_release(&"move_right")
	for i: int in range(40):
		await _step(1)
		if _room.get_e_preview_text().contains("STORE CORE (TARGET)"):
			break
	Input.action_press(&"interact")
	await _step(1)
	Input.action_release(&"interact")
	await _step(7)
	await _capture(
		"interaction_03_target_capture.png",
		"ENGINE CAPTURE 640x360 | SCRIPTED PHYSICS RUN | MANUAL E STORE | TARGET LID RISING | SUCCESS HINT (PHYSICS STILL LIVE)"
	)

	for i: int in range(40):
		await _step(1)
		if _room.get_target_bay().is_locked():
			break
	for i: int in range(30):
		await _step(1)
		if _room.get_e_preview_text().contains("RELEASE"):
			break
	Input.action_press(&"interact")
	await _step(1)
	Input.action_release(&"interact")
	await _step(18)
	if not _room.get_core().is_active():
		await _step(10)
	await _capture(
		"interaction_04_target_release.png",
		"ENGINE CAPTURE 640x360 | SCRIPTED PHYSICS RUN | TARGET RE-RELEASE | CORE CYAN - | PLAYER GOLD +"
	)

	_manifest.append("interaction_01_opening.png | SCRIPTED STILL | start bay lid opening, E snapshot CYAN -")
	_manifest.append("interaction_02_transport.png | SCRIPTED RUN | player GOLD +, core CYAN -, heteropolar follow right")
	_manifest.append("interaction_03_target_capture.png | SCRIPTED RUN | manual E store, target lid rising, success hint")
	_manifest.append("interaction_04_target_release.png | SCRIPTED RUN | target re-release, core CYAN -")
	_manifest.append("Capture setup: place the player near start; real E/D for opening and heteropolar follow; real E STORE at target; real E re-release. The separate interaction test walks the whole route and returns.")
	_manifest.append("These stills are not a video and not human play; continuous behaviour is covered by the interaction test.")
	_write_manifest()
	print("CAPTURE_INTERACTION_DONE shots=4 success=%s core_active=%s" % [
		str(_room.is_success()), str(_room.get_core().is_active())
	])
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
	panel.size = Vector2(626.0, 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.04, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.75, 0.70, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	_capture_label = Label.new()
	_capture_label.position = Vector2(12.0, 50.0)
	_capture_label.size = Vector2(616.0, 12.0)
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_label.add_theme_font_size_override("font_size", 8)
	_capture_label.add_theme_color_override("font_color", Color("#e9efeb"))
	root.add_child(_capture_label)


func _write_manifest() -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/MANIFEST_INTERACTION.txt", FileAccess.WRITE)
	if file == null:
		printerr("Could not write MANIFEST_INTERACTION.txt")
		return
	for line: String in _manifest:
		file.store_line(line)
	file.close()


func _step(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
