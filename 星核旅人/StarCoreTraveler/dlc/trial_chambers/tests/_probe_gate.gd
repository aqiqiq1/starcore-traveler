extends Node

const SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT: String = "res://screenshots/_probe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	var trial: TrialChambers = (load(SCENE) as PackedScene).instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = false
	add_child(trial)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam: Camera2D = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1280
	cam.limit_bottom = 360
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()
	for entry: Array in [
		[280.0, 245.0, 1.6, "gate"],
		[300.0, 220.0, 1.35, "gate_wide"],
		[320.0, 180.0, 1.0, "play"],
	]:
		cam.global_position = Vector2(float(entry[0]), float(entry[1]))
		cam.zoom = Vector2(float(entry[2]), float(entry[2]))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		image.save_png(ProjectSettings.globalize_path(OUT).path_join(String(entry[3]) + ".png"))
		print("PROBE %s" % entry[3])
	get_tree().quit(0)
