extends Node

## 640x360 evidence for the six-chapter pause/completion alignment.
## Run WITHOUT --headless (the viewport must actually render):
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://scripts/ui/tests/capture_pause_completion.tscn
##
## Saves five real viewport captures:
##   dlc1_pause_controls.png   DLC1 操作 table inside the pause panel
##   dlc2_pause_controls.png   DLC2 操作 table inside the pause panel
##   dlc3_pause_controls.png   DLC3 操作 table inside the pause panel
##   base_l1_completion.png    L1 completion with 用时 mm:ss
##   dlc2_completion.png       DLC2 completion with 用时 mm:ss
##
## Completion progress is written to throwaway user files, never the real
## chapter_progress.cfg.

const OUT_DIR: String = "res://screenshots/pause_completion_20261127"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const TRIAL: String = "res://dlc/trial_chambers/trial_chambers.tscn"
const RIFT: String = "res://dlc/rift_workshop/rift_workshop.tscn"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const P_CAP: String = "user://pause_completion_capture.cfg"

var _saved: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	_cleanup_progress()
	print("PAUSE_COMPLETION_CAPTURE saved=%d files=%s" % [
		_saved.size(), ", ".join(_saved)
	])
	get_tree().quit(0 if _saved.size() == 5 else 1)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _has_property(object: Object, property_name: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false


func _load(
	path: String, no_menu: bool, no_intro: bool, progress_path: String = ""
) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var level: Node = packed.instantiate() if packed != null else null
	if level == null:
		return null
	if no_menu and _has_property(level, "enable_start_menu"):
		level.set("enable_start_menu", false)
	if no_intro:
		for property_name: String in [
			"show_intro_guide", "show_intro_cinematic", "show_mechanic_tips",
		]:
			if _has_property(level, property_name):
				level.set(property_name, false)
	if not progress_path.is_empty() and _has_property(level, "chapter_progress_path"):
		level.set("chapter_progress_path", progress_path)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(8)
	return level


func _cleanup(level: Node) -> void:
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	get_tree().paused = false
	get_tree().current_scene = null
	if is_instance_valid(level):
		level.queue_free()
	await _wait_process(10)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(directory.path_join(shot_name))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])


func _capture_pause(path: String, shot_name: String) -> void:
	var level: Node = await _load(path, false, true)
	if level == null:
		push_error("Could not load " + path)
		return
	level.call("_set_paused", true)
	await _wait_process(4)
	await _wait_seconds(0.30)
	var hud: Node = level.get_node("HUD")
	var controls: PixelMenuButton = hud.call(
		"get_pause_controls_button"
	) as PixelMenuButton
	if controls != null:
		controls.pressed.emit()
	await _wait_process(3)
	await _wait_seconds(0.12)
	await _save(shot_name)
	# Close the table and the pause page before the next scene.
	var back: PixelMenuButton = hud.call(
		"get_pause_controls_back_button"
	) as PixelMenuButton
	if back != null:
		back.pressed.emit()
	await _wait_process(2)
	level.call("_set_paused", false)
	await _wait_process(2)
	await _cleanup(level)


func _capture_l1_completion() -> void:
	var level: Node = await _load(LEVEL_01, true, false, P_CAP)
	if level == null:
		push_error("Could not load level_01")
		return
	level.call("_finish_intro")
	await _wait_process(10)
	await _wait_seconds(1.4)
	level.call("_on_exit_reached")
	await _wait_seconds(0.40)
	await _save("base_l1_completion.png")
	await _cleanup(level)


func _capture_rift_completion() -> void:
	var level: Node = await _load(RIFT, false, true, P_CAP)
	if level == null:
		push_error("Could not load rift_workshop")
		return
	await _wait_seconds(1.4)
	level.call("_complete_chapter")
	await _wait_seconds(0.40)
	await _save("dlc2_completion.png")
	await _cleanup(level)


func _run() -> void:
	await _capture_pause(TRIAL, "dlc1_pause_controls.png")
	await _capture_pause(RIFT, "dlc2_pause_controls.png")
	await _capture_pause(LOOM, "dlc3_pause_controls.png")
	await _capture_l1_completion()
	await _capture_rift_completion()


func _cleanup_progress() -> void:
	get_tree().paused = false
	var absolute_path: String = ProjectSettings.globalize_path(P_CAP)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
