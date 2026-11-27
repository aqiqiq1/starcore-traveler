extends Node

## Continuous 0.2 s sampling of the DLC3 opening film, used to check the camera
## path and the lamp/core beats across the whole 4.0 s.  Run WITHOUT --headless:
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/star_loom/tests/capture_intro_strip.tscn
## The PNGs are written to tests/out/loom_opening_strip/ (a .gdignore folder).

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out/loom_opening_strip"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		printerr("LOOM_STRIP missing scene")
		return
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(6)
	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	if cine == null:
		printerr("LOOM_STRIP missing film")
		return

	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var index: int = 0
	var t: float = 0.0
	while t <= 4.001:
		cine.set_time_for_capture(t)
		await _wait_process(2)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = directory.path_join("%02d_%.1f.png" % [index, t])
		image.save_png(path)
		print("STRIP %s size=%dx%d center=%s zoom=%.2f" % [
			path, image.get_width(), image.get_height(),
			str(cine.get_camera_center()), cine.get_camera_zoom()
		])
		index += 1
		t += 0.2
	loom.queue_free()
	await _wait_process(8)
