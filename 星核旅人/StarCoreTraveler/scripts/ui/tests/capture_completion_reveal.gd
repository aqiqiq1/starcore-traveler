extends Node

## 640x360 evidence for the base completion page reveal. Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_completion_reveal.tscn
##
## Saves a mid-open frame (0.18 s tween still running) and the settled page for
## level 02 and level 03. Real viewport captures, not mockups.

const OUT_DIR: String = "res://scripts/ui/tests/out"
const CASES: Array[Array] = [
	["res://scenes/level_02.tscn", "l2"],
	["res://scenes/level_03.tscn", "l3"],
]

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for entry: Array in CASES:
		await _capture(String(entry[0]), String(entry[1]))
	print("COMPLETION_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _capture(scene_path: String, tag: String) -> void:
	var level: Node = (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	for _index: int in range(10):
		await get_tree().process_frame
	var hud: Node = level.get_node_or_null("HUD")
	if hud == null:
		print("COMPLETION_CAPTURE missing HUD in %s" % scene_path)
		level.queue_free()
		return
	hud.call("show_completion", true, 1)
	# Two frames in: the dimmer is partially faded and the panel is still shy
	# of its rest scale, which is the frame a player actually perceives.
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("%s_completion_mid" % tag)
	await get_tree().create_timer(0.35, true).timeout
	await _save("%s_completion_settled" % tag)
	hud.call("show_completion", false)
	await get_tree().process_frame
	get_tree().current_scene = null
	level.queue_free()
	for _index: int in range(6):
		await get_tree().process_frame


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(shot_name + ".png"))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])
