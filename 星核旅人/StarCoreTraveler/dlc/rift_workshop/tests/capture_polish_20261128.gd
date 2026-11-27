extends Node

## 640x360 evidence for the 2026-11-28 DLC2 opening polish.
##
## Run WITHOUT --headless (the real viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/rift_workshop/tests/capture_polish_20261128.tscn
##
## Six keyframes include two frames 0.20 s apart inside the held shot.  The
## held pair is compared on a wall-only crop: any camera/layer shimmer makes
## that crop differ.  A 0.20 s strip is also written to tests/out for the
## contact sheet.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/boss_intro_polish_20261128"
const STRIP_DIR: String = "res://dlc/rift_workshop/tests/out/polish_20261128_rift"
const STATIC_CROP: Rect2i = Rect2i(1240, 80, 160, 200)
const FRAMES: Array = [
	[1.12, "rift_01_pupil_contraction_chain.png"],
	[1.62, "rift_02_eye_open.png"],
	[1.96, "rift_03_rim_sweep_plates.png"],
	[2.36, "rift_04_phase_wave.png"],
	[3.06, "rift_05_static_a.png"],
	[3.26, "rift_06_static_b.png"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("RIFT_POLISH_CAPTURE done dir=%s" % OUT_DIR)
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
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		printerr("RIFT_POLISH_CAPTURE missing scene")
		return
	var rift: RiftWorkshop = packed.instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(6)

	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	if cine == null:
		printerr("RIFT_POLISH_CAPTURE missing film")
		return

	for entry: Array in FRAMES:
		cine.set_time_for_capture(float(entry[0]))
		await _wait_process(2)
		await _save(OUT_DIR, String(entry[1]))

	# Static pair read-out and wall-crop diff.
	cine.set_time_for_capture(3.06)
	await _wait_process(2)
	var cam_a: Vector2 = cine.get_opening_camera().global_position
	var layers_a: Dictionary = cine.get_world_layer_positions()
	var anchors_a: PackedVector2Array = cine.get_overlay_anchor_screen_points()
	cine.set_time_for_capture(3.26)
	await _wait_process(2)
	var cam_b: Vector2 = cine.get_opening_camera().global_position
	var layers_b: Dictionary = cine.get_world_layer_positions()
	var anchors_b: PackedVector2Array = cine.get_overlay_anchor_screen_points()
	print("STATIC_CAM A=%s B=%s delta=%.3f" % [
		str(cam_a), str(cam_b), (cam_b - cam_a).length()
	])
	print("STATIC_LAYERS equal=%s" % str(layers_a == layers_b))
	print("STATIC_ANCHORS equal=%s count=%d" % [
		str(anchors_a == anchors_b), anchors_a.size()
	])
	print("CHAIN_SWAY at_1.12=%d at_3.06=%d at_3.26=%d" % [
		cine.get_chain_sway_at(1.12),
		cine.get_chain_sway_at(3.06),
		cine.get_chain_sway_at(3.26),
	])
	print("PUPIL scale_1.12=%.2f scale_1.36=%.2f scale_1.96=%.2f" % [
		cine.get_pupil_scale_at(1.12),
		cine.get_pupil_scale_at(1.36),
		cine.get_pupil_scale_at(1.96),
	])
	var a_path: String = ProjectSettings.globalize_path(OUT_DIR) \
		.path_join("rift_05_static_a.png")
	var b_path: String = ProjectSettings.globalize_path(OUT_DIR) \
		.path_join("rift_06_static_b.png")
	print("STATIC_CROP_DIFF rift pixels=%d" % _diff_crop(a_path, b_path))

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
	print("STRIP_FRAMES rift count=%d" % index)

	cine.finish_capture()
	await _wait_process(40)
	print("HANDOFF rift hud_visible=%s player_x=%.1f camera=%s" % [
		str(rift.get_hud().visible),
		rift.get_player().global_position.x,
		str(get_viewport().get_camera_2d().get_screen_center_position()),
	])
	rift.queue_free()
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
