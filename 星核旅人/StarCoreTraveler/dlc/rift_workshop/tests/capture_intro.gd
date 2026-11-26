extends Node

## 640x360 stills of the DLC2 opening film at three readable beats.
##   ... --path . --position 60,60 res://dlc/rift_workshop/tests/capture_intro.tscn

const FILM: String = "res://dlc/rift_workshop/rift_intro_cinematic.tscn"
const OUT_DIR: String = "res://dlc/rift_workshop/tests/out"
const FRAMES: Array = [
	[0.64, "intro_eye_closed"],
	[1.18, "intro_eye_opening"],
	[1.78, "intro_eye_open"],
	[2.42, "intro_plates_wave"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var cine: DlcIntroCinematic = (load(FILM) as PackedScene).instantiate() as DlcIntroCinematic
	if cine == null:
		printerr("CAPTURE_RIFT missing film")
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
		print("CAPTURE_RIFT %s time=%.2f size=%dx%d" % [
			path, float(entry[0]), image.get_width(), image.get_height()
		])
	cine.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
