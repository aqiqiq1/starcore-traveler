extends Node

## 640x360 evidence for the two hidden-side light hints.
## Run WITHOUT --headless:
##
##   D:/Godot/Godot_v4.7.2-stable_win64_console.exe --resolution 640x360 \
##     --path . res://dlc/star_loom/tests/capture_hidden_hint.tscn
##
## Saves to res://screenshots/hidden_hint_20261128/:
##   01_dlc3_checkpoint_hint_640.png        first recorded checkpoint + line
##   02_chapter_page_side_hint_640.png      four rows + undiscovered footer
##   03_chapter_page_after_discovery_640.png sidebar row revealed, no footer
##
## The checkpoint line is produced by moving the real body into the real
## Area2D; the chapter footer is the real page refresh.  No show_event() call
## fakes either frame.

const CHAPTER_PROGRESS = preload("res://scripts/ui/chapter_progress.gd")
const REGISTRY = preload("res://scripts/mechanics/mechanic_registry.gd")

const OUT_DIR: String = "res://screenshots/hidden_hint_20261128"
const LOOM: String = "res://dlc/star_loom/star_loom.tscn"
const LEVEL_01: String = "res://scenes/level_01.tscn"
const PROGRESS: String = "user://hidden_hint_capture_chapters.cfg"
const MECH_PROGRESS: String = "user://hidden_hint_capture_mechanics.cfg"
const HINT_PROGRESS: String = "user://hidden_hint_capture_hint.cfg"

var _saved: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for tip_id: String in ["polarity", "core_carry", "relay_link", "float_platform"]:
		MechanicTips.mark_seen(tip_id)
	_prepare_mechanic_progress()
	_remove_progress()
	get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	await _capture_checkpoint()
	await _capture_chapter_pages()
	_remove_progress()
	MechanicTeach.clear_progress_path_override()
	print("HIDDEN_HINT_CAPTURE saved=%d files=%s" % [
		_saved.size(), ", ".join(_saved)
	])
	get_tree().quit(0 if _saved.size() == 3 else 1)


func _prepare_mechanic_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	for id: String in REGISTRY.all_ids():
		config.set_value("mechanics", id, true)
	config.save(MECH_PROGRESS)
	MechanicTeach.set_progress_path_override(MECH_PROGRESS)


func _remove_progress() -> void:
	for path: String in [PROGRESS, HINT_PROGRESS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _capture_checkpoint() -> void:
	var level: Node = await _load(LOOM, func(node: Node) -> void:
		node.set("chapter_progress_path", PROGRESS)
		node.set("hint_progress_path", HINT_PROGRESS)
		node.set("show_intro_guide", false)
		node.set("show_intro_cinematic", false)
	)
	if level == null:
		return
	var player: L3Player = level.call("get_player") as L3Player
	var checkpoint: LevelCheckpoint = level.call("get_checkpoint") as LevelCheckpoint
	var camera: Camera2D = level.call("get_camera") as Camera2D
	var hud: LoomHUD = level.call("get_hud") as LoomHUD
	if player == null or checkpoint == null:
		await _cleanup(level)
		return
	# Seat the core before the checkpoint so the bay's own one-shot
	# "青核入仓" edge is spent; otherwise it would overwrite the checkpoint line
	# in the same frame.
	var carrier: CoreDeliveryCarrier = level.call("get_core_carrier") as CoreDeliveryCarrier
	if carrier != null:
		carrier.debug_set_x(carrier.socket_x)
		await _wait_physics(6)
	player.global_position = checkpoint.global_position
	player.velocity = Vector2.ZERO
	if camera != null:
		camera.reset_smoothing()
	await _wait_physics(10)
	await _wait_seconds(0.4)
	print("SHOT_CHECKPOINT event=%s marker=%s" % [
		hud.get_event_text(),
		str(bool(level.call("is_checkpoint_mirror_hint_shown")))
	])
	await _save("01_dlc3_checkpoint_hint_640")
	await _cleanup(level)


func _capture_chapter_pages() -> void:
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L1, PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L2, PROGRESS)
	CHAPTER_PROGRESS.mark_completed(CHAPTER_PROGRESS.ID_L3, PROGRESS)
	var level: Node = await _load(LEVEL_01, func(node: Node) -> void:
		var menu: StartMenu = node.get_node_or_null("StartMenu") as StartMenu
		if menu != null:
			menu.chapter_progress_path = PROGRESS
		node.set("enable_start_menu", true)
	)
	if level == null:
		return
	var menu: StartMenu = level.get_node_or_null("StartMenu") as StartMenu
	if menu == null:
		await _cleanup(level)
		return
	await _wait_process(8)
	menu.get_chapter_button().pressed.emit()
	await _wait_process(8)
	print("SHOT_PAGE_BEFORE footer=%s rift=%s text=%s" % [
		str(menu.is_chapter_side_hint_visible()),
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT).visible),
		menu.get_chapters_progress_text()
	])
	await _save("02_chapter_page_side_hint_640")
	CHAPTER_PROGRESS.mark_discovered(CHAPTER_PROGRESS.ID_RIFT, PROGRESS)
	menu.call("_refresh_chapters", false)
	await _wait_process(8)
	print("SHOT_PAGE_AFTER footer=%s rift=%s text=%s" % [
		str(menu.is_chapter_side_hint_visible()),
		str(menu.get_chapter_row(CHAPTER_PROGRESS.ID_RIFT).visible),
		menu.get_chapters_progress_text()
	])
	await _save("03_chapter_page_after_discovery_640")
	await _cleanup(level)


# --- helpers ---------------------------------------------------------------

func _load(scene_path: String, configure: Callable = Callable()) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("HIDDEN_HINT_CAPTURE missing %s" % scene_path)
		return null
	var level: Node = packed.instantiate()
	if configure.is_valid():
		configure.call(level)
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	get_tree().paused = false
	await _wait_process(8)
	await _wait_physics(8)
	return level


func _cleanup(level: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(DemoAudio):
		DemoAudio.stop_world()
	var current: Node = get_tree().current_scene
	get_tree().current_scene = null
	if current != null and is_instance_valid(current):
		current.queue_free()
	await _wait_process(14)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_width() != 640 or image.get_height() != 360:
		print("CAPTURE_SIZE unexpected %dx%d, resizing" % [
			image.get_width(), image.get_height()
		])
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(directory.path_join(shot_name + ".png"))
	_saved.append(shot_name)
	print("SHOT %s size=%dx%d error=%d" % [
		shot_name, image.get_width(), image.get_height(), error
	])


func _wait_process(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _wait_seconds(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
