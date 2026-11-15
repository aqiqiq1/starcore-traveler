extends Node

## Actual engine viewport capture tool. Run with the GUI executable:
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/capture_screenshots.tscn
## This scene opens the real main scene, forces specific animation frames via
## PrototypePlayer.show_showcase(), waits for the renderer, and saves the
## root viewport image. It is not a pre-rendered or composited mock-up.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CAPTURE_DIR: String = "res://screenshots"

var _game: PrototypeMain
var _player: PrototypePlayer
var _capture_label: Label
var _capture_panel: Panel
var _manifest: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	var absolute_dir: String = ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

	_game = MAIN_SCENE.instantiate() as PrototypeMain
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _game.get_player()
	_build_capture_overlay()

	var window_size: Vector2i = DisplayServer.window_get_size()
	_manifest.append("Star Core Traveler - actual engine viewport captures")
	_manifest.append("Godot: %s" % Engine.get_version_info()["string"])
	_manifest.append("Display: %s  renderer: %s" % [
		DisplayServer.get_name(),
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
	])
	_manifest.append("Window size: %dx%d" % [window_size.x, window_size.y])
	_manifest.append("Logical viewport: 640x360 (project stretch=viewport, nearest filter)")
	_manifest.append("These images are captured from the running engine viewport, not pre-rendered art.")
	_manifest.append("")

	var walk_only: bool = OS.get_cmdline_user_args().has("--walk-only")
	if walk_only:
		await _capture_pose(&"walk", 0, 1, true, Vector2(96.0, 288.0), "21_walk_right_gold.png", -1, false)
		await _capture_pose(&"walk", 0, -1, false, Vector2(96.0, 288.0), "22_walk_left_cyan.png", -1, false)
		_manifest.append("")
		_manifest.append("WALK-ONLY ADDENDUM: captured after adding walk as the default movement state.")
		_manifest.append("21/22 were re-captured after adding the F2 anchor-room hint to the base HUD.")
		_manifest.append("21/22 are post-change walk captures; 01-20 are the earlier pre-walk-default set.")
		_write_manifest("MANIFEST_WALK.txt")
		print("CAPTURE_DONE mode=walk-only shots=2")
		get_tree().quit(0)
		return

	var anims: Array[StringName] = [&"idle", &"run", &"jump", &"fall"]
	var frame_indices: Array[int] = [0, 4, 2, 1]
	var positions: Array[Vector2] = [
		Vector2(96.0, 288.0),
		Vector2(384.0, 288.0),
		Vector2(320.0, 152.0),
		Vector2(432.0, 144.0),
	]
	var shot_index: int = 1
	for anim_index: int in range(anims.size()):
		for facing: int in [1, -1]:
			for positive: bool in [true, false]:
				var anim_name: String = String(anims[anim_index])
				var facing_name: String = "right" if facing > 0 else "left"
				var polarity_name: String = "gold" if positive else "cyan"
				var file_name: String = "%02d_%s_%s_%s.png" % [
					shot_index, anim_name, facing_name, polarity_name
				]
				await _capture_pose(
					anims[anim_index], frame_indices[anim_index], facing, positive,
					positions[anim_index], file_name, -1, false
				)
				shot_index += 1

	await _capture_pose(&"idle", 0, 1, true, Vector2(96.0, 288.0), "17_ring_gold.png", 2, false)
	await _capture_pose(&"idle", 0, 1, false, Vector2(96.0, 288.0), "18_ring_cyan.png", 2, false)
	await _capture_pose(&"idle", 0, 1, true, Vector2(96.0, 288.0), "19_anchor_debug_idle.png", -1, true)
	await _capture_pause()
	await _capture_pose(&"walk", 0, 1, true, Vector2(96.0, 288.0), "21_walk_right_gold.png", -1, false)
	await _capture_pose(&"walk", 0, -1, false, Vector2(96.0, 288.0), "22_walk_left_cyan.png", -1, false)

	_manifest.append("")
	_manifest.append("Ring shots freeze showcase frame 2 (0.10 s of the 0.20 s one-shot).")
	_manifest.append("The debug shot shows the chest cross and 12x30 body collision rectangle.")
	_manifest.append("Capture labels and manifest use 0-based source frame indices.")
	_manifest.append("21/22 are walk captures added after walk/sprint became the default.")
	_write_manifest("MANIFEST.txt")
	print("CAPTURE_DONE shots=22")
	get_tree().quit(0)


func _build_capture_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CaptureOverlay"
	layer.layer = 20
	add_child(layer)

	var root: Control = Control.new()
	root.size = Vector2(640.0, 360.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_capture_panel = Panel.new()
	_capture_panel.position = Vector2(7.0, 48.0)
	_capture_panel.size = Vector2(560.0, 16.0)
	_capture_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.04, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.75, 0.70, 0.85)
	_capture_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_capture_panel)

	_capture_label = Label.new()
	_capture_label.position = Vector2(12.0, 50.0)
	_capture_label.size = Vector2(550.0, 12.0)
	_capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_label.add_theme_font_size_override("font_size", 8)
	_capture_label.add_theme_color_override("font_color", Color("#e9efeb"))
	root.add_child(_capture_label)


func _capture_pose(
	anim: StringName,
	frame_index: int,
	facing: int,
	positive: bool,
	player_position: Vector2,
	file_name: String,
	ring_frame: int,
	debug_overlay: bool
) -> void:
	_player.global_position = player_position
	_player.velocity = Vector2.ZERO
	_player.show_showcase(anim, frame_index, facing, positive, ring_frame)
	_player.set_debug_enabled(debug_overlay)
	_game.get_hud().set_debug_visible(debug_overlay)
	await get_tree().process_frame
	await get_tree().process_frame

	var anchor: Vector2i = _player.get_chest_anchor_frame()
	var facing_text: String = "RIGHT" if facing > 0 else "LEFT"
	var polarity_text: String = "GOLD (+)" if positive else "CYAN (-)"
	var ring_text: String = ""
	if ring_frame >= 0:
		ring_text = "  |  RING %d/4 @0.10s" % (ring_frame + 1)
	var debug_text: String = ""
	if debug_overlay:
		debug_text = "  |  DEBUG CROSS=CHEST RECT=12x30"
	_capture_label.text = "ENGINE CAPTURE 640x360  |  %s #%d/%d  |  %s  |  %s%s%s" % [
		String(anim).to_upper(), frame_index, _player.get_frame_count_for(anim) - 1,
		facing_text, polarity_text, ring_text, debug_text
	]

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/" + file_name)
	var error: Error = image.save_png(absolute_path)
	if error != OK:
		printerr("CAPTURE FAILED %s error=%d" % [file_name, error])
	else:
		print("CAPTURED %s size=%s" % [file_name, str(image.get_size())])
	_manifest.append("%s | %s #%d/%d | facing=%s | polarity=%s | chest=(%d,%d) | pos=(%.0f,%.0f) | image=%s" % [
		file_name,
		String(anim), frame_index, _player.get_frame_count_for(anim) - 1,
		facing_text, polarity_text, anchor.x, anchor.y,
		player_position.x, player_position.y, str(image.get_size()),
	])


func _capture_pause() -> void:
	_player.global_position = Vector2(96.0, 288.0)
	_player.velocity = Vector2.ZERO
	_player.show_showcase(&"idle", 0, 1, true)
	_player.set_debug_enabled(false)
	_game.get_hud().set_debug_visible(false)
	_game.toggle_pause()
	_game.get_hud().set_pause_visible(true)
	_capture_label.text = "ENGINE CAPTURE 640x360  |  PAUSED  |  ESC RESUME  |  PHYSICS + EFFECTS FROZEN"
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var absolute_path: String = ProjectSettings.globalize_path(CAPTURE_DIR + "/20_pause_overlay.png")
	var error: Error = image.save_png(absolute_path)
	if error != OK:
		printerr("CAPTURE FAILED 20_pause_overlay.png error=%d" % error)
	else:
		print("CAPTURED 20_pause_overlay.png size=%s" % str(image.get_size()))
	_manifest.append("20_pause_overlay.png | paused overlay | physics frozen | image=%s" % str(image.get_size()))
	_game.toggle_pause()


func _write_manifest(file_name: String = "MANIFEST.txt") -> void:
	var file: FileAccess = FileAccess.open(CAPTURE_DIR + "/" + file_name, FileAccess.WRITE)
	if file == null:
		printerr("Could not write capture manifest %s" % file_name)
		return
	for line: String in _manifest:
		file.store_line(line)
	file.close()
