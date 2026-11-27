extends Node

## 640x360 before/after evidence for the DLC2 interior pass (2026-11-27).
## Run WITHOUT --headless (the live viewport is 640x360):
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/rift_workshop/tests/capture_interior_20261127.tscn -- before
##
## The optional user argument is the subfolder under
## res://screenshots/rift_interior_20261127/ (before / after).  The three
## camera positions are the same in both runs:
##   start.png  entry / inversion curtain
##   mid.png    low iron beams + phase bridges
##   boss.png   mirror hall arena
##
## The harness only hides the intro guide / opening film and moves the player.
## It never changes gameplay state or the boss.

const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_ROOT: String = "res://screenshots/rift_interior_20261127"

var _out_dir: String = OUT_ROOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = OUT_ROOT.path_join(args[0])
	await get_tree().process_frame
	await _run()
	print("RIFT_INTERIOR_CAPTURE done dir=%s" % _out_dir)
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(_out_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _shot(name: String, player_pos: Vector2, settle_frames: int) -> void:
	var packed: PackedScene = load(RIFT_SCENE) as PackedScene
	if packed == null:
		print("RIFT_INTERIOR_CAPTURE missing scene")
		return
	var rift: Node = packed.instantiate()
	rift.set("show_intro_guide", false)
	rift.set("show_intro_cinematic", false)
	rift.set("show_mechanic_tips", false)
	add_child(rift)
	await _wait_process(4)
	var player: Node2D = rift.get_node_or_null("Player") as Node2D
	if player != null:
		player.global_position = player_pos
		player.set("velocity", Vector2.ZERO)
		if player.has_method("cancel_attack"):
			player.call("cancel_attack")
	var camera: Camera2D = null
	if rift.has_method("get_camera"):
		camera = rift.call("get_camera") as Camera2D
	if camera == null and player != null:
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await _wait_physics(settle_frames)
	await _wait_process(settle_frames)
	await _save(name)
	rift.queue_free()
	await _wait_process(8)


func _run() -> void:
	# Entry: the player stands on the starting floor in front of the violet
	# inversion curtain; the camera is clamped to the left edge (0..640).
	await _shot("start.png", Vector2(40.0, 320.0), 14)
	# Mid: low beams (552..1040 at y211..223) and the three phase bridges.
	# Landing A spans 752..800, so this is a legal standing spot.
	await _shot("mid.png", Vector2(780.0, 280.0), 20)
	# Boss: the mirror hall arena; the camera is at 1220..1860 and the boss
	# hovers at 1540,260.  The player stands left of the boss.
	await _shot("boss.png", Vector2(1430.0, 320.0), 30)
