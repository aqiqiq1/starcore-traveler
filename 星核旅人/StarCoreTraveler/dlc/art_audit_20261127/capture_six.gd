extends Node

## 640x360 six-chapter art audit capture.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 40,40 \
##     res://dlc/art_audit_20261127/capture_six.tscn -- <out_dir_name>
##
## Each shot is the live viewport (including HUD).  The run only moves the
## player and disables intro guides/tips; no gameplay state is forced.

const OUT_ROOT: String = "res://screenshots/art_audit_20261127"

var _out_dir: String = OUT_ROOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = OUT_ROOT.path_join(args[0])
	await get_tree().process_frame
	await _run()
	print("ART_AUDIT_CAPTURE done dir=%s" % _out_dir)
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(_out_dir)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [name, image.get_width(), image.get_height(), error])


func _shot(
	scene_path: String, file_name: String, player_path: String,
	player_pos: Vector2, disable_menu: bool = false
) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("SHOT %s MISSING_SCENE %s" % [file_name, scene_path])
		return
	var level: Node = packed.instantiate()
	if level.has_method("set"):
		level.set("show_intro_guide", false)
		level.set("show_intro_cinematic", false)
		level.set("show_mechanic_tips", false)
		if disable_menu:
			level.set("enable_start_menu", false)
	add_child(level)
	await _wait_process(4)
	# First-level opening film and L2 mechanic popup are not part of the
	# background/terrain review; remove their screen chrome for a clean shot.
	var opening: Node = level.get_node_or_null("OpeningCinematic")
	if opening != null and opening.has_method("abort"):
		opening.call("abort")
	var popup: Node = level.get_node_or_null("MechanicPopup")
	if popup != null:
		popup.queue_free()
	await _wait_process(4)
	var player: Node2D = level.get_node_or_null(player_path) as Node2D
	if player != null:
		player.global_position = player_pos
		if player.has_method("set"):
			player.set("velocity", Vector2.ZERO)
	var camera: Camera2D = null
	if player != null:
		camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()
	await get_tree().create_timer(0.5, true).timeout
	await _wait_process(3)
	await _save(file_name)
	level.queue_free()
	await _wait_process(8)


func _run() -> void:
	await _shot("res://scenes/level_01.tscn", "level_01.png", "World/Player", Vector2(320, 300), true)
	await _shot("res://scenes/level_02.tscn", "level_02.png", "Player", Vector2(940, 320))
	await _shot("res://scenes/level_03.tscn", "level_03.png", "Player", Vector2(2250, 320))
	await _shot("res://dlc/trial_chambers/trial_chambers.tscn", "dlc_01_trial.png", "Player", Vector2(190, 320))
	await _shot("res://dlc/rift_workshop/rift_workshop.tscn", "dlc_02_rift.png", "Player", Vector2(740, 280))
	await _shot("res://dlc/star_loom/star_loom.tscn", "dlc_03_loom.png", "Player", Vector2(480, 320))
