extends Node

## 640x360 page captures for the shared DLC guide.  Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/ui/tests/capture_guide.tscn
##
## Saves dlc/ui/tests/out/trial_guide_1..3.png and rift_guide_1..3.png.
## The guide itself pauses the tree; each page is a real live viewport shot.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT_SCENE: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const OUT_DIR: String = "res://dlc/ui/tests/out"

var _level: Node
var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("DLC_GUIDE_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
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


func _tap_f() -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = KEY_F
	down.keycode = KEY_F
	down.pressed = true
	get_viewport().push_input(down)
	await _wait_process(2)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = KEY_F
	up.keycode = KEY_F
	up.pressed = false
	get_viewport().push_input(up)
	await _wait_process(4)


func _capture_chapter(path: String, prefix: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	_level = packed.instantiate()
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(8)
	var guide: DlcGuide = null
	if _level.has_method("get_intro_guide"):
		guide = _level.call("get_intro_guide") as DlcGuide
	if guide == null or not guide.is_open():
		print("CAPTURE_FAIL %s guide not open" % prefix)
		return
	await _save("%s_guide_1.png" % prefix)
	await _tap_f()
	await _save("%s_guide_2.png" % prefix)
	await _tap_f()
	await _save("%s_guide_3.png" % prefix)
	await _tap_f()
	await _wait_process(4)
	get_tree().current_scene = null
	_level.queue_free()
	_level = null
	await _wait_process(8)


func _run() -> void:
	await _capture_chapter(TRIAL_SCENE, "trial")
	await _capture_chapter(RIFT_SCENE, "rift")
