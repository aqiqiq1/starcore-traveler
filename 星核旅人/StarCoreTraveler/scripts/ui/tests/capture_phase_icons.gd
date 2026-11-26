extends Node

## 640x360 evidence for the base-level phase badge.  Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_phase_icons.tscn
##
## Saves one start-state shot per level plus one moon-update shot from level 02
## into scripts/ui/tests/out/.  The shots come from the real viewport, not a
## mockup.

const CASES: Array[Array] = [
	["res://scenes/level_01.tscn", "level01"],
	["res://scenes/level_02.tscn", "level02"],
	["res://scenes/level_03.tscn", "level03"],
]
const OUT_DIR: String = "res://scripts/ui/tests/out"

var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for entry: Array in CASES:
		await _capture_case(String(entry[0]), String(entry[1]))
	print("PHASE_ICON_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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
	_saved.append(name)
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _capture_case(scene_path: String, tag: String) -> void:
	var level: Node = (load(scene_path) as PackedScene).instantiate()
	if tag == "level01":
		level.set("enable_start_menu", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(10)
	if tag == "level01":
		level.call("_finish_intro")
		await _wait_process(8)

	await _save("base_phase_%s_sun.png" % tag)
	if tag == "level02":
		var player: Node = level.call("get_player") as Node
		if player != null:
			player.call("_toggle_polarity")
			await _wait_process(8)
			await _save("base_phase_%s_moon.png" % tag)

	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(8)
