extends Node

## 640x360 evidence for the 2026-11-28 DLC3 opening polish.
##
## Run WITHOUT --headless (the real viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/star_loom/tests/capture_polish_20261128.tscn
##
## Six keyframes include two frames 0.20 s apart inside the held shot.  The
## held pair is compared on a wall-only crop: any camera/layer shimmer makes
## that crop differ.  A 0.20 s strip is also written to tests/out for the
## contact sheet.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/boss_intro_polish_20261128"
const STRIP_DIR: String = "res://dlc/star_loom/tests/out/polish_20261128_loom"
## Left wall/window only: world x 459-550, safely before the left gear, lamp
## rails, dust cones and loom.  Nothing in this crop animates.
const STATIC_CROP: Rect2i = Rect2i(40, 40, 100, 280)
const FRAMES: Array = [
	[1.70, "loom_01_lamp_rows_gears_idle.png"],
	[2.06, "loom_02_gear_spin_shuttle_sparks.png"],
	[2.62, "loom_03_core_pulse.png"],
	[3.08, "loom_04_static_a.png"],
	[3.28, "loom_05_static_b.png"],
	[4.42, "loom_06_pull_to_player.png"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("LOOM_POLISH_CAPTURE done dir=%s" % OUT_DIR)
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


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		printerr("LOOM_POLISH_CAPTURE missing scene")
		return
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(6)

	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	if cine == null:
		printerr("LOOM_POLISH_CAPTURE missing film")
		return

	for entry: Array in FRAMES:
		cine.set_time_for_capture(float(entry[0]))
		await _wait_process(2)
		await _save(OUT_DIR, String(entry[1]))

	# Static pair read-out and wall-crop diff.  The crop contains no lamp,
	# gear, core or dust pixels, so a zero diff is a camera/layer stability
	# proof, not a claim that the intentional overlays are frozen.
	cine.set_time_for_capture(3.08)
	await _wait_process(2)
	var cam_a: Vector2 = cine.get_opening_camera().global_position
	var layers_a: Dictionary = cine.get_world_overlay_positions()
	var anchors_a: PackedVector2Array = cine.get_overlay_anchor_screen_points()
	cine.set_time_for_capture(3.28)
	await _wait_process(2)
	var cam_b: Vector2 = cine.get_opening_camera().global_position
	var layers_b: Dictionary = cine.get_world_overlay_positions()
	var anchors_b: PackedVector2Array = cine.get_overlay_anchor_screen_points()
	print("STATIC_CAM A=%s B=%s delta=%.3f" % [
		str(cam_a), str(cam_b), (cam_b - cam_a).length()
	])
	print("STATIC_LAYERS equal=%s" % str(layers_a == layers_b))
	print("STATIC_ANCHORS equal=%s count=%d" % [
		str(anchors_a == anchors_b), anchors_a.size()
	])
	var a_path: String = ProjectSettings.globalize_path(OUT_DIR) \
		.path_join("loom_04_static_a.png")
	var b_path: String = ProjectSettings.globalize_path(OUT_DIR) \
		.path_join("loom_05_static_b.png")
	print("STATIC_CROP_DIFF loom pixels=%d" % _diff_crop(a_path, b_path))

	# 0.20 s strip for the contact sheet.
	var strip_absolute: String = ProjectSettings.globalize_path(STRIP_DIR)
	DirAccess.make_dir_recursive_absolute(strip_absolute)
	var index: int = 0
	var t: float = 0.0
	while t <= 4.401:
		cine.set_time_for_capture(t)
		await _wait_process(1)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(strip_absolute.path_join("%02d_%.1f.png" % [index, t]))
		print("STRIP %.1f cam=%s zoom=%.3f" % [
			t, str(cine.get_opening_camera().global_position),
			cine.get_camera_zoom()
		])
		index += 1
		t += 0.2
	print("STRIP_FRAMES loom count=%d" % index)

	cine.finish_capture()
	await _wait_process(40)
	print("HANDOFF loom hud_visible=%s player_x=%.1f camera=%s" % [
		str(loom.get_hud().visible),
		loom.get_player().global_position.x,
		str(get_viewport().get_camera_2d().get_screen_center_position()),
	])
	loom.queue_free()
	await _wait_process(8)


func _diff_crop(path_a: String, path_b: String) -> int:
	var image_a: Image = Image.load_from_file(path_a)
	var image_b: Image = Image.load_from_file(path_b)
	if image_a == null or image_b == null:
		return -1
	var crop_a: Image = image_a.get_region(STATIC_CROP)
	var crop_b: Image = image_b.get_region(STATIC_CROP)
	var changed: int = 0
	for y: int in range(crop_a.get_height()):
		for x: int in range(crop_a.get_width()):
			if crop_a.get_pixel(x, y) != crop_b.get_pixel(x, y):
				changed += 1
	return changed
