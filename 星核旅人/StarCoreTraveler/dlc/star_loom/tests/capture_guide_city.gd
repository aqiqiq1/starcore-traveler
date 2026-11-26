extends Node

## 640x360 evidence for the two city intro-guide pages.
## Run WITHOUT --headless:
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/star_loom/tests/capture_guide_city.tscn
##
## Saves out/guide_city_1..2.png.  The guide is the real shared
## dlc/ui/dlc_guide.tscn opened by the formal chapter; F advances the pages and
## the demo strips are the real 24-frame captures in dlc/ui/demos/.

const LOOM_SCENE: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://dlc/star_loom/tests/out"

var _loom: StarLoom


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()
	await _cleanup()
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _push_key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code as Key
	event.keycode = code as Key
	event.pressed = pressed
	get_viewport().push_input(event)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(name))
	print("SHOT %s size=%dx%d error=%d" % [
		name, image.get_width(), image.get_height(), error
	])


func _run() -> void:
	var packed: PackedScene = load(LOOM_SCENE) as PackedScene
	if packed == null:
		print("LOOM_GUIDE_CAPTURE missing scene")
		return
	_loom = packed.instantiate() as StarLoom
	_loom.show_intro_guide = true
	_loom.show_intro_cinematic = false
	get_tree().root.add_child(_loom)
	get_tree().current_scene = _loom
	for _index: int in range(120):
		var guide: DlcGuide = _loom.get_intro_guide()
		if guide != null and is_instance_valid(guide) and guide.is_open():
			break
		await get_tree().process_frame
	await _wait_process(12)
	await _save("guide_city_1.png")
	for page in range(2, 3):
		_push_key(KEY_F, true)
		await _wait_process(3)
		_push_key(KEY_F, false)
		await _wait_process(8)
		await _save("guide_city_%d.png" % page)
	_push_key(KEY_SPACE, true)
	for _index: int in range(600):
		var guide: DlcGuide = _loom.get_intro_guide()
		if guide == null or not guide.is_open():
			break
		await get_tree().process_frame
	_push_key(KEY_SPACE, false)
	await _wait_process(4)


func _cleanup() -> void:
	get_tree().paused = false
	if _loom != null and is_instance_valid(_loom):
		_loom.queue_free()
		_loom = null
	await _wait_process(8)
