extends Node

## 640x360 evidence for the 2026-11-28 completion-icon swap.
## Run WITHOUT --headless:
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
##     res://dlc/text_layout_20261128/tests/capture_completion_icon.tscn
##
## Saves to res://screenshots/completion_icon_20261128/:
##   01_mirror_entrance.png   the DLC3 镜面裂隙 entrance is unchanged
##   02_completion_icon.png   real Loom completion page with the game icon
##
## The completion page is opened by the real _complete_chapter() route; the
## entrance frame is the real gate with the player 56 px in front of it.

const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const OUT_DIR: String = "res://screenshots/completion_icon_20261128"
const PROGRESS: String = "user://completion_icon_capture.cfg"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))
	print("COMPLETION_ICON_CAPTURE saved=%d files=%s" % [_saved.size(), ", ".join(_saved)])
	get_tree().quit(0)


func _run() -> void:
	var packed: PackedScene = load(LOOM) as PackedScene
	var level: Node = packed.instantiate()
	level.set("chapter_progress_path", PROGRESS)
	level.set("show_intro_guide", false)
	level.set("show_intro_cinematic", false)
	level.set("show_mechanic_tips", false)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	await _wait_process(10)
	get_tree().paused = false
	var gate: Node2D = level.call("get_hidden_rift_gate") as Node2D
	var player: Node2D = level.call("get_player") as Node2D
	var camera: Camera2D = level.call("get_camera") as Camera2D
	if gate == null or player == null or camera == null:
		print("CAPTURE_FAIL loom objects missing")
		return
	player.global_position = Vector2(gate.global_position.x - 56.0, 320.0)
	player.velocity = Vector2.ZERO
	await _wait_physics(5)
	camera.reset_smoothing()
	await _wait_seconds(0.35)
	print("MIRROR_GATE pos=%s" % str(gate.global_position))
	await _save("01_mirror_entrance.png")
	level.call("_complete_chapter")
	await _wait_seconds(0.60)
	var hud: Node = level.call("get_hud")
	var emblem: CompletionEmblem = hud.find_child(
		"CompletionEmblem", true, false
	) as CompletionEmblem
	print("COMPLETION_ICON path=%s size=%s texture=%s" % [
		emblem.get_texture_path() if emblem != null else "none",
		str(emblem.size) if emblem != null else "none",
		str(emblem.get_texture().get_size()) if emblem != null and emblem.get_texture() != null else "none",
	])
	await _save("02_completion_icon.png")
	var primary: PixelMenuButton = hud.call(
		"get_completion_primary_button"
	) as PixelMenuButton
	if primary != null:
		primary.pressed.emit()
		await _wait_seconds(0.22)
		print("COMPLETION_RIPPLE progress=%.2f" % float(
			hud.call("get_completion_mirror_fade").call("get_progress")
		))
		await _save("03_completion_ripple.png")
	get_tree().paused = false
	get_tree().current_scene = null
	level.queue_free()
	await _wait_process(8)


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


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
