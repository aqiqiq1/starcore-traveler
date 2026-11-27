extends Node

## 640x360 evidence for the DLC3 opening rework (2026-11-27).
##
## Run WITHOUT --headless (the real viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/star_loom/tests/capture_intro.tscn
##
## The harness owns a real StarLoom, freezes the real film at six beats, then
## finishes it once so the last frame is the actual control hand-off:
##   dark hall/loom silhouette -> first lamp row -> all rows + shuttle ->
##   orbs/core lit -> pulled back to the entrance player -> HUD/control returned.
##
## No debug camera or painted substitute is used.  The only capture-only helper
## is LoomIntroCinematic.set_time_for_capture(), which moves the real
## OpeningCamera2D and the world-space overlays on the live scene.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/loom_opening_20261127"
const FRAMES: Array = [
	[0.60, "00_hall_dark_loom_silhouette.png"],
	[1.38, "01_lamp_row_1.png"],
	[1.82, "02_lamp_rows_all.png"],
	[1.98, "03_lamp_rows_shuttle.png"],
	[2.66, "04_orbs_core_lit.png"],
	[3.92, "05_pull_back_to_player.png"],
]

var _last_capture_time: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("LOOM_OPENING_CAPTURE done dir=%s" % OUT_DIR)
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s time=%s size=%dx%d error=%d" % [
		name, _last_capture_time, image.get_width(), image.get_height(), error
	])


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		printerr("LOOM_OPENING_CAPTURE missing scene")
		return
	var loom: StarLoom = packed.instantiate() as StarLoom
	loom.show_intro_guide = false
	loom.show_intro_cinematic = true
	add_child(loom)
	await _wait_process(6)

	var cine: LoomIntroCinematic = loom.get_intro_cinematic()
	if cine == null:
		printerr("LOOM_OPENING_CAPTURE missing film")
		return

	for entry: Array in FRAMES:
		_last_capture_time = "%.2f s" % float(entry[0])
		cine.set_time_for_capture(float(entry[0]))
		await _wait_process(2)
		await _save(String(entry[1]))

	# Real hand-off: the director emits finished, the chapter re-enables the
	# player camera, unlocks control and fades the HUD in.  Wait past the
	# 0.35 s fade so the evidence shows the delivered HUD, not a translucent
	# first frame.
	_last_capture_time = "hand-off"
	cine.finish_capture()
	# 0.35 s HUD fade plus a settled margin; a frame-count wait is not enough
	# on a high-FPS window.
	await get_tree().create_timer(0.55).timeout
	await _save("06_control_returned.png")

	loom.queue_free()
	await _wait_process(8)
