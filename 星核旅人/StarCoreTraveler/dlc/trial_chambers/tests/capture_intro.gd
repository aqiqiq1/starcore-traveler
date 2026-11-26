extends Node

## 640x360 stills of the DLC1 opening film at three readable beats.  The film
## draws its whole composition itself, so this harness does not instantiate the
## chapter (and therefore does not depend on the concurrently-refactored HUD).
##   ... --path . --position 60,60 res://dlc/trial_chambers/tests/capture_intro.tscn

const FILM: String = "res://dlc/trial_chambers/trial_intro_cinematic.tscn"
const OUT_DIR: String = "res://dlc/trial_chambers/tests/out"
const FRAMES: Array = [
	[0.52, "intro_crystal_gold"],
	[1.02, "intro_crystals"],
	[1.64, "intro_lock"],
	[2.34, "intro_light_pullback"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var cine: DlcIntroCinematic = (load(FILM) as PackedScene).instantiate() as DlcIntroCinematic
	if cine == null:
		printerr("CAPTURE_TRIAL missing film")
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
		print("CAPTURE_TRIAL %s time=%.2f size=%dx%d" % [
			path, float(entry[0]), image.get_width(), image.get_height()
		])
	cine.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
