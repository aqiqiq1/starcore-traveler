extends Node

## Trial-only 640x360 copy captures for the three naturalized guide pages.
## Run WITHOUT --headless:
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/trial_chambers/tests/capture_guide_copy.tscn
##
## Saves directly into dlc/trial_chambers/tests/out/ so the evidence does not
## depend on the shared six-page capture, which also loads the rift chapter.

const TRIAL_SCENE: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const OUT_DIR: String = "res://dlc/trial_chambers/tests/out"

var _saved: Array[String] = []
var _level: Node = null


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("TRIAL_GUIDE_COPY_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


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


func _run() -> void:
	var packed: PackedScene = load(TRIAL_SCENE) as PackedScene
	_level = packed.instantiate()
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	await _wait_process(8)
	var guide: DlcGuide = null
	if _level.has_method("get_intro_guide"):
		guide = _level.call("get_intro_guide") as DlcGuide
	if guide == null or not guide.is_open():
		print("CAPTURE_FAIL trial guide not open")
		get_tree().quit(1)
		return
	# Let each page's demo reach a readable action frame.
	await _wait_seconds(1.6)
	await _save("trial_guide_1.png")
	await _tap_f()
	await _wait_seconds(1.6)
	await _save("trial_guide_2.png")
	await _tap_f()
	await _wait_seconds(1.6)
	await _save("trial_guide_3.png")
	await _tap_f()
	await _wait_process(4)
	# Stop the Ogg before quitting so the evidence run has no leak warning.
	var ambience: DlcChapterAmbience = _level.call("get_ambience") as DlcChapterAmbience
	if ambience != null:
		var player: AudioStreamPlayer = ambience.get_player()
		if player != null:
			player.stream = null
		ambience.stop(0.0)
		ambience.set("_stream", null)
	get_tree().current_scene = null
	_level.queue_free()
	await _wait_process(8)
