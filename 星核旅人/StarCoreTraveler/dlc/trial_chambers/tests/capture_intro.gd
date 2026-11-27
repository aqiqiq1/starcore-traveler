extends Node

## 640x360 evidence for the DLC1 opening rework (2026-11-27).
##
## Run WITHOUT --headless (the real viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/trial_chambers/tests/capture_intro.tscn
##
## The harness owns a real TrialChambers, freezes the real film at four beats,
## then finishes it once so the fifth frame is the actual control hand-off.  The
## sixth frame is the same gate in ordinary gameplay, for the "is this the level
## door?" check.  No debug camera or painted substitute is used.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT_DIR: String = "res://screenshots/trial_opening_20261127"
const FRAMES: Array = [
	[0.55, "00_two_gates_real_wide.png"],
	[1.62, "01_gold_crystal_and_two_doors.png"],
	[2.30, "02_seam_light_pool.png"],
	[3.22, "03_pull_to_player.png"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(640, 360))
	await get_tree().process_frame
	await _run()
	print("TRIAL_OPENING_CAPTURE done dir=%s" % OUT_DIR)
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
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	if packed == null:
		printerr("TRIAL_OPENING_CAPTURE missing scene")
		return
	var trial: TrialChambers = packed.instantiate() as TrialChambers
	trial.show_intro_guide = false
	trial.show_intro_cinematic = true
	add_child(trial)
	await _wait_process(6)

	var cine: TrialIntroCinematic = trial.get_intro_cinematic()
	if cine == null:
		printerr("TRIAL_OPENING_CAPTURE missing film")
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
	await _save("04_control_returned.png")

	# Ordinary gameplay framing of the same real gate: move the player to the
	# gate approach and let the real player camera settle.  This is a test-only
	# teleport, not a change to the level's rules or route.
	var player: L3Player = trial.get_player()
	player.global_position = Vector2(245.0, 320.0)
	player.velocity = Vector2.ZERO
	trial.get_camera().reset_smoothing()
	await _wait_process(30)
	_last_capture_time = "same gate in gameplay"
	await _save("05_same_gate_in_gameplay.png")

	trial.queue_free()
	await _wait_process(8)
