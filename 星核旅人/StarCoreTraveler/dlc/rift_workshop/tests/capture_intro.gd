extends Node

## 640x360 evidence for the DLC2 opening rework (2026-11-27).
##
## Run WITHOUT --headless (the real viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/rift_workshop/tests/capture_intro.tscn
##
## The harness owns a real RiftWorkshop, freezes the real film at four beats,
## then finishes it once so the fifth frame is the actual control hand-off:
##   mirror hall wide (eye closed) -> eye open -> both plates lit ->
##   pulled back to the player -> HUD/control returned.
##
## No debug camera or painted substitute is used.  The only capture-only helper
## is RiftIntroCinematic.set_time_for_capture(), which moves the real camera and
## overlays on the live scene.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://screenshots/rift_opening_20261127"
const FRAMES: Array = [
	[0.00, "00_first_frame.png"],
	[0.72, "01_mirror_hall_wide.png"],
	[1.55, "02_eye_open.png"],
	[1.95, "03_plates_lit.png"],
	[2.35, "03b_phase_wave.png"],
	[3.82, "04_pull_to_player.png"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("RIFT_OPENING_CAPTURE done dir=%s" % OUT_DIR)
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
		name, str(_last_capture_time), image.get_width(), image.get_height(), error
	])


var _last_capture_time: String = ""


func _run() -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		printerr("RIFT_OPENING_CAPTURE missing scene")
		return
	var rift: RiftWorkshop = packed.instantiate() as RiftWorkshop
	rift.show_intro_guide = false
	rift.show_intro_cinematic = true
	add_child(rift)
	await _wait_process(6)

	var cine: RiftIntroCinematic = rift.get_intro_cinematic()
	if cine == null:
		printerr("RIFT_OPENING_CAPTURE missing film")
		return

	for entry: Array in FRAMES:
		_last_capture_time = "%.2f s" % float(entry[0])
		cine.set_time_for_capture(float(entry[0]))
		await _wait_process(2)
		await _save(String(entry[1]))

	# Real hand-off: the director emits finished, the chapter re-enables the
	# player camera, unlocks control and fades the HUD in.  Wait past the 0.35 s
	# fade so the evidence shows the delivered HUD, not a translucent first frame.
	_last_capture_time = "hand-off"
	cine.finish_capture()
	await _wait_process(60)
	await _save("05_control_returned.png")

	rift.queue_free()
	await _wait_process(8)
