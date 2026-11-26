extends Node

## 640x360 stills of the DLC3 opening film at three readable beats.
##   ... --path . --position 60,60 res://dlc/star_loom/tests/capture_intro.tscn

const FILM: String = "res://dlc/star_loom/loom_intro_cinematic.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out"
const FRAMES: Array = [
	[0.52, "intro_lamp_row_1"],
	[0.82, "intro_lamp_row_2"],
	[1.04, "intro_lamps"],
	[1.62, "intro_shuttle"],
	[2.74, "intro_core"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var cine: DlcIntroCinematic = (load(FILM) as PackedScene).instantiate() as DlcIntroCinematic
	if cine == null:
		printerr("CAPTURE_LOOM missing film")
		get_tree().quit(1)
		return
	add_child(cine)
	cine.start()
	await get_tree().process_frame
	await get_tree().process_frame
	for entry: Array in FRAMES:
		cine.set_time_for_capture(float(entry[0]))
		await get_tree().process_frame
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = OUT_DIR + "/" + String(entry[1]) + ".png"
		image.save_png(path)
		print("CAPTURE_LOOM %s time=%.2f size=%dx%d" % [
			path, float(entry[0]), image.get_width(), image.get_height()
		])
	cine.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
