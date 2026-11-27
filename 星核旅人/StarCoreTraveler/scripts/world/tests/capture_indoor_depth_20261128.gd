extends Node

## 640x360 before/after evidence for the 2026-11-28 DLC2/DLC3 indoor depth
## pass.  Run WITHOUT --headless:
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://scripts/world/tests/capture_indoor_depth_20261128.tscn
##
## Writes to res://screenshots/depth_indoor_20261128/:
##   rift_before_arch.png / rift_after_arch.png
##   rift_before_forge.png / rift_after_forge.png
##   loom_before_windows.png / loom_after_windows.png
##   loom_before_loom.png / loom_after_loom.png
## plus 0.2 s strip frames under strip_rift/ and strip_loom/ and a
## STATIC_DIFF line for a wall-only crop.

const OUT_DIR: String = "res://screenshots/depth_indoor_20261128"
const STRIP_RIFT: String = "res://screenshots/depth_indoor_20261128/strip_rift"
const STRIP_LOOM: String = "res://screenshots/depth_indoor_20261128/strip_loom"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const RIFT_STATIC_CROP: Rect2i = Rect2i(280, 110, 200, 170)
const LOOM_STATIC_CROP: Rect2i = Rect2i(280, 100, 100, 180)
const STRIP_TIMES: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("INDOOR_DEPTH_CAPTURE done dir=%s" % OUT_DIR)
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(directory: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var absolute: String = ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(absolute)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(absolute.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _setup_chapter(packed: PackedScene) -> Node2D:
	var chapter: Node2D = packed.instantiate() as Node2D
	chapter.set("show_intro_guide", false)
	chapter.set("show_intro_cinematic", false)
	get_tree().root.add_child(chapter)
	get_tree().current_scene = chapter
	return chapter


func _pose(chapter: Node2D, x: float, y: float, scrolling: bool = true,
		freeze_logic: bool = false) -> void:
	var player: Node2D = chapter.call("get_player") as Node2D
	var camera: Camera2D = chapter.call("get_camera") as Camera2D
	if freeze_logic:
		chapter.set_process(false)
		chapter.set_physics_process(false)
	player.global_position = Vector2(x, y)
	player.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	if scrolling:
		await _wait_process(10)
	else:
		await _wait_process(4)


func _before_after(chapter: Node2D, depth_path: String,
		before_name: String, after_name: String) -> void:
	var depth: Node = chapter.get_node_or_null(depth_path)
	var atmosphere: Node = chapter.get_node_or_null("Atmosphere")
	if depth == null or atmosphere == null:
		printerr("CAPTURE missing layer nodes")
		return
	var gate: Node = chapter.get_node_or_null("MirrorRiftGate")
	depth.call("set_strength_for_capture", 0.0)
	atmosphere.set("modulate", Color(1.0, 1.0, 1.0, 0.0))
	if gate != null:
		gate.call("set_depth_strength", 0.0)
	await _wait_process(4)
	await _save(OUT_DIR, before_name)
	depth.call("set_strength_for_capture", 1.0)
	atmosphere.set("modulate", Color(1.0, 1.0, 1.0, 1.0))
	if gate != null:
		gate.call("set_depth_strength", 1.0)
	await _wait_process(4)
	await _save(OUT_DIR, after_name)


func _diff_rect(path_a: String, path_b: String, rect: Rect2i) -> int:
	var image_a: Image = Image.load_from_file(path_a)
	var image_b: Image = Image.load_from_file(path_b)
	if image_a == null or image_b == null:
		return -1
	var crop_a: Image = image_a.get_region(rect)
	var crop_b: Image = image_b.get_region(rect)
	var changed: int = 0
	for y: int in range(crop_a.get_height()):
		for x: int in range(crop_a.get_width()):
			if crop_a.get_pixel(x, y) != crop_b.get_pixel(x, y):
				changed += 1
	return changed


func _glass_key(color: Color) -> int:
	return (int(round(color.r * 255.0)) << 16) \
		| (int(round(color.g * 255.0)) << 8) \
		| int(round(color.b * 255.0))


func _glass_set() -> Dictionary:
	## Same sky/cloud family as window_module; leaded bars, stone frame,
	## stained-glass accents and foreground props are deliberately excluded.
	var keys: Dictionary = {}
	for y: int in range(92, 296):
		var t: float = float(y - 92) / 203.0
		keys[_glass_key(Color(
			(45.0 + (120.0 - 45.0) * t) / 255.0,
			(90.0 + (165.0 - 90.0) * t) / 255.0,
			(112.0 + (174.0 - 112.0) * t) / 255.0
		))] = true
	for color: Color in [
		Color(80.0 / 255.0, 125.0 / 255.0, 141.0 / 255.0),
		Color(105.0 / 255.0, 145.0 / 255.0, 156.0 / 255.0),
		Color(133.0 / 255.0, 173.0 / 255.0, 181.0 / 255.0),
		Color(163.0 / 255.0, 195.0 / 255.0, 200.0 / 255.0),
	]:
		keys[_glass_key(color)] = true
	return keys


func _diff_windows(path_a: String, path_b: String) -> int:
	var image_a: Image = Image.load_from_file(path_a)
	var image_b: Image = Image.load_from_file(path_b)
	if image_a == null or image_b == null:
		return -1
	var glass: Dictionary = _glass_set()
	var changed: int = 0
	for window_x: int in [76, 264, 452]:
		for y: int in range(92, 296):
			for x: int in range(window_x, window_x + 126):
				var pixel_a: Color = image_a.get_pixel(x, y)
				if not glass.has(_glass_key(pixel_a)):
					continue
				if pixel_a != image_b.get_pixel(x, y):
					changed += 1
	return changed


func _depth_only_diff(chapter: Node2D) -> void:
	## Isolate the new Depth layer: hide the new atmosphere and the player,
	## then toggle only the overlay/gate depth strength.  The three window
	## panes must be pixel-identical; the door must change.
	var depth: Node = chapter.get_node_or_null("Depth")
	var gate: Node = chapter.get_node_or_null("MirrorRiftGate")
	var atmosphere: Node = chapter.get_node_or_null("Atmosphere")
	var player: Node2D = chapter.call("get_player") as Node2D
	if depth == null or atmosphere == null or player == null:
		return
	# Hide every animated foreground/gameplay element for this technical
	# pair.  The three windows then contain only the untouched CityBack sky;
	# any difference would have to come from the new Depth layer.
	var hidden: Array[Node] = []
	for path: String in [
		"Props", "GateFirst", "GateSecond", "GateSecondProxy", "CoreBay",
		"CoreCarrier", "MirrorRiftGate", "Boss", "Hazards", "Fx", "Checkpoint",
		"Player", "HUD",
	]:
		var node: Node = chapter.get_node_or_null(path)
		if node != null:
			hidden.append(node)
			node.set("visible", false)
	atmosphere.set("modulate", Color(1.0, 1.0, 1.0, 0.0))
	depth.call("set_strength_for_capture", 0.0)
	if gate != null:
		gate.call("set_depth_strength", 0.0)
	await _wait_process(4)
	await _save(OUT_DIR, "loom_depth_only_before.png")
	depth.call("set_strength_for_capture", 1.0)
	if gate != null:
		gate.call("set_depth_strength", 1.0)
	await _wait_process(4)
	await _save(OUT_DIR, "loom_depth_only_after.png")
	var absolute: String = ProjectSettings.globalize_path(OUT_DIR)
	print("WINDOW_DIFF loom changed=%d" % _diff_windows(
		absolute.path_join("loom_depth_only_before.png"),
		absolute.path_join("loom_depth_only_after.png")
	))
	print("DOOR_DIFF loom changed=%d" % _diff_rect(
		absolute.path_join("loom_depth_only_before.png"),
		absolute.path_join("loom_depth_only_after.png"),
		Rect2i(402, 224, 36, 96)
	))
	for node: Node in hidden:
		node.set("visible", true)
	atmosphere.set("modulate", Color(1.0, 1.0, 1.0, 1.0))
	depth.call("set_strength_for_capture", 1.0)
	if gate != null:
		gate.call("set_depth_strength", 1.0)
	await _wait_process(4)


func _strip(chapter: Node2D, directory: String, static_crop: Rect2i,
		label: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(absolute)
	var previous_ticks: int = Time.get_ticks_msec()
	for index: int in range(STRIP_TIMES.size()):
		if index > 0:
			var target_ms: int = previous_ticks + 200
			while Time.get_ticks_msec() < target_ms:
				await get_tree().process_frame
			previous_ticks += 200
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(absolute.path_join("%02d_%.1f.png" % [index, STRIP_TIMES[index]]))
	print("STRIP %s frames=%d" % [label, STRIP_TIMES.size()])
	# The crop is a wall/deep-layer area with no moving atmosphere.  Any
	# sub-pixel layer jitter would show up as changed pixels.
	var path_a: String = absolute.path_join("00_0.0.png")
	var path_b: String = absolute.path_join("01_0.2.png")
	var image_a: Image = Image.load_from_file(path_a)
	var image_b: Image = Image.load_from_file(path_b)
	var changed: int = -1
	if image_a != null and image_b != null:
		var crop_a: Image = image_a.get_region(static_crop)
		var crop_b: Image = image_b.get_region(static_crop)
		changed = 0
		for y: int in range(crop_a.get_height()):
			for x: int in range(crop_a.get_width()):
				if crop_a.get_pixel(x, y) != crop_b.get_pixel(x, y):
					changed += 1
	print("STATIC_DIFF %s crop=%s changed=%d" % [label, str(static_crop), changed])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var rift_packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if rift_packed != null:
		var rift: Node2D = _setup_chapter(rift_packed)
		await _wait_process(6)
		await _pose(rift, 660.0, 280.0)
		await _before_after(rift, "Background/DepthOverlay",
			"rift_before_arch.png", "rift_after_arch.png")
		await _strip(rift, STRIP_RIFT, RIFT_STATIC_CROP, "rift")
		await _pose(rift, 200.0, 320.0, false)
		await _before_after(rift, "Background/DepthOverlay",
			"rift_before_forge.png", "rift_after_forge.png")
		await _strip(rift, "res://screenshots/depth_indoor_20261128/strip_rift_forge",
			Rect2i(200, 100, 200, 160), "rift_forge")
		rift.queue_free()
		await _wait_process(16)
		get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(6)

	var loom_packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if loom_packed != null:
		var loom: Node2D = _setup_chapter(loom_packed)
		await _wait_process(6)
		await _pose(loom, 320.0, 320.0, false)
		await _before_after(loom, "Depth",
			"loom_before_windows.png", "loom_after_windows.png")
		await _depth_only_diff(loom)
		await _strip(loom, STRIP_LOOM, LOOM_STATIC_CROP, "loom")
		await _pose(loom, 400.0, 320.0, false)
		await _before_after(loom, "Depth",
			"loom_before_loom.png", "loom_after_loom.png")
		await _strip(loom, "res://screenshots/depth_indoor_20261128/strip_loom_dust",
			Rect2i(430, 100, 100, 160), "loom_dust")
		# Central loom-apose close-up.  Freeze the chapter logic so placing
		# the camera at x=680 does not start the boss fight; the dormant loom
		# art stays visible.
		await _pose(loom, 680.0, 320.0, false, true)
		await _before_after(loom, "Depth",
			"loom_niche_before.png", "loom_niche_after.png")
		var niche_dir: String = ProjectSettings.globalize_path(OUT_DIR)
		print("NICHE_DIFF loom changed=%d" % _diff_rect(
			niche_dir.path_join("loom_niche_before.png"),
			niche_dir.path_join("loom_niche_after.png"),
			Rect2i(240, 66, 240, 234)
		))
		loom.queue_free()
		await _wait_process(16)
		get_tree().current_scene = null
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	await _wait_process(6)
